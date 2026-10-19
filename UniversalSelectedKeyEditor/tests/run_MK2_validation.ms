/* Isolated Batch: existing MK2 regressions followed by native-keyboard regression. */
(
    local folder = getFilenamePath (getThisScriptFilename())
    fileIn (folder + "run_MK2_tests.ms")
    fileIn (folder + "run_MK2_keyboard_tests.ms")
    fileIn (folder + "run_MK2_mouse_tests.ms")
)
