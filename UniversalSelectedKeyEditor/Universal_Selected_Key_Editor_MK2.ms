/*
 Universal Selected Key Editor - MK2 (existing-key editor)
 Intended host: Autodesk 3ds Max 2027 / MAXScript
 See MK2_README.md and tests/runtime_MK2_report.txt for verification scope.

 - Inspect current-frame or all keys under selected scene nodes (SubAnim traversal).
 - Right-click Object / Track to isolate, hide, or restore a category.
 - Double-click Value to edit an existing key without changing sliderTime.
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
    global LKE_TimeCallback
    global LKE_InlineHost
    if LKE_InlineHost == undefined do
    (
        try (LKE_InlineHost = dotNetClass "USKE.MK2.InlineHost") catch ()
        if LKE_InlineHost == undefined do
        (
            -- Embedded helper built from support/MK2InlineHost.cs; no external DLL.
            local helperBytes = (dotNetClass "System.Convert").FromBase64String "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YgBsAHkAIABWAGUAcgBzAGkAbwBuAAAAMAAuADAALgAwAC4AMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAwAAACgNQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
            (dotNetClass "System.Reflection.Assembly").Load helperBytes
            LKE_InlineHost = dotNetClass "USKE.MK2.InlineHost"
        )
    )
    if LKE_TimeCallback != undefined do try (unregisterTimeCallback LKE_TimeCallback) catch ()
    LKE_TimeCallback = undefined
    try (destroyDialog LKE_UI) catch ()

    global LKE_Rows = #()
    global LKE_SeenHandles = #()

    struct LKE_KeyRow
    (
        controllerHandle,
        nodeHandle,
        displayPath,
        trackName,
        isLightTrack,
        accessPath,
        subIndices,
        categoryTrail,
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

    fn LKE_AxisToken trackName =
    (
        -- Match a literal axis token in the leaf track name, never object/ancestor names.
        local nameText = trimLeft (trimRight trackName)
        local match = (dotNetClass "System.Text.RegularExpressions.Regex").Match nameText "(?i)^(x|y|z)(?:$|[ _.-])|[ _.-](x|y|z)$"
        if not match.Success then return undefined
        local token = match.Groups.Item[1].Value as string
        if token == "" do token = match.Groups.Item[2].Value as string
        toLower token
    )

    fn LKE_CellColor row =
    (
        local colors = dotNetClass "System.Drawing.Color"
        case (LKE_AxisToken row.trackName) of
        (
            "x": (colors.FromArgb 255 228 228)
            "y": (colors.FromArgb 227 245 228)
            "z": (colors.FromArgb 225 236 255)
            default: (if row.isLightTrack then (colors.FromArgb 255 248 204) else undefined)
        )
    )

    fn LKE_AddController c displayPath accessPath nodeHandle allKeys subIndices includeTime:undefined trackName:"" categoryTrail:#() =
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
            local atCurrentTime = includeTime != undefined and (try ((getKeyTime c ki) == includeTime) catch (false))
            if (allKeys or (if includeTime == undefined then selected else atCurrentTime)) do
            (
                local k = try (getKey c ki) catch (undefined)
                if k != undefined do
                (
                    local v = LKE_ReadKeyValue k
                    local cls = if v == undefined then "unavailable" else ((classOf v) as string)
                    local lightTrack = try ((superClassOf (getAnimByHandle nodeHandle).baseObject) == Light) catch (false)
                    append LKE_Rows (LKE_KeyRow \
                        controllerHandle:handle \
                        nodeHandle:nodeHandle \
                        displayPath:displayPath \
                        trackName:trackName \
                        isLightTrack:lightTrack \
                        accessPath:(accessPath + ".controller") \
                        subIndices:(for index in subIndices collect index) \
                        categoryTrail:categoryTrail \
                        keyTime:k.time \
                        sampledValue:v \
                        typeName:cls \
                        canEdit:(v != undefined))
                )
            )
        )
        true
    )

    fn LKE_Walk anim displayPath accessPath nodeHandle allKeys depth subIndices includeTime:undefined trackName:"" categoryTrail:#() =
    (
        if depth > 24 then return false
        if categoryTrail.count == 0 do categoryTrail = #(#((nodeHandle as string) + ":#()", displayPath, displayPath))

        local c = try (anim.controller) catch (undefined)
        if c != undefined do LKE_AddController c displayPath accessPath nodeHandle allKeys subIndices includeTime:includeTime trackName:trackName categoryTrail:categoryTrail

        local n = try (anim.numSubs) catch (0)
        for i = 1 to n do
        (
            local child = try (getSubAnim anim i) catch (undefined)
            if child != undefined do
            (
                local childName = try (child.name as string) catch ("SubAnim" + (i as string))
                local childIndices = for index in subIndices collect index
                append childIndices i
                local childTrail = for category in categoryTrail collect category
                append childTrail #((nodeHandle as string) + ":" + (childIndices as string), childName, displayPath + " > " + childName)
                LKE_Walk child \
                    (displayPath + " > " + childName) \
                    (accessPath + "[" + (i as string) + "]") \
                    nodeHandle allKeys (depth + 1) childIndices includeTime:includeTime trackName:childName categoryTrail:childTrail
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

    -- Probe the live selected nodes, not cached rows: newly added keys are detected too.
    fn LKE_HasKeyAtTime anim t allKeys seen depth =
    (
        if depth > 24 then return false
        local c = try (anim.controller) catch (undefined)
        if c != undefined do
        (
            local handle = try (getHandleByAnim c) catch (undefined)
            if handle != undefined and findItem seen handle == 0 do
            (
                append seen handle
                local idx = try (getKeyIndex c t) catch (0)
                if idx != undefined and idx > 0 do
                (
                    local readable = try ((getKey c idx) != undefined) catch (false)
                    if readable and (allKeys or (try (isKeySelected c idx) catch (false))) then return true
                )
            )
        )
        local n = try (anim.numSubs) catch (0)
        for i = 1 to n do
        (
            local child = try (getSubAnim anim i) catch (undefined)
            if child != undefined and (LKE_HasKeyAtTime child t allKeys seen (depth + 1)) then return true
        )
        false
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

    rollout LKE_UI "Universal Selected Key Editor  |  MK2" width:900 height:668
    (
        local displayedValueText = ""
        local pendingTime = undefined
        local autoRefreshBusy = false
        local hiddenCategoryKeys = #()
        local onlyCategoryKey = undefined
        local knownCategories = #()
        local categoryMenu = undefined
        local categoryRootItems = undefined
        local menuHandlers = #()
        local inlineEditor = undefined
        local inlineRow = undefined
        local inlineOriginalText = ""
        local inlineAcceleratorsState = undefined
        local pendingInlineRow = undefined
        local RefreshList
        timer refreshDelay interval:180 active:false
        timer inlineStartDelay interval:40 active:false
        button bScan "REFRESH / SCAN" pos:[12,10] width:190 height:30
        radiobuttons rbMode "MODE (selected objects)" labels:#("SELECT - Current frame only", "ALL - All keys") default:1 columns:2 pos:[218,3] width:650 height:39
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

        fn CancelInlineEdit =
        (
            inlineStartDelay.active = false
            pendingInlineRow = undefined
            inlineRow = undefined
            if inlineAcceleratorsState != undefined do
            (
                enableAccelerators = inlineAcceleratorsState
                inlineAcceleratorsState = undefined
            )
            if inlineEditor != undefined do inlineEditor.Visible = false
            true
        )

        fn RowInCategory row key =
        (
            for category in row.categoryTrail where category[1] == key do return true
            false
        )

        fn IsCategoryVisible row =
        (
            if onlyCategoryKey != undefined and not (RowInCategory row onlyCategoryKey) then return false
            for key in hiddenCategoryKeys where RowInCategory row key do return false
            true
        )

        fn ApplyCategoryAction action key:undefined =
        (
            CancelInlineEdit()
            case action of
            (
                #all: (hiddenCategoryKeys = #(); onlyCategoryKey = undefined)
                #only: (onlyCategoryKey = key; hiddenCategoryKeys = #())
                #hide: (if key != undefined and findItem hiddenCategoryKeys key == 0 do append hiddenCategoryKeys key)
                #unhide: (hiddenCategoryKeys = for hidden in hiddenCategoryKeys where hidden != key collect hidden)
            )
            RefreshList focusTime:sliderTime
        )

        fn DisposeCategoryMenu =
        (
            for item in menuHandlers do try (dotNet.removeAllEventHandlers item) catch ()
            menuHandlers = #()
            if categoryMenu != undefined do categoryMenu.Dispose()
            categoryMenu = undefined
            categoryRootItems = undefined
        )

        fn OnCategoryMenuClick sender args =
        (
            local action = (sender.Name as string) as name
            local key = if sender.Tag == undefined then undefined else (sender.Tag as string)
            ApplyCategoryAction action key:key
        )

        fn AddCategoryMenuItem items text action key:undefined =
        (
            -- Let the owning menu create its native item, avoiding Add overload ambiguity.
            local item = items.Add (text as string)
            dotNet.setLifetimeControl item #dotNet
            item.Name = action as string
            if key != undefined do item.Tag = key
            dotNet.addEventHandler item "Click" OnCategoryMenuClick
            append menuHandlers item
            item
        )

        fn BuildCategoryMenu row =
        (
            if categoryMenu == undefined then
            (
                categoryMenu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
                dotNet.setLifetimeControl categoryMenu #dotNet
                categoryRootItems = categoryMenu.Items
            )
            else
            (
                for item in menuHandlers do try (dotNet.removeAllEventHandlers item; item.Dispose()) catch ()
                menuHandlers = #()
                categoryRootItems.Clear()
            )
            local rootItems = categoryRootItems
            local showAllItem = AddCategoryMenuItem rootItems "SHOW ALL CATEGORIES" #all
            showAllItem.Checked = hiddenCategoryKeys.count == 0 and onlyCategoryKey == undefined
            if row != undefined do
            (
                local depth = 0
                for category in row.categoryTrail do
                (
                    local indent = ""
                    for i = 1 to depth do indent += "  "
                    local onlyItem = AddCategoryMenuItem rootItems ("ONLY: " + indent + category[2]) #only key:category[1]
                    onlyItem.ToolTipText = category[3]
                    local hideItem = AddCategoryMenuItem rootItems ("HIDE: " + indent + category[2]) #hide key:category[1]
                    hideItem.ToolTipText = category[3]
                    depth += 1
                )
            )
            for category in knownCategories where findItem hiddenCategoryKeys category[1] > 0 do
                AddCategoryMenuItem rootItems ("UNHIDE: " + category[3]) #unhide key:category[1]
            categoryMenu
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

        fn SelectTimeRow t preferredController:undefined =
        (
            local chosen = 0
            for ri = 1 to LKE_Rows.count where LKE_Rows[ri].keyTime == t do
            (
                if chosen == 0 do chosen = ri
                if preferredController != undefined and LKE_Rows[ri].controllerHandle == preferredController do
                (
                    chosen = ri
                    exit
                )
            )
            if chosen == 0 then return false
            -- Resolve by Tag so selection is independent of displayed item ordering.
            for i = 0 to lv.Items.Count - 1 do
            (
                local item = lv.Items.Item[i]
                if (item.Tag as integer) == chosen do
                (
                    item.Selected = true
                    item.Focused = true
                    item.EnsureVisible()
                    DisplayRow LKE_Rows[chosen]
                    return true
                )
            )
            false
        )

        fn RefreshList focusTime:undefined =
        (
            CancelInlineEdit()
            local previousRow = GetSelectedRow()
            local preferredController = if previousRow == undefined then undefined else previousRow.controllerHandle
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
                LKE_Walk o o.name ("(getAnimByHandle " + (nodeHandle as string) + ")") nodeHandle (rbMode.state == 2) 0 #() includeTime:sliderTime
            )

            for r in LKE_Rows do
                for category in r.categoryTrail do
                (
                    local found = false
                    for known in knownCategories where known[1] == category[1] do found = true
                    if not found do append knownCategories category
                )
            local unfilteredCount = LKE_Rows.count
            LKE_Rows = for r in LKE_Rows where IsCategoryVisible r collect r

            for ri = 1 to LKE_Rows.count do
            (
                local r = LKE_Rows[ri]
                local fields = MakeLabelForRow r
                local item = dotNetObject "System.Windows.Forms.ListViewItem" fields[1]
                item.Tag = dotNetObject "System.Int32" ri
                item.SubItems.Add fields[2]
                item.SubItems.Add fields[3]
                item.SubItems.Add fields[4]
                local cellColor = LKE_CellColor r
                if cellColor != undefined do
                (
                    item.UseItemStyleForSubItems = false
                    item.SubItems.Item[1].BackColor = cellColor
                )
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
            if onlyCategoryKey != undefined or hiddenCategoryKeys.count > 0 do lblStatus.text += "   Category filter active. Right-click to SHOW ALL."
            if LKE_Rows.count > 0 then
            (
                if focusTime == undefined or not (SelectTimeRow focusTime preferredController:preferredController) do
                (
                    lv.Items.Item[0].Selected = true
                    lv.Items.Item[0].Focused = true
                    DisplayRow LKE_Rows[1]
                )
            )
            else if rbMode.state == 1 then
                lblStatus.text += "   No keys at current frame."
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

        fn BeginInlineEdit rowIndex =
        (
            CancelInlineEdit()
            local liveList = LKE_UI.lv
            if rowIndex < 1 or rowIndex > LKE_Rows.count then return false
            local row = LKE_Rows[rowIndex]
            local context = try (LKE_ResolveRow row) catch (undefined)
            if context == undefined or not row.canEdit then
            (
                lblStatus.text = "This source key is unavailable or read-only. Refresh the list."
                return false
            )
            local item = undefined
            for i = 0 to liveList.Items.Count - 1 where (liveList.Items.Item[i].Tag as integer) == rowIndex do item = liveList.Items.Item[i]
            if item == undefined then return false
            item.EnsureVisible()
            item.Selected = true
            local bounds = item.SubItems.Item[2].Bounds
            local width = liveList.ClientSize.Width - bounds.Left
            if width > bounds.Width do width = bounds.Width
            if width < 30 then
            (
                lblStatus.text = "Scroll horizontally to expose the Value cell, then double-click it."
                return false
            )
            refreshDelay.active = false
            pendingTime = undefined
            inlineRow = row
            inlineOriginalText = LKE_ValueText (LKE_ReadKeyValue context[3])
            inlineEditor.Text = inlineOriginalText
            inlineAcceleratorsState = enableAccelerators
            enableAccelerators = false
            local shown = LKE_InlineHost.Show liveList.Handle inlineEditor bounds.Left bounds.Top width bounds.Height
            if not shown then
            (
                CancelInlineEdit()
                lblStatus.text = "Cannot focus the Value editor. Refresh the list and retry."
                return false
            )
            lblStatus.text = "Edit Value: ENTER applies; ESC or focus change cancels. Time slider stays unchanged."
            true
        )

        fn CommitInlineEdit =
        (
            if inlineRow == undefined then return false
            local row = inlineRow
            local text = inlineEditor.Text as string
            if text == inlineOriginalText then (CancelInlineEdit(); return true)
            local context = try (LKE_ResolveRow row) catch (undefined)
            if context == undefined then
            (
                CancelInlineEdit()
                lblStatus.text = "Source track changed. Refresh before editing."
                return false
            )
            local value = LKE_ParseTyped text (LKE_ReadKeyValue context[3]) controller:context[1]
            if value == undefined then
            (
                lblStatus.text = "Invalid value for this key type. Correct the text, or press ESC."
                return false
            )
            CancelInlineEdit()
            local ok = false
            local reason = undefined
            try (ok = LKE_CommitEdit row #value row.keyTime value)
            catch (reason = getCurrentException() as string)
            RefreshList focusTime:row.keyTime
            if reason != undefined do lblStatus.text = "Value edit refused: " + reason
            ok
        )

        fn OnInlineKeyDown sender e =
        (
            local keys = dotNetClass "System.Windows.Forms.Keys"
            if e.KeyCode == keys.Enter then (e.SuppressKeyPress = true; CommitInlineEdit())
            else if e.KeyCode == keys.Escape then (e.SuppressKeyPress = true; CancelInlineEdit())
        )

        fn OnInlinePreviewKeyDown sender e =
        (
            local keys = dotNetClass "System.Windows.Forms.Keys"
            if e.KeyCode == keys.Enter or e.KeyCode == keys.Escape do e.IsInputKey = true
        )

        fn OnInlineKeyUp sender e =
        (
            -- Native dialog preprocessing can consume RETURN/ESC key-down.
            -- The session guard prevents a second commit after KeyDown succeeds.
            local keys = dotNetClass "System.Windows.Forms.Keys"
            if e.KeyCode == keys.Enter and inlineRow != undefined then
            (
                e.Handled = true
                CommitInlineEdit()
            )
            else if e.KeyCode == keys.Escape do
            (
                e.Handled = true
                CancelInlineEdit()
            )
        )

        fn OnInlineGotFocus sender e =
        (
            if inlineRow != undefined do
            (
                if inlineAcceleratorsState == undefined do inlineAcceleratorsState = enableAccelerators
                enableAccelerators = false
            )
        )

        fn OnInlineLostFocus sender e = (CancelInlineEdit())

        fn HandleValueDoubleClick x y =
        (
            local hit = lv.HitTest x y
            if hit.Item == undefined or hit.SubItem == undefined then return false
            if (hit.Item.SubItems.IndexOf hit.SubItem) != 2 then return false
            BeginInlineEdit (hit.Item.Tag as integer)
        )

        fn QueueValueEdit x y =
        (
            CancelInlineEdit()
            local hit = LKE_UI.lv.HitTest x y
            if hit.Item == undefined or hit.SubItem == undefined then return false
            if (hit.Item.SubItems.IndexOf hit.SubItem) != 2 then return false
            pendingInlineRow = hit.Item.Tag as integer
            -- Let the ListView finish its native double-click and mouse-up first.
            inlineStartDelay.active = true
            true
        )

        on inlineStartDelay tick do
        (
            inlineStartDelay.active = false
            local rowIndex = pendingInlineRow
            pendingInlineRow = undefined
            if rowIndex != undefined do BeginInlineEdit rowIndex
        )

        fn AutoRefreshAtTime t =
        (
            if not LKE_UI.isDisplayed or autoRefreshBusy or t == undefined or sliderTime != t then return false
            autoRefreshBusy = true
            local refreshed = false
            try
            (
                -- SELECT must refresh on empty frames too, to clear obsolete rows.
                local hit = (rbMode.state == 1)
                local seen = #()
                for node in selection where isValidNode node and not hit do
                    hit = LKE_HasKeyAtTime node t true seen 0
                if hit do
                (
                    refreshed = RefreshList focusTime:t
                    if refreshed do lblStatus.text += "   Auto @ " + LKE_FmtTime t
                )
            )
            catch (lblStatus.text = "Auto refresh failed: " + (getCurrentException() as string))
            autoRefreshBusy = false
            refreshed
        )

        fn OnTimeChanged =
        (
            -- Keep the time callback cheap; scan only after the slider settles.
            try
            (
                if LKE_UI.isDisplayed and not autoRefreshBusy do
                (
                    pendingTime = sliderTime
                    refreshDelay.active = false
                    refreshDelay.active = true
                )
            )
            catch ()
        )

        on refreshDelay tick do
        (
            refreshDelay.active = false
            AutoRefreshAtTime pendingTime
        )

        on LKE_UI close do
        (
            CancelInlineEdit()
            DisposeCategoryMenu()
            if inlineEditor != undefined do
            (
                dotNet.removeAllEventHandlers inlineEditor
                inlineEditor.Dispose()
                inlineEditor = undefined
            )
            refreshDelay.active = false
            pendingTime = undefined
            try (unregisterTimeCallback OnTimeChanged) catch ()
            if LKE_TimeCallback == OnTimeChanged do LKE_TimeCallback = undefined
        )

        on LKE_UI open do
        (
            hiddenCategoryKeys = #()
            onlyCategoryKey = undefined
            knownCategories = #()
            lv.View = (dotNetClass "System.Windows.Forms.View").Details
            lv.FullRowSelect = true
            lv.HideSelection = false
            lv.MultiSelect = false
            lv.GridLines = true
            lv.OwnerDraw = true
            lv.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").NonClickable
            lv.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 13.0
            lv.Columns.Add "Frame" 95
            lv.Columns.Add "Object / Track (SubAnim)" 455
            lv.Columns.Add "Value" 208
            lv.Columns.Add "Type" 110
            inlineEditor = dotNetObject "System.Windows.Forms.TextBox"
            dotNet.setLifetimeControl inlineEditor #mxs
            inlineEditor.Font = lv.Font
            -- The native Max dialog consumes RETURN for single-line child edits.
            -- ES_WANTRETURN requests the key; KeyDown suppresses the newline.
            inlineEditor.Multiline = true
            inlineEditor.AcceptsReturn = true
            inlineEditor.WordWrap = false
            inlineEditor.Visible = false
            -- Parent the editor lazily to the displayed ListView in BeginInlineEdit.
            dotNet.addEventHandler inlineEditor "PreviewKeyDown" OnInlinePreviewKeyDown
            dotNet.addEventHandler inlineEditor "KeyDown" OnInlineKeyDown
            dotNet.addEventHandler inlineEditor "KeyUp" OnInlineKeyUp
            dotNet.addEventHandler inlineEditor "GotFocus" OnInlineGotFocus
            dotNet.addEventHandler inlineEditor "LostFocus" OnInlineLostFocus

            txFrame.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0
            txValue.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0
            txAccess.Font = dotNetObject "System.Drawing.Font" "Consolas" 11.0
            txAccess.Multiline = true
            txAccess.ReadOnly = true
            txAccess.ScrollBars = (dotNetClass "System.Windows.Forms.ScrollBars").Horizontal

            RefreshList()
            LKE_TimeCallback = OnTimeChanged
            registerTimeCallback LKE_TimeCallback
        )

        on lv SelectedIndexChanged sender args do
        (
            if inlineRow != undefined do CancelInlineEdit()
            local r = GetSelectedRow()
            if r != undefined do DisplayRow r
        )

        on lv MouseDown sender e do
        (
            if e.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left do
            (
                if e.Clicks == 2 then QueueValueEdit e.X e.Y
                else if pendingInlineRow != undefined do CancelInlineEdit()
            )
        )

        on lv MouseUp sender e do
        (
            if e.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right do
            (
                CancelInlineEdit()
                local hit = lv.HitTest e.X e.Y
                local row = undefined
                if hit.Item != undefined and hit.SubItem != undefined do
                (
                    if (hit.Item.SubItems.IndexOf hit.SubItem) != 1 then return false
                    row = LKE_Rows[hit.Item.Tag as integer]
                    hit.Item.Selected = true
                )
                local menu = BuildCategoryMenu row
                menu.Show lv (dotNetObject "System.Drawing.Point" e.X e.Y)
            )
        )

        on lv MouseWheel sender e do CancelInlineEdit()
        on lv ColumnWidthChanged sender e do CancelInlineEdit()

        on lv DrawColumnHeader sender e do (e.DrawDefault = true)

        on lv DrawSubItem sender e do
        (
            -- Preserve the cell tint even when the row is selected automatically.
            if e.ColumnIndex == 1 and not e.Item.UseItemStyleForSubItems then
            (
                local brush = dotNetObject "System.Drawing.SolidBrush" e.SubItem.BackColor
                try
                (
                    e.Graphics.FillRectangle brush e.Bounds
                    local flags = dotNetClass "System.Windows.Forms.TextFormatFlags"
                    local textFlags = dotNet.combineEnums flags.Left flags.VerticalCenter flags.SingleLine flags.EndEllipsis flags.NoPrefix
                    (dotNetClass "System.Windows.Forms.TextRenderer").DrawText e.Graphics (e.SubItem.Text as string) lv.Font e.Bounds (dotNetClass "System.Drawing.Color").Black textFlags
                )
                catch (e.DrawDefault = true)
                brush.Dispose()
            )
            else e.DrawDefault = true
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
    createDialog LKE_UI 900 668 style:#(#style_titlebar, #style_sysmenu, #style_minimizebox) escapeEnable:false
)
