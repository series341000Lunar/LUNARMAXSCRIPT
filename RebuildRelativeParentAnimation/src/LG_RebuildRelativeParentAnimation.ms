/*
    Rebuild Relative Parent Animation - MAXScript only.
    The engine is intentionally callable without the rollout for batch verification.
    A sampled world trajectory is exact only at the sampled frames.
*/

global RRPA_Rollout
global rrpaRebuild

fn rrpaLog level message = format "[RRPA][%] %\n" level message

fn rrpaSelectedNodes =
(
    local result = #()
    for n in selection where isValidNode n do if (findItem result n) == 0 do append result n
    result
)

fn rrpaDeterminant tm = dot (cross tm.row1 tm.row2) tm.row3

fn rrpaHasShear tm =
(
    local a = tm.row1
    local b = tm.row2
    local c = tm.row3
    local la = length a
    local lb = length b
    local lc = length c
    if la < 1e-7 or lb < 1e-7 or lc < 1e-7 then true
    else
        (abs (dot a b) / (la * lb) > 1e-4) or
        (abs (dot a c) / (la * lc) > 1e-4) or
        (abs (dot b c) / (lb * lc) > 1e-4)
)

fn rrpaNearestAngle value reference = value + (360.0 * (floor ((reference - value) / 360.0 + 0.5)))

fn rrpaContinuousEuler quatValue previous =
(
    local e = quatToEuler quatValue order:1
    if previous == undefined then return e
    local candidateA = eulerAngles (rrpaNearestAngle e.x previous.x) (rrpaNearestAngle e.y previous.y) (rrpaNearestAngle e.z previous.z)
    local alternate = eulerAngles (e.x + 180.0) (180.0 - e.y) (e.z + 180.0)
    local candidateB = eulerAngles (rrpaNearestAngle alternate.x previous.x) (rrpaNearestAngle alternate.y previous.y) (rrpaNearestAngle alternate.z previous.z)
    local da = (candidateA.x-previous.x)^2 + (candidateA.y-previous.y)^2 + (candidateA.z-previous.z)^2
    local db = (candidateB.x-previous.x)^2 + (candidateB.y-previous.y)^2 + (candidateB.z-previous.z)^2
    if db < da then candidateB else candidateA
)

fn rrpaRotationError a b =
(
    local qa = normalize a.rotationPart
    local qb = normalize b.rotationPart
    local dotValue = qa.x*qb.x + qa.y*qb.y + qa.z*qb.z + qa.w*qb.w
    local signValue = if dotValue < 0.0 then -1.0 else 1.0
    local dx = qa.x - signValue*qb.x
    local dy = qa.y - signValue*qb.y
    local dz = qa.z - signValue*qb.z
    local dw = qa.w - signValue*qb.w
    local chord = sqrt (dx*dx + dy*dy + dz*dz + dw*dw)
    4.0 * asin (amin 1.0 (chord*0.5))
)

fn rrpaIsAncestor ancestor nodeValue =
(
    local cursor = nodeValue.parent
    while cursor != undefined do
    (
        if cursor == ancestor then return true
        cursor = cursor.parent
    )
    false
)

/* Returns #(success, status, maxPos, maxRot, posNode, posFrame,
             rotNode, rotFrame, message). Errors never leave a partial bake. */
