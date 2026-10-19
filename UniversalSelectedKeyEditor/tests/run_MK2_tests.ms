/* Run manually in 3ds Max 2027. Creates/deletes only its own temporary fixture.
   Preserves selection and slider time; does not save/reset/clear Undo.
   Uses a separate USKET_ namespace so the user's editor is not replaced. */
(
    local testFolder = getFilenamePath (getThisScriptFilename())
    local toolPath = testFolder + "../Universal_Selected_Key_Editor_MK2.ms"
    local source = (dotNetClass "System.IO.File").ReadAllText toolPath
    local cases = (dotNetClass "System.IO.File").ReadAllText (testFolder + "runtime_MK2_cases.ms")
    source = substituteString source "LKE_" "USKET_"
    -- Fault injection exists ONLY in this in-memory test copy of the source.
    global USKET_TestFailAfterWrite = false
    source = substituteString source "if not (deepEqual (USKET_KeyState c) planned)" "if USKET_TestFailAfterWrite then throw \"Injected failure after real controller mutation\"; if not (deepEqual (USKET_KeyState c) planned)"
    local marker = "createDialog USKET_UI 900 668 style:#(#style_titlebar, #style_sysmenu, #style_minimizebox) escapeEnable:false"
    if findString source marker == undefined then throw "Test insertion marker missing."
    global USKET_ReportPath = testFolder + "runtime_MK2_report.txt"
    execute (substituteString source marker cases)
)
