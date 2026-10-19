-- Go to frame 0, register the link target, then match world rotation/position.
(
    sliderTime = 0f
    local root = getNodeByName "HLP_IsometricCity_Root" exact:true
    local target = getNodeByName "HLP_IsometricCity_GrandOriginalPos" exact:true

    if root == undefined or target == undefined then
        messageBox "Root or GrandOriginalPos node was not found." title:"Isometric City - B"
    else if classOf root.transform.controller != Link_Constraint then
        messageBox "Root must already have a Link Constraint." title:"Isometric City - B"
    else
    (
        undo "Isometric City - GrandOriginalPos" on
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
                    format "B - Frame 0 pivot position error: % (scene units)\n" positionError
                    if positionError > 0.001 do
                        messageBox ("Alignment did not reach the target. Position error: " + (positionError as string)) title:"Isometric City - B"
                )
                else
                    messageBox "Could not add the link target." title:"Isometric City - B"
            )
        )
    )
)
