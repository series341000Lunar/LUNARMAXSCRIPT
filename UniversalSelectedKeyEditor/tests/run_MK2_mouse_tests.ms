/* Isolated Batch: real ListView mouse messages followed by TextBox key messages. */
(
    local folder = getFilenamePath (getThisScriptFilename())
    local source = (dotNetClass "System.IO.File").ReadAllText (folder + "../Universal_Selected_Key_Editor_MK2.ms")
    local cases = (dotNetClass "System.IO.File").ReadAllText (folder + "mouse_MK2_cases.ms")
    source = substituteString source "LKE_" "USKEM_"
    global USKEM_ReportPath = folder + "mouse_MK2_report.txt"
    execute (substituteString source "createDialog USKEM_UI 900 668 style:#(#style_titlebar, #style_sysmenu, #style_minimizebox) escapeEnable:false" cases)
)
