-- Injected into a renamed copy of the actual source by run_runtime_tests.ms.
global USKET_Out = createFile USKET_ReportPath
global USKET_Passed = 0
global USKET_Failed = 0
fn USKET_Check condition label =
(
    if condition then USKET_Passed += 1 else USKET_Failed += 1
    format "% | %\n" (if condition then "PASS" else "FAIL") label to:USKET_Out
)
fn USKET_Scan node allKeys =
(
    USKET_Rows = #()
    USKET_SeenHandles = #()
    USKET_Walk node node.name "testNode" (getHandleByAnim node) allKeys 0 #()
    USKET_Rows
)
fn USKET_Row node controller time =
(
    USKET_Scan node true
    for row in USKET_Rows where row.controllerHandle == getHandleByAnim controller and row.keyTime == time do return row
    undefined
)
fn USKET_Refused row operation target value =
(
    local failed = false
    try (USKET_CommitEdit row operation target value) catch (failed = true; format "REFUSAL | %\n" (getCurrentException()) to:USKET_Out)
    failed
)
fn USKET_Pump milliseconds =
(
    local deadline = timeStamp() + milliseconds
    while timeStamp() < deadline do
    (
        windows.processPostedMessages()
        (dotNetClass "System.Threading.Thread").Sleep 10
    )
)
format "Host: %\n" (maxVersion()) to:USKET_Out
local savedSelection = selection as array
local savedTime = sliderTime
local fixtures = #()
local fatal = undefined
try
(
    local node
    undo "USKE Tests - Fixture" on
    (
        node = box name:(uniqueName "USKET_Fixture_") width:1 length:1 height:1
        append fixtures node
        node.length.controller = bezier_float()
        local c = node.length.controller
        for t in #(0f, 10f, 20f) do (addNewKey c t).value = 123.456789
        deselectKeys c
        selectKey c 2
    )
    local c = node.length.controller
    USKET_Scan node false
    USKET_Check (USKET_Rows.count == 1 and USKET_Rows[1].keyTime == 10f) "SELECT collects only the selected key"
    USKET_Scan node true
    USKET_Check (USKET_Rows.count == 3) "ALL collects selected and unselected keys"
    local row = USKET_Row node c 10f
    local exact = (getKey c 2).value
    local before = USKET_KeyState c details:true
    USKET_Check (USKET_Refused row #move 20f exact) "Occupied target refused"
    USKET_Check (deepEqual before (USKET_KeyState c details:true)) "Collision refusal preserves all source keys"
    USKET_Check (USKET_CommitEdit row #move 12f exact) "Move within neighboring interval"
    USKET_Check ((getKey c (getKeyIndex c 12f)).value == exact) "Move preserves Float bits without text roundtrip"
    local undoNames = theHold.getUndoNames()
    if findItem undoNames "LKE - move" == 0 then throw "Edit was not recorded in Undo; no unrelated Undo will be issued."
    max undo
    USKET_Check ((getKeyIndex c 10f) > 0 and deepEqual before (USKET_KeyState c details:true)) "Undo restores move and key metadata"
    max redo
    USKET_Check ((getKeyIndex c 12f) > 0) "Redo restores move"
    row = USKET_Row node c 12f
    local beforeCrossing = USKET_KeyState c details:true
    USKET_Check (USKET_CommitEdit row #move 30f exact) "Crossing move using native key copy"
    USKET_Check ((numKeys c == 3) and (getKeyIndex c 12f) == 0 and (getKey c (getKeyIndex c 30f)).value == exact) "Crossing move preserves count and exact value"
    max undo
    USKET_Check (deepEqual beforeCrossing (USKET_KeyState c details:true)) "Crossing move Undo restores original key metadata"
    max redo
    USKET_Check ((getKeyIndex c 30f) > 0 and (getKeyIndex c 12f) == 0) "Crossing move Redo"
    row = USKET_Row node c 30f
    USKET_Check (USKET_CommitEdit row #new 40f exact) "Create new key from existing track"
    USKET_Check ((getKey c (getKeyIndex c 40f)).value == exact) "New key preserves unedited raw Float value"
    row = USKET_Row node c 40f
    USKET_Check (USKET_CommitEdit row #value 40f 55.25) "Apply typed Float value"
    row = USKET_Row node c 40f
    before = USKET_KeyState c details:true
    local undoBeforeFailure = theHold.getUndoNames()
    USKET_TestFailAfterWrite = true
    USKET_Check (USKET_Refused row #new 50f 99.0) "Injected failure after actual key insertion is caught"
    USKET_TestFailAfterWrite = false
    USKET_Check (deepEqual before (USKET_KeyState c details:true)) "Rollback restores key count, times, values, selection and common metadata"
    USKET_Check (deepEqual undoBeforeFailure (theHold.getUndoNames())) "Cancelled edit leaves prior Undo entries intact"
    USKET_TestFailAfterWrite = true
    USKET_Check (USKET_Refused row #move (-10f) 55.25) "Injected failure after actual crossing move is caught"
    USKET_TestFailAfterWrite = false
    USKET_Check (deepEqual before (USKET_KeyState c details:true)) "Crossing move rollback restores original keys"
    row = USKET_Row node c 40f
    undo "USKE Tests - External change" on ((getKey c (getKeyIndex c 40f)).value = 66.0)
    USKET_Check (USKET_Refused row #value 40f 77.0) "External value change refused"
    row = USKET_Row node c 40f
    undo "USKE Tests - Replace controller" on (node.length.controller = copy c)
    USKET_Check (USKET_ResolveRow row == undefined) "Detached original controller cannot be edited through stale row"
    c = node.length.controller

    undo "USKE Tests - More types" on
    (
        node.visibility = boolean_float()
        (addNewKey node.visibility.controller 0f).value = 1.0
        node.position.controller = bezier_position()
        (addNewKey node.position.controller 0f).value = [1.234567,2,3]
        (addNewKey node.position.controller 10f).value = [4,5,6]
        (addNewKey node.position.controller 20f).value = [7,8,9]
        local bendMod = Bend()
        addModifier node bendMod
        bendMod.angle.controller = bezier_float()
        (addNewKey bendMod.angle.controller 0f).value = 0.25
    )
    local bc = node.visibility.controller
    USKET_Check ((USKET_ParseTyped "true" 1.0 controller:bc) == 1.0 and (USKET_ParseTyped "off" 1.0 controller:bc) == 0.0) "Boolean Controller accepts Boolean tokens as Float 0/1"
    USKET_Check ((USKET_ParseTyped "2" 1.0 controller:bc) == undefined) "Boolean Controller rejects non-binary value"
    row = USKET_Row node bc 0f
    USKET_Check (USKET_CommitEdit row #value 0f 0.0) "Apply Boolean Controller value"
    local pc = node.position.controller
    row = USKET_Row node pc 0f
    local pointValue = (getKey pc 1).value
    USKET_Check (USKET_CommitEdit row #move 30f pointValue) "Point3 crossing move"
    USKET_Check (deepEqual (getKey pc (getKeyIndex pc 30f)).value pointValue) "Point3 exact value preserved"
    USKET_Check ((USKET_ParseTyped "[9,8,7]" [0,0,0]) == [9,8,7]) "Point3 typed parse"
    USKET_Check ((USKET_ParseTyped "2.5" 1) == undefined and (USKET_ParseTyped "2" 1) == 2) "Integer parser rejects Float coercion"
    local ac = node.modifiers[1].angle.controller
    row = USKET_Row node ac 0f
    USKET_Check (row != undefined and USKET_CommitEdit row #value 0f 0.5) "Modifier Bend Angle raw Float track resolved and edited"

    local lightNode
    undo "USKE Tests - Light" on
    (
        lightNode = OmniLight name:(uniqueName "USKET_Light_")
        append fixtures lightNode
        lightNode.multiplier.controller = bezier_float()
        (addNewKey lightNode.multiplier.controller 0f).value = 1.0
    )
    local lc = lightNode.multiplier.controller
    row = USKET_Row lightNode lc 0f
    USKET_Check (row != undefined and USKET_CommitEdit row #value 0f 2.0) "Standard light intensity raw Float edited"

    undo "USKE Tests - Unkeyed and toggle tracks" on
    (
        node.height.controller = bezier_float()
        node.width.controller = On_Off()
        addNewKey node.width.controller 0f
    )
    USKET_Scan node true
    USKET_Check ((for r in USKET_Rows where r.controllerHandle == getHandleByAnim node.height.controller collect r).count == 0) "Unkeyed tracks remain excluded (no first-key feature)"
    local toggle = node.width.controller
    row = USKET_Row node toggle 0f
    USKET_Check (row == undefined) "Traditional On-Off unsupported getKey API safely omitted"
    USKET_Check ((numKeys toggle == 1) and (getKeyTime toggle 1) == 0f) "On-Off scan preserves toggle keys"

    with undo off (select node)
    createDialog USKET_UI 900 668 style:#(#style_titlebar, #style_sysmenu)
    USKET_Check (USKET_UI.rbMode.state == 1) "UI opens in SELECT mode"
    local selectedCount = USKET_Rows.count
    USKET_UI.rbMode.state = 2
    USKET_UI.RefreshList()
    USKET_Check (USKET_Rows.count > selectedCount) "UI ALL mode refresh shows more keys"
    USKET_Check (USKET_UI.GetWriteContext() != undefined) "UI resolves selected row into write context"
    USKET_UI.txValue.Text = "[invalid input]"
    USKET_Check (USKET_UI.GetWriteContext readInput:false != undefined) "Time-only move ignores unapplied value text"
    -- Reorder the displayed rows; Tag must still resolve the source row.
    if USKET_UI.lv.Items.Count > 1 do
    (
        local item = USKET_UI.lv.Items.Item[1]
        local tag = item.Tag as integer
        USKET_UI.lv.Items.Remove item
        USKET_UI.lv.Items.Insert 0 item
        for i = 0 to USKET_UI.lv.Items.Count-1 do USKET_UI.lv.Items.Item[i].Selected = false
        item.Selected = true
        USKET_Check (USKET_UI.GetSelectedRow() == USKET_Rows[tag]) "Reordered list uses stable row Tag"
    )
    local callbackCount = (for entry in (showregisteredTimeCallbacks asArray:true) where entry[3] == USKET_TimeCallback collect entry).count
    USKET_Check (callbackCount == 1) "Time callback registered exactly once"
    USKET_UI.lblStatus.text = "NO_KEY_SENTINEL"
    sliderTime = 3f
    USKET_Pump 300
    USKET_Check (USKET_UI.lblStatus.text == "NO_KEY_SENTINEL") "Unkeyed frame does not refresh"
    undo "USKE Tests - External value before time jump" on ((getKey c (getKeyIndex c 40f)).value = 88.0)
    sliderTime = 40f
    USKET_Pump 350
    USKET_Check ((findString USKET_UI.lblStatus.text "Auto @ 40") != undefined) "sliderTime assignment triggers delayed auto refresh on keyed frame"
    local freshRows = for r in USKET_Rows where r.controllerHandle == getHandleByAnim c and r.keyTime == 40f collect r
    USKET_Check (freshRows.count == 1 and freshRows[1].sampledValue == 88.0) "Auto refresh reads current key value from scene"
    USKET_Check ((USKET_UI.GetSelectedRow()).keyTime == 40f) "Auto refresh selects the current sliderTime row"
    USKET_Check (USKET_UI.txFrame.Text as string == "40") "Auto-selected key populates editor with current frame"
    sliderTime = 0f
    USKET_Pump 350
    USKET_Check ((USKET_UI.GetSelectedRow()).controllerHandle == getHandleByAnim c and (USKET_UI.GetSelectedRow()).keyTime == 0f) "Multiple current-frame keys prefer previously selected controller"
    sliderTime = 10f
    USKET_Pump 350
    USKET_Check ((USKET_UI.GetSelectedRow()).keyTime == 10f) "Missing preferred track falls back to another current-frame row"
    -- More rows than the viewport can hold, with the destination near the end.
    undo "USKE Tests - Scroll fixture keys" on
        (for t = 50 to 100 do (addNewKey c (t * 1f)).value = t as float)
    sliderTime = 100f
    USKET_Pump 1000
    local selectedItem = USKET_UI.lv.SelectedItems.Item[0]
    format "SCROLL PROBE | slider:% selected:% status:% count:% topIndex:% bounds:% clientHeight:%\n" sliderTime (USKET_UI.GetSelectedRow()).keyTime USKET_UI.lblStatus.text USKET_UI.lv.Items.Count USKET_UI.lv.TopItem.Index selectedItem.Bounds USKET_UI.lv.ClientSize.Height to:USKET_Out
    USKET_Check ((USKET_UI.GetSelectedRow()).keyTime == 100f) "Auto refresh selects a keyed frame far down a long list"
    USKET_Check (selectedItem.Bounds.Top >= 0 and selectedItem.Bounds.Bottom <= USKET_UI.lv.ClientSize.Height and USKET_UI.lv.TopItem.Index > 0) "EnsureVisible scrolls far-down selected row into list viewport"
    USKET_Check (selectedItem.Focused) "Auto-selected current-frame row has list item focus"
    USKET_UI.rbMode.state = 1
    USKET_UI.RefreshList()
    deselectKeys c
    USKET_UI.lblStatus.text = "UNSELECTED_KEY_SENTINEL"
    sliderTime = 39f
    USKET_Pump 250
    sliderTime = 40f
    USKET_Pump 350
    USKET_Check ((findString USKET_UI.lblStatus.text "Auto @ 40") != undefined) "SELECT mode auto-refreshes on unselected current-frame key"
    USKET_Check ((USKET_UI.GetSelectedRow()).keyTime == 40f) "Unselected current-frame key is displayed and selected in list"
    USKET_Check (not (isKeySelected c (getKeyIndex c 40f))) "Automatic list selection leaves scene key unselected"
    USKET_Check ((for r in USKET_Rows where r.controllerHandle == getHandleByAnim c and r.keyTime == 100f collect r).count == 0) "SELECT does not include unselected keys at other frames"
    selectKey c (getKeyIndex c 40f)
    sliderTime = 39f
    USKET_Pump 250
    sliderTime = 40f
    USKET_Pump 350
    USKET_Check ((findString USKET_UI.lblStatus.text "Auto @ 40") != undefined) "SELECT mode refreshes on selected key"
    undo "USKE Tests - Uncached key" on ((addNewKey c 45f).value = 777.0)
    sliderTime = 45f
    USKET_Pump 350
    freshRows = for r in USKET_Rows where r.controllerHandle == getHandleByAnim c and r.keyTime == 45f collect r
    USKET_Check (freshRows.count == 1 and freshRows[1].sampledValue == 777.0) "New unselected uncached key triggers live probe and refresh"
    USKET_Check ((USKET_UI.GetSelectedRow()).keyTime == 45f and not (isKeySelected c (getKeyIndex c 45f))) "New unselected key auto-focuses without changing scene selection"
    USKET_UI.lblStatus.text = "DEBOUNCE_SENTINEL"
    sliderTime = 40f
    sliderTime = 41f
    USKET_Pump 350
    USKET_Check (USKET_UI.lblStatus.text == "DEBOUNCE_SENTINEL") "Rapid changes debounce to final unkeyed frame"
    local registeredFunction = USKET_TimeCallback
    destroyDialog USKET_UI
    callbackCount = (for entry in (showregisteredTimeCallbacks asArray:true) where entry[3] == registeredFunction collect entry).count
    USKET_Check (callbackCount == 0 and USKET_TimeCallback == undefined) "Closing UI unregisters callback"
    createDialog USKET_UI 900 668 style:#(#style_titlebar, #style_sysmenu)
    callbackCount = (for entry in (showregisteredTimeCallbacks asArray:true) where entry[3] == USKET_TimeCallback collect entry).count
    USKET_Check (callbackCount == 1) "Reopening UI registers one callback without duplicates"
    destroyDialog USKET_UI
)
catch (fatal = getCurrentException() as string; USKET_Check false ("FATAL: " + fatal); format "%\n" (getCurrentExceptionStackTrace()) to:USKET_Out)
try (destroyDialog USKET_UI) catch ()
undo "USKE Tests - Cleanup" on (for n in fixtures where isValidNode n do delete n)
with undo off (select (for n in savedSelection where isValidNode n collect n))
sliderTime = savedTime
format "SUMMARY: % passed; % failed\n" USKET_Passed USKET_Failed to:USKET_Out
format "Manual visual acceptance / V-Ray / tyFlow / native Integer controller: NOT TESTED\n" to:USKET_Out
close USKET_Out
