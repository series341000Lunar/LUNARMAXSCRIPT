/* Isolated Batch regression: dispatch native keyboard messages to the real editor. */
(
    local folder = getFilenamePath (getThisScriptFilename())
    local source = (dotNetClass "System.IO.File").ReadAllText (folder + "../Universal_Selected_Key_Editor_MK2.ms")
    local cases = (dotNetClass "System.IO.File").ReadAllText (folder + "keyboard_MK2_cases.ms")
    source = substituteString source "LKE_" "USKEK_"
    global USKEK_ReportPath = folder + "keyboard_MK2_report.txt"
    execute (substituteString source "createDialog USKEK_UI 900 668 style:#(#style_titlebar, #style_sysmenu, #style_minimizebox) escapeEnable:false" cases)
)
