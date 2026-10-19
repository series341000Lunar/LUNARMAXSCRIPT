global USKEK_Out = createFile USKEK_ReportPath
global USKEK_Passed = 0
global USKEK_Failed = 0
fn USKEK_Check condition label =
(
    if condition then USKEK_Passed += 1 else USKEK_Failed += 1
    format "% | %\n" (if condition then "PASS" else "FAIL") label to:USKEK_Out
)
fn USKEK_Log sender e =
(
    format "EVENT % | %\n" (classOf e) (try(e.KeyCode as string)catch("focus")) to:USKEK_Out
)
fn USKEK_Pump milliseconds =
(
    local deadline = timeStamp() + milliseconds
    while timeStamp() < deadline do
    (
        windows.processPostedMessages()
        (dotNetClass "System.Threading.Thread").Sleep 10
    )
)
fn USKEK_PostKey code =
(
    local handle = USKEK_UI.inlineEditor.Handle
    windows.postMessage handle 0x0100 code 0
    windows.postMessage handle 0x0101 code 0
    USKEK_Pump 250
)
local fixture = undefined
local savedSelection = selection as array
local savedTime = sliderTime
local savedAccel = enableAccelerators
try
(
    fixture = box name:(uniqueName "USKEK_Keyboard_")
    fixture.length.controller = bezier_float()
    local c = fixture.length.controller
    with animate on (at time 0f fixture.length = 10; at time 20f fixture.length = 20)
    select fixture
    sliderTime = 11f
    createDialog USKEK_UI 900 668 style:#(#style_titlebar, #style_sysmenu, #style_minimizebox) escapeEnable:false
    USKEK_UI.rbMode.state = 2
    USKEK_UI.RefreshList()
    local index = 0
    for i = 1 to USKEK_Rows.count where USKEK_Rows[i].controllerHandle == getHandleByAnim c and USKEK_Rows[i].keyTime == 20f do index = i
    if index == 0 then throw "Fixture key not found."
    for eventName in #("PreviewKeyDown", "KeyDown", "LostFocus") do dotNet.addEventHandler USKEK_UI.inlineEditor eventName USKEK_Log
    USKEK_UI.BeginInlineEdit index
    USKEK_UI.inlineEditor.Text = "91.125"
    format "BEFORE visible:% focused:% active:% accelerators:% value:%\n" USKEK_UI.inlineEditor.Visible USKEK_UI.inlineEditor.Focused (USKEK_UI.inlineRow != undefined) enableAccelerators (getKey c (getKeyIndex c 20f)).value to:USKEK_Out
    format "WM_GETDLGCODE: %\n" (windows.sendMessage USKEK_UI.inlineEditor.Handle 0x0087 13 0) to:USKEK_Out
    USKEK_Check (not enableAccelerators) "Max keyboard accelerators disabled while editing"
    USKEK_PostKey 13
    format "AFTER active:% value:% slider:% status:%\n" (USKEK_UI.inlineRow != undefined) (getKey c (getKeyIndex c 20f)).value sliderTime USKEK_UI.lblStatus.text to:USKEK_Out
    USKEK_Check ((getKey c (getKeyIndex c 20f)).value == 91.125 and sliderTime == 11f) "Native ENTER dispatch applies off-time key value without moving slider"
    USKEK_Check (USKEK_UI.inlineRow == undefined and enableAccelerators == savedAccel) "ENTER ends editing and restores accelerators"
    max undo
    USKEK_Check ((getKey c (getKeyIndex c 20f)).value == 20) "Native ENTER edit Undo"
    max redo
    USKEK_Check ((getKey c (getKeyIndex c 20f)).value == 91.125) "Native ENTER edit Redo"
    USKEK_UI.RefreshList()
    USKEK_UI.BeginInlineEdit index
    USKEK_UI.inlineEditor.Text = "invalid_token"
    USKEK_PostKey 13
    USKEK_Check (USKEK_UI.inlineRow != undefined and (getKey c (getKeyIndex c 20f)).value == 91.125) "Native ENTER rejects invalid input while keeping editor active"
    USKEK_PostKey 27
    USKEK_Check (USKEK_UI.isDisplayed and USKEK_UI.inlineRow == undefined and enableAccelerators == savedAccel) "Native ESC cancels edit, keeps dialog, and restores accelerators"
    USKEK_UI.BeginInlineEdit index
    destroyDialog USKEK_UI
    USKEK_Check (enableAccelerators == savedAccel) "Closing during editing restores accelerators"
)
catch(USKEK_Check false ("ERROR: " + (getCurrentException() as string)))
try(destroyDialog USKEK_UI)catch()
if isValidNode fixture do delete fixture
select (for n in savedSelection where isValidNode n collect n)
sliderTime = savedTime
enableAccelerators = savedAccel
format "SUMMARY: % passed; % failed\n" USKEK_Passed USKEK_Failed to:USKEK_Out
close USKEK_Out
