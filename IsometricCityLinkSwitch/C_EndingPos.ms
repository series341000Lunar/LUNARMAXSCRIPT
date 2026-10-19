-- Save the current time, align at frame 0, then restore the saved time.
(
    local savedSliderTime = sliderTime
    local operationError = undefined
    try
    (
        sliderTime = 0f
        local root = getNodeByName "HLP_IsometricCity_Root" exact:true
        local target = getNodeByName "HLP_IsometricCity_EndingPos" exact:true
    
        if root == undefined or target == undefined then
            messageBox "Root or EndingPos node was not found." title:"Isometric City - C"
        else if classOf root.transform.controller != Link_Constraint then
            messageBox "Root must already have a Link Constraint." title:"Isometric City - C"
        else
        (
            undo "Isometric City - EndingPos" on
            (
                select root
                with animate off
                (
                    if root.transform.controller.addTarget target 0 then
                    (
                        local sourceTM = copy target.transform
                        local rootScale = root.transform.scalePart
                        local alignedTM = (scaleMatrix rootScale) * (sourceTM.rotationPart as matrix3)
                        alignedTM.row4 = sourceTM.row4
                        root.transform = alignedTM
                        redrawViews()
                        local positionError = distance root.transform.row4 target.transform.row4
                        format "C - Frame 0 pivot position error: % (scene units)\n" positionError
                        if positionError > 0.001 do
                            messageBox ("Alignment did not reach the target. Position error: " + (positionError as string)) title:"Isometric City - C"
                    )
                    else
                        messageBox "Could not add the link target." title:"Isometric City - C"
                )
            )
        )
    )
    catch
    (
        operationError = getCurrentException()
    )
    sliderTime = savedSliderTime
    if operationError != undefined do throw operationError
)