fn rrpaRebuild parentNode childNodes bakeScale:false =
(
    local originalTime = currentTime
    local result = #(false, #ERROR, 0.0, 0.0, "", 0, "", 0, "")
    local holdStarted = false
    local sourceFrames = #()
    local parentFrames = #()
    local childFrames = #()
    local localFrames = #()
    local frameStart = animationRange.start
    local frameEnd = animationRange.end
    local posTolerance = 0.0001
    local rotTolerance = 0.01

    try
    (
        if parentNode == undefined or not isValidNode parentNode do throw "Parent is missing or invalid."
        if childNodes == undefined or childNodes.count < 1 do throw "Select at least one Child."
        if theHold.Holding() do throw "Another Undo operation is active. Run this tool after it finishes."
        local uniqueChildren = #()
        for child in childNodes do
        (
            if child == undefined or not isValidNode child do throw "A Child is missing or invalid."
            if child == parentNode do throw "Parent cannot also be a Child."
            if rrpaIsAncestor child parentNode do throw ("Parent cycle: " + child.name + " is an ancestor of Parent.")
            if (findItem uniqueChildren child) == 0 do append uniqueChildren child
        )

        /* Phase A: read every source world Matrix3 before any scene mutation. */
        for t = frameStart to frameEnd by 1f do
        (
            append sourceFrames t
            at time t
            (
                append parentFrames (copy parentNode.transform)
                local row = #()
                for child in uniqueChildren do append row (copy child.transform)
                append childFrames row
            )
        )
        if sourceFrames.count < 1 do throw "Animation Range has no sampled frames."

        /* Phase B: compute every local TM, check inverse and representability. */
        for fi = 1 to sourceFrames.count do
        (
            local parentTM = parentFrames[fi]
            local det = rrpaDeterminant parentTM
            if abs det < 1e-8 do
                throw ("Singular Parent matrix at frame " + (sourceFrames[fi] as string) + ".")
            local parentInverse = inverse parentTM
            local row = #()
            for ci = 1 to uniqueChildren.count do
            (
                local localTM = childFrames[fi][ci] * parentInverse
                if rrpaHasShear localTM do
                    throw ("Unsupported shear or zero scale: " + uniqueChildren[ci].name + " at frame " + (sourceFrames[fi] as string) + ".")
                if localTM.determinantSign < 0 do
                    throw ("Mirrored local transform is unsupported: " + uniqueChildren[ci].name + " at frame " + (sourceFrames[fi] as string) + ".")
                append row localTM
            )
            append localFrames row
        )

        /* Phase C: one undoable transaction; explicit Cancel on any failure. */
        theHold.Begin()
        holdStarted = true
        with redraw off
        (
            for ci = 1 to uniqueChildren.count do
            (
                local child = uniqueChildren[ci]
                child.parent = parentNode
                child.transform.controller = NewDefaultMatrix3Controller()
                local prsCtrl = child.transform.controller
                prsCtrl[1].controller = Position_XYZ()
                prsCtrl[2].controller = Euler_XYZ()
                prsCtrl[3].controller = linear_scale()
                local posCtrl = prsCtrl[1].controller
                local rotCtrl = prsCtrl[2].controller
                posCtrl[1].controller = linear_float()
                posCtrl[2].controller = linear_float()
                posCtrl[3].controller = linear_float()
                rotCtrl[1].controller = linear_float()
                rotCtrl[2].controller = linear_float()
                rotCtrl[3].controller = linear_float()

                local previousEuler = undefined
                for fi = 1 to sourceFrames.count do
                (
                    local localTM = localFrames[fi][ci]
                    local keyTM = copy localTM
                    if not bakeScale do
                    (
                        keyTM = matrix3 1
                        keyTM.rotation = localTM.rotationPart
                        keyTM.translation = localTM.translationPart
                    )
                    local e = rrpaContinuousEuler localTM.rotationPart previousEuler
                    previousEuler = e
                    at time sourceFrames[fi] with animate on
                    (
                        /* Direct PRS.value is evaluated with an identity parent matrix. */
                        prsCtrl.value = keyTM
                        /* Override decomposed Euler values with continuous equivalents. */
                        rotCtrl.x_rotation = e.x
                        rotCtrl.y_rotation = e.y
                        rotCtrl.z_rotation = e.z
                    )
                )
            )
        )

        /* Phase D: verify all Child world TMs and that Parent motion survived. */
        local maxPos = 0.0
        local maxRot = 0.0
        local worstPosNode = ""
        local worstRotNode = ""
        local worstPosFrame = 0
        local worstRotFrame = 0
        for fi = 1 to sourceFrames.count do
        (
            at time sourceFrames[fi]
            (
                local nowParent = copy parentNode.transform
                local parentPosError = distance nowParent.translationPart parentFrames[fi].translationPart
                local parentRotError = rrpaRotationError nowParent parentFrames[fi]
                if parentPosError > posTolerance or parentRotError > rotTolerance do
                    throw ("Parent world motion changed at frame " + (sourceFrames[fi] as string) +
                        ": position=" + (parentPosError as string) + ", rotation=" +
                        (parentRotError as string) + " deg.")
                for ci = 1 to uniqueChildren.count do
                (
                    local child = uniqueChildren[ci]
                    local bakedTM = copy child.transform
                    local sourceTM = childFrames[fi][ci]
                    local posError = distance bakedTM.translationPart sourceTM.translationPart
                    local rotError = rrpaRotationError bakedTM sourceTM
                    if bakeScale do
                    (
                        local basisError = amax (length (bakedTM.row1 - sourceTM.row1))
                            (amax (length (bakedTM.row2 - sourceTM.row2)) (length (bakedTM.row3 - sourceTM.row3)))
                        if basisError > posTolerance do
                            throw ("Scale/basis validation failed: " + child.name + " at frame " +
                                (sourceFrames[fi] as string) + ", error=" + (basisError as string) + ".")
                    )
                    if posError > maxPos do
                    (
                        maxPos = posError
                        worstPosNode = child.name
                        worstPosFrame = (sourceFrames[fi] / ticksPerFrame) as integer
                    )
                    if rotError > maxRot do
                    (
                        maxRot = rotError
                        worstRotNode = child.name
                        worstRotFrame = (sourceFrames[fi] / ticksPerFrame) as integer
                    )
                )
            )
        )
        if maxPos > posTolerance or maxRot > rotTolerance do
            throw ("Validation failed: position=" + (maxPos as string) +
                " rotation=" + (maxRot as string) + " deg; worst " + worstPosNode +
                " / " + worstRotNode + ". The bake was rolled back.")

        theHold.Accept "Rebuild Relative Parent Animation"
        holdStarted = false
        result = #(true, #PASS, maxPos, maxRot, worstPosNode, worstPosFrame,
            worstRotNode, worstRotFrame, "Frames: " + (sourceFrames.count as string) +
            ", Children: " + (uniqueChildren.count as string))
        rrpaLog "PASS" (parentNode.name + " | " + result[9] +
            " | max position " + (maxPos as string) + " | max rotation " + (maxRot as string) + " deg")
    )
    catch
    (
        local message = getCurrentException() as string
        if holdStarted do
        (
            try (theHold.Cancel()) catch (message += " [Undo cancel failed]")
            holdStarted = false
        )
        result[9] = message
        rrpaLog "ERROR" message
    )
    sliderTime = originalTime
    result
)

