global USKEM_Out = createFile USKEM_ReportPath
global USKEM_Passed = 0
global USKEM_Failed = 0
fn USKEM_Check condition label =
(
    if condition then USKEM_Passed += 1 else USKEM_Failed += 1
    format "% | %\n" (if condition then "PASS" else "FAIL") label to:USKEM_Out
)
fn USKEM_Log sender e =
(
    format "EVENT % | active:% visible:% focused:%\n" ((e.GetType()).FullName) (USKEM_UI.inlineRow != undefined) USKEM_UI.inlineEditor.Visible USKEM_UI.inlineEditor.Focused to:USKEM_Out
)
fn USKEM_Pump milliseconds =
(
    local deadline = timeStamp() + milliseconds
    while timeStamp() < deadline do (windows.processPostedMessages(); (dotNetClass "System.Threading.Thread").Sleep 10)
)
fn USKEM_DoubleClick x y =
(
    local handle = USKEM_UI.lv.Handle
    local position = y * 65536 + x
    windows.postMessage handle 0x0201 1 position
    windows.postMessage handle 0x0202 0 position
    windows.postMessage handle 0x0203 1 position
    windows.postMessage handle 0x0202 0 position
    USKEM_Pump 300
)
fn USKEM_Key code =
(
    local handle = USKEM_UI.inlineEditor.Handle
    windows.postMessage handle 0x0100 code 0
    windows.postMessage handle 0x0101 code 0
    USKEM_Pump 200
)
local fixture = undefined
local savedSelection = selection as array
local savedTime = sliderTime
local savedAccel = enableAccelerators
try
(
    fixture = box name:(uniqueName "USKEM_Mouse_")
    fixture.length.controller = bezier_float()
    local c = fixture.length.controller
    with animate on (at time 0f fixture.length = 10; at time 20f fixture.length = 20)
    select fixture
    sliderTime = 11f
    createDialog USKEM_UI 900 668 style:#(#style_titlebar, #style_sysmenu, #style_minimizebox) escapeEnable:false
    USKEM_UI.rbMode.state = 2
    USKEM_UI.RefreshList()
    local listHost = (dotNetClass "System.Windows.Forms.Control").FromHandle USKEM_UI.lv.Handle
    listHost.Focus()
    USKEM_Pump 100
    gc light:true
    (dotNetClass "System.GC").Collect()
    USKEM_Check (not USKEM_UI.inlineEditor.IsDisposed) "Unparented editor survives MAXScript and .NET collection until first use"
    local index = 0
    for i = 1 to USKEM_Rows.count where USKEM_Rows[i].controllerHandle == getHandleByAnim c and USKEM_Rows[i].keyTime == 20f do index = i
    if index == 0 then throw "Fixture key missing."
    local item = USKEM_UI.lv.Items.Item[index-1]
    item.EnsureVisible()
    local cell = item.SubItems.Item[2].Bounds
    for eventName in #("GotFocus", "LostFocus") do dotNet.addEventHandler USKEM_UI.inlineEditor eventName USKEM_Log
    format "HOST list-visible:% cell:%\n" USKEM_UI.lv.Visible cell to:USKEM_Out
    USKEM_DoubleClick 8 (cell.Top+8)
    USKEM_Check (USKEM_UI.inlineRow == undefined) "Frame column double-click does not start Value editing"
    local editAccel = enableAccelerators
    USKEM_DoubleClick (cell.Left+8) (cell.Top+8)
    USKEM_Check (USKEM_UI.inlineRow != undefined) "Native double-click starts and retains edit session after mouse-up"
    USKEM_Check (USKEM_UI.inlineEditor.Visible and USKEM_UI.inlineEditor.Focused) "Double-click input remains visible and focused after message pump"
    USKEM_Check (USKEM_UI.inlineEditor.Parent.Handle == USKEM_UI.lv.Handle) "Input is parented to the displayed ListView native handle"
    if USKEM_UI.inlineRow == undefined then throw "Double-click did not leave an editable Value cell."
    for characterCode in #(55,56,46,50,53) do windows.postMessage USKEM_UI.inlineEditor.Handle 0x0102 characterCode 0
    USKEM_Pump 100
    USKEM_Check ((USKEM_UI.inlineEditor.Text as string) == "78.25") "Native character input replaces selected Value text"
    USKEM_Key 13
    format "AFTER ENTER value:% active:% status:%\n" (getKey c (getKeyIndex c 20f)).value (USKEM_UI.inlineRow != undefined) USKEM_UI.lblStatus.text to:USKEM_Out
    USKEM_Check ((getKey c (getKeyIndex c 20f)).value == 78.25 and sliderTime == 11f) "Double-click then native ENTER changes source key without time jump"
    USKEM_Check (USKEM_UI.inlineRow == undefined and enableAccelerators == editAccel) "Mouse edit commit restores accelerator state from before editing"
    max undo
    USKEM_Check ((getKey c (getKeyIndex c 20f)).value == 20) "Mouse and keyboard edit Undo restores original value"
    max redo
    USKEM_Check ((getKey c (getKeyIndex c 20f)).value == 78.25) "Mouse and keyboard edit Redo restores typed value"
)
catch(USKEM_Check false ("ERROR: " + (getCurrentException() as string)))
try(destroyDialog USKEM_UI)catch()
if isValidNode fixture do delete fixture
select (for n in savedSelection where isValidNode n collect n)
sliderTime = savedTime
enableAccelerators = savedAccel
format "SUMMARY: % passed; % failed\n" USKEM_Passed USKEM_Failed to:USKEM_Out
close USKEM_Out
