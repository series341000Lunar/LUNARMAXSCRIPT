/*
    Thin launcher for Lunar Transform Assistant.
    The implementation remains in src/LunarTransformAssistant.ms.
*/

macroScript LunarTransformAssistant
category:"Lunar Tools"
internalCategory:"Lunar Tools"
tooltip:"Lunar Transform Assistant"
buttonText:"Lunar Transform Assistant"
autoUndoEnabled:false
(
    local launcherSource = getSourceFileName()

    on execute do
    (
        if ::LunarTransformAssistantRollout != undefined then
        (
            if ::LunarTransformAssistantRollout.isDisplayed then
            (
                ::LunarTransformAssistantRollout.visible = true
                setFocus ::LunarTransformAssistantRollout
            )
            else
            (
                createDialog ::LunarTransformAssistantRollout 380 886 \
                    style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
            )
        )
        else
        (
            local mainScript = undefined
            local candidates = #()

            if launcherSource != undefined and launcherSource != "" do
                append candidates ((getFilenamePath launcherSource) + "..\\src\\LunarTransformAssistant.ms")

            append candidates ((getDir #userScripts) + "\\LunarTransformAssistant\\src\\LunarTransformAssistant.ms")

            for candidate in candidates while mainScript == undefined do
            (
                if doesFileExist candidate do mainScript = candidate
            )

            if mainScript != undefined then
            (
                fileIn mainScript
            )
            else
            (
                local message = "LunarTransformAssistant.ms was not found.\n\n" +
                    "Expected either beside this project launcher at:\n" +
                    "..\\src\\LunarTransformAssistant.ms\n\nor under:\n" +
                    (getDir #userScripts) + "\\LunarTransformAssistant\\src\\LunarTransformAssistant.ms"
                format "[LTA][ERROR] %\n" message
                messageBox message title:"Lunar Transform Assistant"
            )
        )
    )
)