if RRPA_Rollout != undefined do try (destroyDialog RRPA_Rollout) catch()

rollout RRPA_Rollout "Rebuild Relative Parent Animation"
(
    label lblParent "Parent: select Child(s), then add Parent" pos:[12,12] width:360 height:18
    label lblChildren "Children: 0 selected" pos:[12,35] width:360 height:18
    label lblRange "Range: -" pos:[12,58] width:360 height:18
    pickbutton pbParent "Pick Parent (fallback)" pos:[12,84] width:170 height:26
    checkbox cbScale "Bake Scale" pos:[204,88] checked:false
    button btnRun "Rebuild Relative Parent Animation" pos:[12,120] width:350 height:32
    label lblStatus "Status: Ready" pos:[12,162] width:350 height:18
    label lblPos "Max Pos Error: -" pos:[12,184] width:350 height:18
    label lblRot "Max Rot Error: -" pos:[12,206] width:350 height:18

    local previousSelection = #()
    local parentCandidate = undefined
    local explicitParent = undefined
    local selectionCallback = undefined
    local trackingSuspended = false

    fn refreshUI =
    (
        local nodes = rrpaSelectedNodes()
        local parentNode = if explicitParent != undefined and isValidNode explicitParent then explicitParent else parentCandidate
        if parentNode != undefined and not isValidNode parentNode do parentNode = undefined
        lblParent.text = "Parent: " + (if parentNode == undefined then "<select last or Pick Parent>" else parentNode.name)
        local countValue = nodes.count
        if parentNode != undefined and (findItem nodes parentNode) > 0 do countValue -= 1
        lblChildren.text = "Children: " + (countValue as string) + " selected"
        lblRange.text = "Range: " + (animationRange.start as string) + " - " + (animationRange.end as string) + " | Step: 1 frame"
    )

    fn onSelectionChanged eventName nodeHandles =
    (
        if not trackingSuspended do
        (
            try
            (
                local now = rrpaSelectedNodes()
                local added = #()
                for n in now where (findItem previousSelection n) == 0 do append added n
                if added.count == 1 then
                (
                    parentCandidate = added[1]
                    explicitParent = undefined
                )
                else if added.count > 1 then
                (
                    parentCandidate = undefined
                    explicitParent = undefined
                    lblStatus.text = "Status: Ambiguous batch; pick Parent explicitly."
                )
                else if parentCandidate != undefined and (findItem now parentCandidate) == 0 do
                    parentCandidate = undefined
                previousSelection = now
                refreshUI()
            )
            catch (lblStatus.text = "Status: Selection tracking failed; use Pick Parent.")
        )
    )

    on RRPA_Rollout open do
    (
        previousSelection = rrpaSelectedNodes()
        parentCandidate = undefined
        explicitParent = undefined
        try (selectionCallback = NodeEventCallback mouseUp:true selectionChanged:onSelectionChanged) catch
        (
            lblStatus.text = "Status: Selection callback unavailable; use Pick Parent."
        )
        refreshUI()
    )
    on RRPA_Rollout close do
    (
        if selectionCallback != undefined do
        (
            try (selectionCallback.enabled = false) catch()
            selectionCallback = undefined
        )
    )
    on pbParent picked pickedNode do
    (
        explicitParent = pickedNode
        refreshUI()
    )
    on btnRun pressed do
    (
        local nodes = rrpaSelectedNodes()
        local parentNode = if explicitParent != undefined and isValidNode explicitParent then explicitParent else parentCandidate
        local children = #()
        for n in nodes where n != parentNode do append children n
        trackingSuspended = true
        local report = rrpaRebuild parentNode children bakeScale:cbScale.checked
        trackingSuspended = false
        previousSelection = rrpaSelectedNodes()
        if report[1] then
        (
            lblStatus.text = "Status: PASS | " + report[9]
            lblPos.text = "Max Pos Error: " + (report[3] as string) + " | " + report[5] + " frame " + (report[6] as string)
            lblRot.text = "Max Rot Error: " + (report[4] as string) + " deg | " + report[7] + " frame " + (report[8] as string)
        )
        else
        (
            lblStatus.text = "Status: ERROR (see Listener)"
            lblPos.text = report[9]
            lblRot.text = "Max Rot Error: -"
        )
        refreshUI()
    )
)

if not maxOps.isInNonInteractiveMode() do
    createDialog RRPA_Rollout 376 235 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
