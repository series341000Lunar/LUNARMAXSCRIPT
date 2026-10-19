/*
 Universal Selected Key Editor - v0.2 (existing-key editor)
 Intended host: Autodesk 3ds Max 2027 / MAXScript
 See README.md and tests/runtime_report.txt for verification scope.

 - Inspect selected or all keys under selected scene nodes (SubAnim traversal).
 - Read: source frame, controller, MAXScript indexed access, raw key value and type.
 - IMPORTANT: raw key units may differ from Modify Panel (angle radian vs degree,
   percentage 0..1 vs 0..100, and some color ranges).
 - Write edited typed value to source key.
 - Add a new key at a specified frame (do not overwrite existing).
 - Relocate one key to a specified frame with collision refusal.
   Within its neighboring interval, use native moveKey + sortKeys.
   Crossing moves stage a same-class key copy using I_KEYCONTROL.
   Unsupported controllers are refused. No first-key creation.

 Inputs are parsed by safeReadExpr (not unrestricted execute).
*/
(
    global LKE_UI
    try (destroyDialog LKE_UI) catch ()

    global LKE_Rows = #()
    global LKE_SeenHandles = #()

    struct LKE_KeyRow
    (
        controllerHandle,
        nodeHandle,
        displayPath,
        accessPath,
        subIndices,
        keyTime,
        sampledValue,
        typeName,
        canEdit
    )

    fn LKE_ReadKeyValue k =
    (
        local v = undefined
        try (v = k.value) catch ()
        v
    )

    fn LKE_FmtTime t =
    (
        if t == undefined then return "?"
        local f = t.frame
        if f == (f as integer) then ((f as integer) as string) else (f as string)
    )

    fn LKE_ValueText v =
    (
        if (classOf v) == Float then (formattedPrint v format:".9g") else (v as string)
    )

    fn LKE_AddController c displayPath accessPath nodeHandle allKeys subIndices =
    (
        local handle = try (getHandleByAnim c) catch (undefined)
        if handle == undefined then return false
        if (findItem LKE_SeenHandles handle) > 0 then return false
        append LKE_SeenHandles handle

        local n = try (numKeys c) catch (-1)
        if n < 1 then return false

        for ki = 1 to n do
        (
            local selected = try (isKeySelected c ki) catch (false)
            if (allKeys or selected) do
            (
                local k = try (getKey c ki) catch (undefined)
                if k != undefined do
                (
                    local v = LKE_ReadKeyValue k
                    local cls = if v == undefined then "unavailable" else ((classOf v) as string)
                    append LKE_Rows (LKE_KeyRow \
                        controllerHandle:handle \
                        nodeHandle:nodeHandle \
                        displayPath:displayPath \
                        accessPath:(accessPath + ".controller") \
                        subIndices:(for index in subIndices collect index) \
                        keyTime:k.time \
                        sampledValue:v \
                        typeName:cls \
                        canEdit:(v != undefined))
                )
            )
        )
        true
    )

    fn LKE_Walk anim displayPath accessPath nodeHandle allKeys depth subIndices =
    (
        if depth > 24 then return false

        local c = try (anim.controller) catch (undefined)
        if c != undefined do LKE_AddController c displayPath accessPath nodeHandle allKeys subIndices

        local n = try (anim.numSubs) catch (0)
        for i = 1 to n do
        (
            local child = try (getSubAnim anim i) catch (undefined)
            if child != undefined do
            (
                local childName = try (child.name as string) catch ("SubAnim" + (i as string))
                local childIndices = for index in subIndices collect index
                append childIndices i
                LKE_Walk child \
                    (displayPath + " > " + childName) \
                    (accessPath + "[" + (i as string) + "]") \
                    nodeHandle allKeys (depth + 1) childIndices
            )
        )
        true
    )

    fn LKE_ResolveRow row =
    (
        if row == undefined then return undefined
        local c = try (getAnimByHandle row.controllerHandle) catch (undefined)
        if c == undefined then return undefined
        local owner = try (getAnimByHandle row.nodeHandle) catch (undefined)
        if not isValidNode owner then return undefined
        local track = owner
        for i in row.subIndices do track = try (getSubAnim track i) catch (undefined)
        local bound = try (track.controller) catch (undefined)
        if bound == undefined or bound != c then return undefined
        local ki = try (getKeyIndex c row.keyTime) catch (0)
        if ki == undefined or ki < 1 then return undefined
        #(c, ki, (getKey c ki))
    )

    fn LKE_ParseTyped input oldValue controller:undefined =
    (
        if oldValue == undefined then return undefined
        local s = trimLeft (trimRight input)
        local cls = classOf oldValue
        if controller != undefined and (classOf controller) == boolean_float do
        (
            local token = toLower s
            if findItem #("true", "on", "1", "1.0") token > 0 then return 1.0
            if findItem #("false", "off", "0", "0.0") token > 0 then return 0.0
            return undefined
        )
        if cls == String then return input
        if cls == Boolean then
        (
            local t = toLower s
            if (t == "true" or t == "on" or t == "1") then return true
            if (t == "false" or t == "off" or t == "0") then return false
            return undefined
        )

        local parsed = try (safeReadExpr (s as stringstream) ignoreSSSEState:true) catch (undefined)
        if parsed == undefined then return undefined

        if cls == Float then
        (
            if isKindOf parsed Number then return (parsed as float)
            return undefined
        )
        if cls == Integer then
        (
            if (classOf parsed) == Integer then return parsed
            return undefined
        )
        if (classOf parsed) == cls then parsed else undefined
    )

    fn LKE_CrossesOtherKeys c sourceTime targetTime =
    (
        local crossing = false
        local n = numKeys c
        for i = 1 to n do
        (
            local t = getKeyTime c i
            if ((t > sourceTime and t < targetTime) or (t < sourceTime and t > targetTime)) do crossing = true
        )
        crossing
    )

    fn LKE_KeyState c details:false =
    (
        for i = 1 to numKeys c collect
        (
            local k = getKey c i
            local entry = #(k.time, LKE_ReadKeyValue k)
            if details do
            (
                for prop in #(#selected, #inTangentType, #outTangentType, #inTangent, #outTangent,
                    #inTangentLength, #outTangentLength, #freeHandle, #x_locked, #y_locked,
                    #z_locked, #constantVelocity, #tension, #continuity, #bias, #easeTo, #easeFrom) do
                    append entry (try (#(prop, getProperty k prop)) catch (#(prop, undefined)))
            )
            entry
        )
    )

    fn LKE_PerformEdit c operation source target value =
    (
        local sourceIndex = getKeyIndex c source
        if sourceIndex == undefined or sourceIndex < 1 then throw "Source key is missing. Refresh."
        case operation of
        (
            #value: ((getKey c sourceIndex).value = value)
            #new:
            (
                if (getKeyIndex c target) > 0 then throw "Target already contains a key."
                addNewKey c target #select
                local newIndex = getKeyIndex c target
                if newIndex == undefined or newIndex < 1 then throw "Key creation failed."
                (getKey c newIndex).value = value
            )
            #move:
            (
                if source == target then throw "Target is already the source frame."
                if (getKeyIndex c target) > 0 then throw "Target already contains a key."
                if LKE_CrossesOtherKeys c source target then
                (
                    -- Copy the native key data BEFORE changing the source controller.
                    -- A one-key temporary controller can be retimed without crossing neighbors.
                    local transfer = copy c
                    if transfer == c then throw "Controller copy is not independent."
                    deleteKeys transfer #allKeys
                    appendKey transfer.keys (getKey c sourceIndex)
                    if numKeys transfer != 1 then throw "Native key copy is unsupported."
                    (getKey transfer 1).time = target
                    (getKey transfer 1).value = value
                    appendKey c.keys (getKey transfer 1)
                    if (getKeyIndex c target) < 1 then throw "Native key paste failed."
                    deleteKey c (getKeyIndex c source)
                )
                else
                (
                    moveKey c sourceIndex (target - source)
                    sortKeys c
                    local newIndex = getKeyIndex c target
                    if newIndex == undefined or newIndex < 1 then throw "Key did not reach target."
                    -- Pure moves never serialize or reassign the value.
                )
                sortKeys c
            )
            default: (throw "Unknown key operation.")
        )
        true
    )

    fn LKE_CommitEdit row operation target value =
    (
        local resolved = LKE_ResolveRow row
        if resolved == undefined then throw "Source track changed. Refresh the list."
        local c = resolved[1]
        local currentValue = LKE_ReadKeyValue resolved[3]
        if (classOf currentValue) != (classOf row.sampledValue) or not (deepEqual currentValue row.sampledValue) then
            throw "Source value changed outside the editor. Refresh the list."
        if not (try (c.supportsKeys) catch (false)) then throw "Controller does not support safe native key editing."
        if (classOf c) == On_Off then throw "On/Off toggle controllers are read-only in this editor."
        if operation == #move then value = currentValue

        -- Trial the exact operation on a detached copy before touching the scene.
        local before = LKE_KeyState c details:true
        local staged = copy c
        if staged == c or (classOf staged) != (classOf c) then throw "Controller copy is not independent or has the wrong type."
        LKE_PerformEdit staged operation row.keyTime target value
        local planned = LKE_KeyState staged
        local expectedCount = before.count + (if operation == #new then 1 else 0)
        if planned.count != expectedCount then throw "Unexpected key count. No scene change made."
        local expectedTime = if operation == #value then row.keyTime else target
        local destination = getKeyIndex staged expectedTime
        if destination == undefined or destination < 1 then throw "Target verification failed."
        if not (deepEqual (LKE_ReadKeyValue (getKey staged destination)) value) then throw "Controller rejected or converted the value."
        for state in before where (operation == #new or state[1] != row.keyTime) do
        (
            local idx = getKeyIndex staged state[1]
            if idx == undefined or idx < 1 then throw "An unrelated key disappeared."
            if not (deepEqual (LKE_ReadKeyValue (getKey staged idx)) state[2]) then throw "An unrelated key value changed."
        )

        -- Own exactly one hold, so failure cancels this edit and never the user's previous edit.
        -- An undo-on context would start its own hold before this guard.
        -- Own the SDK hold directly, as recommended for explicit Cancel semantics.
        (
            if theHold.Holding() or theHold.IsSuspended() then throw "Undo is busy or suspended. Finish the current action and retry."
            local ownedHold = false
            local failure = undefined
            try
            (
                theHold.Begin()
                ownedHold = true
                if LKE_ResolveRow row == undefined or not (deepEqual (LKE_KeyState c details:true) before) then
                    throw "Source changed during preflight. Refresh the list."
                LKE_PerformEdit c operation row.keyTime target value
                if not (deepEqual (LKE_KeyState c) planned) then throw "Post-edit verification failed."
                theHold.Accept ("LKE - " + (operation as string))
                ownedHold = false
            )
            catch
            (
                local reason = getCurrentException() as string
                if ownedHold do theHold.Cancel()
                failure = if not (deepEqual (LKE_KeyState c details:true) before) then
                    (reason + " | ROLLBACK INCOMPLETE: stop editing and inspect this track.")
                else (reason + " | Edit cancelled; source keys restored.")
            )
            if failure != undefined do throw failure
        )
        true
    )

    rollout LKE_UI "Universal Selected Key Editor  |  0.2" width:900 height:668
    (
        local displayedValueText = ""
        button bScan "REFRESH / SCAN" pos:[12,10] width:190 height:30
        radiobuttons rbMode "MODE (selected objects)" labels:#("SELECT - Selected keys", "ALL - All keys") default:1 columns:2 pos:[218,3] width:650 height:39
        label lblStatus "Select an object, then click REFRESH." pos:[12,44] width:870 height:17

        dotNetControl lv "System.Windows.Forms.ListView" pos:[12,69] width:876 height:348

        label lblEditor "SELECTED TRACK / MAXSCRIPT ACCESS" pos:[12,426] width:650 height:19
        dotNetControl txAccess "System.Windows.Forms.TextBox" pos:[12,447] width:766 height:52
        button bCopy "COPY PATH" pos:[785,447] width:102 height:34

        label lblFrame "TARGET FRAME  (integer)" pos:[12,508] width:205 height:18
        label lblValue "RAW KEY VALUE  (controller units, type preserved)" pos:[247,508] width:630 height:18
        dotNetControl txFrame "System.Windows.Forms.TextBox" pos:[12,529] width:220 height:32
        dotNetControl txValue "System.Windows.Forms.TextBox" pos:[247,529] width:640 height:32

        button bApply "APPLY VALUE (ORIGINAL KEY)" pos:[12,579] width:266 height:40
        button bNew "CREATE NEW KEY @ FRAME" pos:[288,579] width:266 height:40
        button bMove "MOVE KEY @ FRAME" pos:[564,579] width:323 height:40

        label lblFoot "WARNING: angles may be radians; percentages may be 0..1. Duplicate scene before testing." pos:[12,630] width:870 height:18

        fn SelectedRowIndex =
        (
            if lv.SelectedItems.Count == 0 then return 0
            try (lv.SelectedItems.Item[0].Tag as integer) catch (0)
        )

        fn GetSelectedRow =
        (
            local ri = SelectedRowIndex()
            if ri < 1 or ri > LKE_Rows.count then undefined else LKE_Rows[ri]
        )

        fn SelectedTargetFrame =
        (
            local s = trimLeft (trimRight (txFrame.Text as string))
            local n = try (safeReadExpr (s as stringstream) ignoreSSSEState:true) catch (undefined)
            if n == undefined then return undefined
            if (classOf n) != Integer then return undefined
            if n < -1000000 or n > 1000000 then return undefined
            n
        )

        fn MakeLabelForRow r =
        (
            local vstr = if r.canEdit then (LKE_ValueText r.sampledValue) else "[not readable]"
            #(LKE_FmtTime r.keyTime, r.displayPath, vstr, r.typeName)
        )

        fn DisplayRow r =
        (
            if r == undefined then return false
            txFrame.Text = LKE_FmtTime r.keyTime
            displayedValueText = if r.canEdit then (LKE_ValueText r.sampledValue) else ""
            txValue.Text = displayedValueText
            local resolved = LKE_ResolveRow r
            local idx = if resolved != undefined then resolved[2] else "?"
            txAccess.Text = r.accessPath + ".keys[" + (idx as string) + "]"
            true
        )

        fn RefreshList =
        (
            lv.BeginUpdate()
            lv.Items.Clear()
            LKE_Rows = #()
            LKE_SeenHandles = #()
            txAccess.Text = ""
            txValue.Text = ""
            txFrame.Text = ""
            displayedValueText = ""

            local scanError = undefined
            try
            (
            for o in selection where isValidNode o do
            (
                local nodeHandle = getHandleByAnim o
                LKE_Walk o o.name ("(getAnimByHandle " + (nodeHandle as string) + ")") nodeHandle (rbMode.state == 2) 0 #()
            )

            for ri = 1 to LKE_Rows.count do
            (
                local r = LKE_Rows[ri]
                local fields = MakeLabelForRow r
                local item = dotNetObject "System.Windows.Forms.ListViewItem" fields[1]
                item.Tag = dotNetObject "System.Int32" ri
                item.SubItems.Add fields[2]
                item.SubItems.Add fields[3]
                item.SubItems.Add fields[4]
                lv.Items.Add item
            )
            )
            catch (scanError = getCurrentException() as string)
            lv.EndUpdate()
            if scanError != undefined then
            (
                lv.Items.Clear()
                LKE_Rows = #()
                lblStatus.text = "Scan failed: " + scanError
                return false
            )

            lblStatus.text = (if rbMode.state == 1 then "SELECT | " else "ALL | ") + (LKE_Rows.count as string) + " keys found on " + (selection.count as string) + " selected object(s)."
            if LKE_Rows.count > 0 then
            (
                lv.Items.Item[0].Selected = true
                lv.Items.Item[0].Focused = true
                DisplayRow LKE_Rows[1]
            )
            else if rbMode.state == 1 then
                lblStatus.text += "   Select keys and REFRESH, or choose ALL."
            true
        )

        fn GetWriteContext readInput:true =
        (
            local r = GetSelectedRow()
            if r == undefined then
            (
                messageBox "Select one key from the list." title:"Key Editor"
                return undefined
            )
            local context = try (LKE_ResolveRow r) catch (undefined)
            if context == undefined then
            (
                messageBox "Source key no longer exists. Refresh the list." title:"Key Editor"
                return undefined
            )
            if not r.canEdit then
            (
                messageBox "This key does not expose an editable .value. No change made." title:"Key Editor"
                return undefined
            )
            local currentValue = LKE_ReadKeyValue context[3]
            local newValue = currentValue
            if readInput and (txValue.Text as string) != displayedValueText do
                newValue = LKE_ParseTyped (txValue.Text as string) currentValue controller:context[1]
            if newValue == undefined then
            (
                messageBox ("Invalid value. Expected type: " + ((classOf currentValue) as string) + "\nFor Boolean use true / false / on / off.") title:"Key Editor"
                return undefined
            )
            #(r, context[1], context[2], context[3], newValue)
        )

        on LKE_UI open do
        (
            lv.View = (dotNetClass "System.Windows.Forms.View").Details
            lv.FullRowSelect = true
            lv.HideSelection = false
            lv.MultiSelect = false
            lv.GridLines = true
            lv.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").NonClickable
            lv.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 13.0
            lv.Columns.Add "Frame" 95
            lv.Columns.Add "Object / Track (SubAnim)" 455
            lv.Columns.Add "Value" 208
            lv.Columns.Add "Type" 110

            txFrame.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0
            txValue.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0
            txAccess.Font = dotNetObject "System.Drawing.Font" "Consolas" 11.0
            txAccess.Multiline = true
            txAccess.ReadOnly = true
            txAccess.ScrollBars = (dotNetClass "System.Windows.Forms.ScrollBars").Horizontal

            RefreshList()
        )

        on lv SelectedIndexChanged sender args do
        (
            local r = GetSelectedRow()
            if r != undefined do DisplayRow r
        )

        on bScan pressed do RefreshList()
        on rbMode changed state do RefreshList()

        on bCopy pressed do
        (
            if txAccess.Text != "" do (setClipBoardText txAccess.Text)
        )

        fn RunEdit operation =
        (
            local p = GetWriteContext readInput:(operation != #move)
            if p == undefined then return false
            local target = if operation == #value then p[1].keyTime else undefined
            if operation != #value do
            (
                local frame = SelectedTargetFrame()
                if frame == undefined then
                (
                    messageBox "Enter a whole-number target frame." title:"Key Editor"
                    return false
                )
                target = frame * 1f
            )
            if operation == #move and (LKE_CrossesOtherKeys p[2] p[1].keyTime target) do
            (
                if not (queryBox "This move crosses other keys. A native key copy will be staged and verified. Neighboring curves may change. Continue?" title:"Move Across Keys") then return false
            )
            local ok = false
            try (ok = LKE_CommitEdit p[1] operation target p[5])
            catch (messageBox (getCurrentException() as string) title:"Key Editor - Edit refused or cancelled")
            -- Failure may invalidate the displayed snapshot too.
            RefreshList()
            ok
        )

        on bApply pressed do RunEdit #value
        on bNew pressed do RunEdit #new
        on bMove pressed do RunEdit #move
    )
    createDialog LKE_UI 900 668 style:#(#style_titlebar, #style_sysmenu, #style_minimizebox)
)
