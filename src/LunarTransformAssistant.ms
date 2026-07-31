/*
    Lunar Transform Assistant
    Autodesk 3ds Max 2026 / MAXScript only

    Safety policy:
    - Source and Targets are captured explicitly.
    - Controllers are never converted to make an operation work.
    - Unsupported controller structures are skipped and reported.
    - Every scene-changing UI command owns exactly one undo block.
*/

global LunarTransformAssistantRollout

if LunarTransformAssistantRollout != undefined do
(
    try
    (
        destroyDialog LunarTransformAssistantRollout
    )
    catch
    (
        format "[LTA][WARN] Previous dialog could not be closed: %\n" (getCurrentException())
    )
)

rollout LunarTransformAssistantRollout "Lunar Transform Assistant"
(
    groupBox gbSource "SOURCE" pos:[8,8] width:364 height:64
    button btnSetSource "Set Source" pos:[18,34] width:96 height:26
    label lblSource "Source: Not set" pos:[124,39] width:236 height:18

    groupBox gbTargets "TARGETS" pos:[8,78] width:364 height:92
    button btnSetTargets "Set Targets" pos:[18,104] width:96 height:26
    label lblTargets "Targets: 0 Objects" pos:[124,109] width:236 height:18
    button btnClearTargets "Clear Targets" pos:[18,136] width:96 height:24

    groupBox gbCopy "TRANSFORM CHANNELS" pos:[8,176] width:364 height:176
    label lblCopyX "X" pos:[190,198] width:22 height:16
    label lblCopyY "Y" pos:[244,198] width:22 height:16
    label lblCopyZ "Z" pos:[298,198] width:22 height:16
    label lblCopyPos "Position" pos:[22,222] width:100 height:18
    checkbox cpyPosX "" pos:[190,220] width:18 height:18
    checkbox cpyPosY "" pos:[244,220] width:18 height:18
    checkbox cpyPosZ "" pos:[298,220] width:18 height:18
    label lblCopyRot "Rotation" pos:[22,248] width:100 height:18
    checkbox cpyRotX "" pos:[190,246] width:18 height:18
    checkbox cpyRotY "" pos:[244,246] width:18 height:18
    checkbox cpyRotZ "" pos:[298,246] width:18 height:18
    label lblCopyScale "Scale" pos:[22,274] width:100 height:18
    checkbox cpyScaleX "" pos:[190,272] width:18 height:18
    checkbox cpyScaleY "" pos:[244,272] width:18 height:18
    checkbox cpyScaleZ "" pos:[298,272] width:18 height:18
    button btnCopyChannels "Copy Selected Channels" pos:[18,308] width:164 height:28
    button btnInstanceChannels "Instance Selected Channels" pos:[190,308] width:168 height:28

    groupBox gbFull "FULL TRANSFORM" pos:[8,358] width:364 height:62
    button btnCopyFull "Copy Full Transform" pos:[18,382] width:164 height:26
    button btnInstanceFull "Instance Full Transform" pos:[190,382] width:168 height:26

    groupBox gbBase "BASE OBJECT" pos:[8,426] width:364 height:62
    button btnCopyBase "Copy Base Object" pos:[18,450] width:164 height:26
    button btnInstanceBase "Instance Base Object" pos:[190,450] width:168 height:26

    groupBox gbLock "TRANSFORM LOCK" pos:[8,494] width:364 height:160
    label lblLockX "X" pos:[190,516] width:22 height:16
    label lblLockY "Y" pos:[244,516] width:22 height:16
    label lblLockZ "Z" pos:[298,516] width:22 height:16
    label lblLockPos "Position" pos:[22,540] width:100 height:18
    checkbox lockPosX "" pos:[190,538] width:18 height:18
    checkbox lockPosY "" pos:[244,538] width:18 height:18
    checkbox lockPosZ "" pos:[298,538] width:18 height:18
    label lblLockRot "Rotation" pos:[22,566] width:100 height:18
    checkbox lockRotX "" pos:[190,564] width:18 height:18
    checkbox lockRotY "" pos:[244,564] width:18 height:18
    checkbox lockRotZ "" pos:[298,564] width:18 height:18
    label lblLockScale "Scale" pos:[22,592] width:100 height:18
    checkbox lockScaleX "" pos:[190,590] width:18 height:18
    checkbox lockScaleY "" pos:[244,590] width:18 height:18
    checkbox lockScaleZ "" pos:[298,590] width:18 height:18
    button btnLockChecked "Lock Checked" pos:[18,616] width:80 height:26
    button btnUnlockChecked "Unlock Checked" pos:[102,616] width:88 height:26
    button btnLockAll "Lock All" pos:[194,616] width:76 height:26
    button btnUnlockAll "Unlock All" pos:[274,616] width:84 height:26

    groupBox gbVisibility "VISIBILITY" pos:[8,660] width:364 height:58
    button btnUnhide "Unhide Selected Nodes" pos:[18,683] width:340 height:25

    label lblStatus "Status: Ready" pos:[10,726] width:360 height:20

    local sourceNode = undefined
    local targetNodes = #()
    local epsilon = 0.0001

    fn ltaLog level message =
    (
        format "[LTA][%] %\n" level message
    )

    fn exceptionText =
    (
        local message = getCurrentException() as string
        message = substituteString message "\r" " "
        substituteString message "\n" " "
    )

    fn setStatus message =
    (
        lblStatus.text = "Status: " + message
    )

    fn updateCaptureDisplay =
    (
        if sourceNode != undefined and isValidNode sourceNode then
            lblSource.text = "Source: " + sourceNode.name
        else
            lblSource.text = "Source: Not set"

        if targetNodes.count == 0 then
            lblTargets.text = "Targets: 0 Objects"
        else if targetNodes.count == 1 then
            lblTargets.text = "Targets: 1 Object (" + targetNodes[1].name + ")"
        else
            lblTargets.text = "Targets: " + (targetNodes.count as string) +
                " Objects (first: " + targetNodes[1].name + ")"
    )

    fn cleanStoredNodes =
    (
        local cleanTargets = #()

        if sourceNode != undefined and not isValidNode sourceNode do
        (
            ltaLog "WARN" "The stored Source was deleted or became invalid."
            sourceNode = undefined
        )

        for targetNode in targetNodes do
        (
            if targetNode != undefined and isValidNode targetNode then
            (
                if targetNode != sourceNode and (findItem cleanTargets targetNode) == 0 do
                    append cleanTargets targetNode
            )
            else
            (
                ltaLog "WARN" "A deleted or invalid stored Target was removed."
            )
        )

        targetNodes = cleanTargets
        updateCaptureDisplay()
    )

    fn validateSourceAndTargets =
    (
        cleanStoredNodes()

        if sourceNode == undefined then
        (
            setStatus "No valid Source."
            ltaLog "ERROR" "No valid Source. Select one node and press Set Source."
            false
        )
        else if targetNodes.count == 0 then
        (
            setStatus "No valid Targets."
            ltaLog "ERROR" "No valid Targets. Select nodes and press Set Targets."
            false
        )
        else
        (
            true
        )
    )

    fn copyChecks =
    (
        #(
            cpyPosX.checked, cpyPosY.checked, cpyPosZ.checked,
            cpyRotX.checked, cpyRotY.checked, cpyRotZ.checked,
            cpyScaleX.checked, cpyScaleY.checked, cpyScaleZ.checked
        )
    )

    fn lockChecks =
    (
        #(
            lockPosX.checked, lockPosY.checked, lockPosZ.checked,
            lockRotX.checked, lockRotY.checked, lockRotZ.checked,
            lockScaleX.checked, lockScaleY.checked, lockScaleZ.checked
        )
    )

    fn checkedCount flags =
    (
        local count = 0
        for flag in flags where flag do count += 1
        count
    )

    fn categoryForIndex channelIndex =
    (
        if channelIndex <= 3 then 1
        else if channelIndex <= 6 then 2
        else 3
    )

    fn axisForIndex channelIndex =
    (
        if channelIndex <= 3 then channelIndex
        else if channelIndex <= 6 then channelIndex - 3
        else channelIndex - 6
    )

    fn axisName axisIndex =
    (
        case axisIndex of
        (
            1: "X"
            2: "Y"
            3: "Z"
            default: "?"
        )
    )

    fn categoryName categoryIndex =
    (
        case categoryIndex of
        (
            1: "Position"
            2: "Rotation"
            3: "Scale"
            default: "Transform"
        )
    )

    fn getCategoryController nodeValue categoryIndex =
    (
        case categoryIndex of
        (
            1: nodeValue.position.controller
            2: nodeValue.rotation.controller
            3: nodeValue.scale.controller
            default: undefined
        )
    )

    fn isSupportedXYZController controllerValue categoryIndex =
    (
        if controllerValue == undefined then
            false
        else
        (
            case categoryIndex of
            (
                1: (classOf controllerValue == Position_XYZ)
                2: (classOf controllerValue == Euler_XYZ)
                3: (classOf controllerValue == ScaleXYZ)
                default: false
            )
        )
    )

    fn valuesNear valueA valueB =
    (
        try
        (
            (abs (valueA - valueB)) <= epsilon
        )
        catch
        (
            valueA == valueB
        )
    )

    fn pointsNear pointA pointB =
    (
        (distance pointA pointB) <= epsilon
    )

    fn matricesNear matrixA matrixB =
    (
        pointsNear matrixA.row1 matrixB.row1 and
        pointsNear matrixA.row2 matrixB.row2 and
        pointsNear matrixA.row3 matrixB.row3 and
        pointsNear matrixA.row4 matrixB.row4
    )

    fn selectedControllerCompatibility sourceController targetController categoryIndex =
    (
        if sourceController == undefined then
            #(false, "Source " + (categoryName categoryIndex) + " controller does not exist.")
        else if targetController == undefined then
            #(false, "Target " + (categoryName categoryIndex) + " controller does not exist.")
        else if not isSupportedXYZController sourceController categoryIndex then
            #(false, "Source " + (categoryName categoryIndex) + " controller " +
                ((classOf sourceController) as string) + " has no supported independent XYZ structure.")
        else if not isSupportedXYZController targetController categoryIndex then
            #(false, "Target " + (categoryName categoryIndex) + " controller " +
                ((classOf targetController) as string) + " has no supported independent XYZ structure.")
        else if categoryIndex == 2 and sourceController.axisOrder != targetController.axisOrder then
            #(false, "Euler axis orders differ (Source " + (sourceController.axisOrder as string) +
                ", Target " + (targetController.axisOrder as string) + ").")
        else
            #(true, "")
    )

    fn copyXYZAxis sourceValue targetValue channelIndex =
    (
        local categoryIndex = categoryForIndex channelIndex
        local axisIndex = axisForIndex channelIndex
        local sourceController = undefined
        local targetController = undefined
        local targetAxes = undefined
        local oldTargetValue = undefined
        local assignmentAttempted = false

        try
        (
            sourceController = getCategoryController sourceValue categoryIndex
            targetController = getCategoryController targetValue categoryIndex
        )
        catch
        (
            return #(false, "Controller access failed: " + exceptionText())
        )

        local compatibility = selectedControllerCompatibility sourceController targetController categoryIndex
        if not compatibility[1] do return compatibility

        try
        (
            local sourceAxes = getXYZControllers sourceController
            targetAxes = getXYZControllers targetController

            if sourceAxes == undefined or sourceAxes.count < axisIndex or sourceAxes[axisIndex] == undefined do
                return #(false, "Source component controller does not exist.")

            if targetAxes == undefined or targetAxes.count < axisIndex or targetAxes[axisIndex] == undefined do
                return #(false, "Target component controller does not exist.")

            local sourceAxisValue = sourceAxes[axisIndex].value
            oldTargetValue = targetAxes[axisIndex].value

            if valuesNear oldTargetValue sourceAxisValue then
                return #(false, "Target already has the Source current value.")

            assignmentAttempted = true
            targetAxes[axisIndex].value = sourceAxisValue

            if valuesNear targetAxes[axisIndex].value sourceAxisValue then
                #(true, "")
            else
            (
                local rollbackMessage = ""
                try
                (
                    targetAxes[axisIndex].value = oldTargetValue
                )
                catch
                (
                    rollbackMessage = " Rollback also failed: " + exceptionText()
                )
                #(false, "The controller rejected the current value assignment." + rollbackMessage)
            )
        )
        catch
        (
            local failureMessage = "Current value assignment failed: " + exceptionText()
            if assignmentAttempted and targetAxes != undefined and oldTargetValue != undefined do
            (
                try
                (
                    targetAxes[axisIndex].value = oldTargetValue
                )
                catch
                (
                    failureMessage += " Rollback also failed: " + exceptionText()
                )
            )
            #(false, failureMessage)
        )
    )

    fn copyBezierScaleAxes sourceValue targetValue flags =
    (
        local selectedAxes = #()
        for axisIndex = 1 to 3 where flags[axisIndex + 6] do append selectedAxes axisIndex

        if selectedAxes.count == 0 do return #(0, #())

        local reasons = #()
        local sourceController = undefined
        local targetController = undefined
        local oldScale = undefined
        local assignmentAttempted = false

        try
        (
            sourceController = sourceValue.scale.controller
            targetController = targetValue.scale.controller
        )
        catch
        (
            append reasons ("Scale controller access failed: " + exceptionText())
            return #(0, reasons)
        )

        if sourceController == undefined or targetController == undefined then
        (
            append reasons "Source or Target Scale controller does not exist."
            return #(0, reasons)
        )

        if classOf sourceController != Bezier_Scale or classOf targetController != Bezier_Scale then
        (
            append reasons ("Scale controller pair is not a supported Bezier_Scale pair (Source " +
                ((classOf sourceController) as string) + ", Target " +
                ((classOf targetController) as string) + ").")
            return #(0, reasons)
        )

        try
        (
            local sourceScale = sourceValue.scale
            oldScale = targetValue.scale
            local desiredScale = [oldScale.x, oldScale.y, oldScale.z]
            local needsChange = false

            for axisIndex in selectedAxes do
            (
                desiredScale[axisIndex] = sourceScale[axisIndex]
                if not valuesNear oldScale[axisIndex] sourceScale[axisIndex] do needsChange = true
            )

            if not needsChange then
            (
                append reasons "Selected Scale axes already have the Source current values."
                return #(0, reasons)
            )

            assignmentAttempted = true
            targetValue.scale = desiredScale
            local actualScale = targetValue.scale
            local allMatched = true

            for axisIndex in selectedAxes where not valuesNear actualScale[axisIndex] desiredScale[axisIndex] do
                allMatched = false

            for axisIndex = 1 to 3 where (findItem selectedAxes axisIndex) == 0 do
            (
                if not valuesNear actualScale[axisIndex] oldScale[axisIndex] do allMatched = false
            )

            if allMatched then
                #(selectedAxes.count, reasons)
            else
            (
                try
                (
                    targetValue.scale = oldScale
                )
                catch
                (
                    append reasons ("Bezier_Scale rollback also failed: " + exceptionText())
                )
                append reasons "Bezier_Scale assignment did not preserve or match all requested current values."
                #(0, reasons)
            )
        )
        catch
        (
            local failureMessage = "Bezier_Scale current value assignment failed: " + exceptionText()
            if assignmentAttempted and oldScale != undefined do
            (
                try
                (
                    targetValue.scale = oldScale
                )
                catch
                (
                    failureMessage += " Rollback also failed: " + exceptionText()
                )
            )
            append reasons failureMessage
            #(0, reasons)
        )
    )

    fn copySelectedChannelsToTarget sourceValue targetValue flags =
    (
        local applied = 0
        local reasons = #()

        for channelIndex = 1 to 6 where flags[channelIndex] do
        (
            local result = copyXYZAxis sourceValue targetValue channelIndex
            if result[1] then
                applied += 1
            else
                append reasons ((categoryName (categoryForIndex channelIndex)) + " " +
                    (axisName (axisForIndex channelIndex)) + ": " + result[2])
        )

        local sourceScaleController = undefined
        local targetScaleController = undefined
        try
        (
            sourceScaleController = sourceValue.scale.controller
            targetScaleController = targetValue.scale.controller
        )
        catch
        (
            append reasons ("Scale controller access failed: " + exceptionText())
        )

        if sourceScaleController != undefined and targetScaleController != undefined and
            classOf sourceScaleController == Bezier_Scale and classOf targetScaleController == Bezier_Scale then
        (
            local scaleResult = copyBezierScaleAxes sourceValue targetValue flags
            applied += scaleResult[1]
            join reasons scaleResult[2]
        )
        else
        (
            for channelIndex = 7 to 9 where flags[channelIndex] do
            (
                local result = copyXYZAxis sourceValue targetValue channelIndex
                if result[1] then
                    applied += 1
                else
                    append reasons ("Scale " + (axisName (axisForIndex channelIndex)) + ": " + result[2])
            )
        )

        #(applied, reasons)
    )

    fn instanceXYZAxis sourceValue targetValue channelIndex =
    (
        local categoryIndex = categoryForIndex channelIndex
        local axisIndex = axisForIndex channelIndex
        local sourceController = undefined
        local targetController = undefined
        local targetSubAnim = undefined
        local oldTargetController = undefined
        local assignmentAttempted = false

        try
        (
            sourceController = getCategoryController sourceValue categoryIndex
            targetController = getCategoryController targetValue categoryIndex
        )
        catch
        (
            return #(false, "Controller access failed: " + exceptionText())
        )

        local compatibility = selectedControllerCompatibility sourceController targetController categoryIndex
        if not compatibility[1] do return compatibility

        try
        (
            local sourceSubAnim = sourceController[axisIndex]
            targetSubAnim = targetController[axisIndex]

            if sourceSubAnim == undefined or sourceSubAnim.controller == undefined do
                return #(false, "Source component controller does not exist.")

            if targetSubAnim == undefined or targetSubAnim.controller == undefined do
                return #(false, "Target component controller does not exist or is not writable.")

            local sourceAxisController = sourceSubAnim.controller
            if targetSubAnim.controller == sourceAxisController then
                return #(false, "Target already shares the Source component controller.")

            oldTargetController = targetSubAnim.controller
            assignmentAttempted = true
            targetSubAnim.controller = sourceAxisController

            if targetController[axisIndex].controller == sourceAxisController then
                #(true, "")
            else
            (
                local rollbackMessage = ""
                try
                (
                    targetSubAnim.controller = oldTargetController
                )
                catch
                (
                    rollbackMessage = " Rollback also failed: " + exceptionText()
                )
                #(false, "The Target component rejected controller assignment." + rollbackMessage)
            )
        )
        catch
        (
            local failureMessage = "Controller instance assignment failed: " + exceptionText()
            if assignmentAttempted and targetSubAnim != undefined and oldTargetController != undefined do
            (
                try
                (
                    targetSubAnim.controller = oldTargetController
                )
                catch
                (
                    failureMessage += " Rollback also failed: " + exceptionText()
                )
            )
            #(false, failureMessage)
        )
    )

    fn reportTargetReasons targetValue operationName reasons =
    (
        for reason in reasons do
            ltaLog "WARN" (targetValue.name + ": " + operationName + " - " + reason)
    )

    fn printBatchSummary operationName successCount skippedCount failedCount =
    (
        ltaLog "INFO" ("Operation: " + operationName)
        ltaLog "INFO" ("Success: " + (successCount as string))
        if skippedCount > 0 then
            ltaLog "WARN" ("Skipped: " + (skippedCount as string))
        else
            ltaLog "INFO" "Skipped: 0"
        if failedCount > 0 then
            ltaLog "ERROR" ("Failed: " + (failedCount as string))
        else
            ltaLog "INFO" "Failed: 0"
    )

    fn isSupportedBaseNode nodeValue =
    (
        if nodeValue == undefined or not isValidNode nodeValue then
            #(false, "Node is invalid.")
        else if isGroupHead nodeValue then
            #(false, "Group heads are not supported.")
        else
        (
            local objectValue = undefined
            try
            (
                objectValue = nodeValue.baseObject
            )
            catch
            (
                return #(false, "Base Object access failed: " + exceptionText())
            )

            if objectValue == undefined then
                #(false, "Base Object does not exist.")
            else if superClassOf objectValue != GeometryClass then
                #(false, "Only ordinary Geometry Base Objects are supported.")
            else if matchPattern ((classOf objectValue) as string) pattern:"*XRef*" ignoreCase:true then
                #(false, "XRef Base Objects are not supported.")
            else
                #(true, "")
        )
    )

    fn selectedNodesArray =
    (
        local nodes = #()
        for selectedNode in selection where selectedNode != undefined and isValidNode selectedNode do
            append nodes selectedNode
        nodes
    )

    on btnSetSource pressed do
    (
        if selection.count != 1 then
        (
            setStatus "Select exactly one Source node."
            ltaLog "WARN" "Set Source requires exactly one selected node."
        )
        else
        (
            local capturedSource = undefined
            for selectedNode in selection do capturedSource = selectedNode

            if capturedSource == undefined or not isValidNode capturedSource then
            (
                setStatus "The selected Source is invalid."
                ltaLog "ERROR" "The selected Source is invalid."
            )
            else
            (
                sourceNode = capturedSource
                local filteredTargets = #()
                for targetNode in targetNodes where targetNode != sourceNode and
                    targetNode != undefined and isValidNode targetNode do
                (
                    if (findItem filteredTargets targetNode) == 0 do append filteredTargets targetNode
                )
                targetNodes = filteredTargets
                updateCaptureDisplay()
                setStatus ("Source set: " + sourceNode.name)
                ltaLog "INFO" ("Source set explicitly: " + sourceNode.name)
            )
        )
    )

    on btnSetTargets pressed do
    (
        local capturedTargets = #()
        local sourceWasExcluded = false

        for selectedNode in selection do
        (
            if selectedNode != undefined and isValidNode selectedNode then
            (
                if sourceNode != undefined and isValidNode sourceNode and selectedNode == sourceNode then
                    sourceWasExcluded = true
                else if (findItem capturedTargets selectedNode) == 0 do
                    append capturedTargets selectedNode
            )
        )

        targetNodes = capturedTargets
        updateCaptureDisplay()

        if targetNodes.count == 0 then
        (
            setStatus "No valid Targets captured."
            ltaLog "WARN" "Set Targets captured no valid nodes."
        )
        else
        (
            setStatus ("Targets set: " + (targetNodes.count as string))
            ltaLog "INFO" ("Targets set explicitly: " + (targetNodes.count as string))
            if sourceWasExcluded do
                ltaLog "WARN" "The Source was present in the Target selection and was excluded."
        )
    )

    on btnClearTargets pressed do
    (
        targetNodes = #()
        updateCaptureDisplay()
        setStatus "Targets cleared."
        ltaLog "INFO" "Stored Targets cleared."
    )

    on btnCopyChannels pressed do
    (
        local flags = copyChecks()
        local requestedCount = checkedCount flags

        if requestedCount == 0 then
        (
            setStatus "Select at least one Transform channel."
            ltaLog "WARN" "Copy Selected Channels requires at least one checked channel."
        )
        else if validateSourceAndTargets() then
        (
            local completeTargets = 0
            local skippedTargets = 0
            local partialTargets = 0
            local appliedChannels = 0

            undo "LTA Copy Selected Channels" on
            (
                at time currentTime
                (
                    for targetNode in targetNodes do
                    (
                        local result = copySelectedChannelsToTarget sourceNode targetNode flags
                        appliedChannels += result[1]

                        if result[1] == requestedCount then
                            completeTargets += 1
                        else if result[1] == 0 then
                            skippedTargets += 1
                        else
                            partialTargets += 1

                        reportTargetReasons targetNode "Copy Selected Channels" result[2]
                    )
                )
            )

            if appliedChannels > 0 do redrawViews()
            printBatchSummary "Copy Selected Channels" completeTargets skippedTargets partialTargets

            if appliedChannels > 0 then
                setStatus ("Copied " + (appliedChannels as string) + " channel values across " +
                    (targetNodes.count as string) + " Targets. Partial/failed: " +
                    (partialTargets as string) + ".")
            else
                setStatus "No channel values were copied. See Listener."
        )
    )

    on btnInstanceChannels pressed do
    (
        local flags = copyChecks()
        local requestedCount = checkedCount flags

        if requestedCount == 0 then
        (
            setStatus "Select at least one Transform channel."
            ltaLog "WARN" "Instance Selected Channels requires at least one checked channel."
        )
        else if validateSourceAndTargets() then
        (
            local completeTargets = 0
            local skippedTargets = 0
            local partialTargets = 0
            local appliedChannels = 0

            undo "LTA Instance Selected Channels" on
            (
                for targetNode in targetNodes do
                (
                    local appliedToTarget = 0
                    local reasons = #()

                    for channelIndex = 1 to 9 where flags[channelIndex] do
                    (
                        local result = instanceXYZAxis sourceNode targetNode channelIndex
                        if result[1] then
                        (
                            appliedToTarget += 1
                            appliedChannels += 1
                        )
                        else
                        (
                            append reasons ((categoryName (categoryForIndex channelIndex)) + " " +
                                (axisName (axisForIndex channelIndex)) + ": " + result[2])
                        )
                    )

                    if appliedToTarget == requestedCount then
                        completeTargets += 1
                    else if appliedToTarget == 0 then
                        skippedTargets += 1
                    else
                        partialTargets += 1

                    reportTargetReasons targetNode "Instance Selected Channels" reasons
                )
            )

            if appliedChannels > 0 do redrawViews()
            printBatchSummary "Instance Selected Channels" completeTargets skippedTargets partialTargets

            if appliedChannels > 0 then
                setStatus ("Instanced " + (appliedChannels as string) + " component controllers. Partial/failed Targets: " +
                    (partialTargets as string) + ".")
            else
                setStatus "No component controllers were instanced. See Listener."
        )
    )

    on btnCopyFull pressed do
    (
        if validateSourceAndTargets() then
        (
            local successCount = 0
            local skippedCount = 0
            local failedCount = 0
            local sourceTransform = sourceNode.transform

            undo "LTA Copy Full Transform" on
            (
                for targetNode in targetNodes do
                (
                    if matricesNear targetNode.transform sourceTransform then
                    (
                        skippedCount += 1
                        ltaLog "WARN" (targetNode.name + ": already has the Source world transform.")
                    )
                    else
                    (
                        local oldTransform = targetNode.transform
                        local assignmentAttempted = false
                        try
                        (
                            assignmentAttempted = true
                            targetNode.transform = sourceTransform
                            if matricesNear targetNode.transform sourceTransform then
                                successCount += 1
                            else
                            (
                                failedCount += 1
                                local rollbackText = ""
                                try
                                (
                                    targetNode.transform = oldTransform
                                )
                                catch
                                (
                                    rollbackText = " Rollback also failed: " + exceptionText()
                                )
                                ltaLog "ERROR" (targetNode.name +
                                    ": full world transform was not fully applied; check locks or controller support." +
                                    rollbackText)
                            )
                        )
                        catch
                        (
                            local failureText = exceptionText()
                            if assignmentAttempted do
                            (
                                try
                                (
                                    targetNode.transform = oldTransform
                                )
                                catch
                                (
                                    failureText += " Rollback also failed: " + exceptionText()
                                )
                            )
                            failedCount += 1
                            ltaLog "ERROR" (targetNode.name + ": Copy Full Transform failed: " + failureText)
                        )
                    )
                )
            )

            if successCount > 0 do redrawViews()
            printBatchSummary "Copy Full Transform" successCount skippedCount failedCount
            setStatus ("Copied full transform to " + (successCount as string) + " Targets. Failed: " +
                (failedCount as string) + ".")
        )
    )

    on btnInstanceFull pressed do
    (
        if validateSourceAndTargets() then
        (
            local successCount = 0
            local skippedCount = 0
            local failedCount = 0
            local parentWarnings = 0
            local sourceController = undefined

            try
            (
                sourceController = sourceNode.transform.controller
            )
            catch
            (
                ltaLog "ERROR" ("Source transform controller access failed: " + exceptionText())
            )

            if sourceController == undefined then
            (
                setStatus "Source transform controller is unavailable."
            )
            else
            (
                undo "LTA Instance Full Transform" on
                (
                    for targetNode in targetNodes do
                    (
                        local oldController = undefined
                        local assignmentAttempted = false

                        if targetNode.parent != sourceNode.parent do
                        (
                            parentWarnings += 1
                            ltaLog "WARN" (targetNode.name +
                                " has a different parent. The shared transform controller may produce a different world-space result.")
                        )

                        try
                        (
                            oldController = targetNode.transform.controller
                            if oldController == sourceController then
                            (
                                skippedCount += 1
                                ltaLog "WARN" (targetNode.name + ": already shares the Source transform controller.")
                            )
                            else
                            (
                                ltaLog "INFO" (targetNode.name + ": replacing " +
                                    ((classOf oldController) as string) + " with an explicit instance of " +
                                    ((classOf sourceController) as string) + ".")
                                assignmentAttempted = true
                                targetNode.transform.controller = sourceController

                                if targetNode.transform.controller == sourceController then
                                    successCount += 1
                                else
                                (
                                    failedCount += 1
                                    local rollbackText = ""
                                    try
                                    (
                                        targetNode.transform.controller = oldController
                                    )
                                    catch
                                    (
                                        rollbackText = " Rollback also failed: " + exceptionText()
                                    )
                                    ltaLog "ERROR" (targetNode.name +
                                        ": Target rejected full transform controller assignment." + rollbackText)
                                )
                            )
                        )
                        catch
                        (
                            local failureText = exceptionText()
                            if assignmentAttempted and oldController != undefined do
                            (
                                try
                                (
                                    targetNode.transform.controller = oldController
                                )
                                catch
                                (
                                    failureText += " Rollback also failed: " + exceptionText()
                                )
                            )
                            failedCount += 1
                            ltaLog "ERROR" (targetNode.name + ": Instance Full Transform failed: " + failureText)
                        )
                    )
                )

                if successCount > 0 do redrawViews()
                printBatchSummary "Instance Full Transform" successCount skippedCount failedCount
                setStatus ("Instanced full transform to " + (successCount as string) + " Targets. Parent warnings: " +
                    (parentWarnings as string) + ".")
            )
        )
    )

    on btnCopyBase pressed do
    (
        if validateSourceAndTargets() then
        (
            local sourceSupport = isSupportedBaseNode sourceNode
            if not sourceSupport[1] then
            (
                setStatus "Source Base Object is unsupported."
                ltaLog "ERROR" ("Source: " + sourceSupport[2])
            )
            else
            (
                local successCount = 0
                local skippedCount = 0
                local failedCount = 0
                local sourceBase = sourceNode.baseObject

                undo "LTA Copy Base Object" on
                (
                    for targetNode in targetNodes do
                    (
                        local targetSupport = isSupportedBaseNode targetNode
                        if not targetSupport[1] then
                        (
                            skippedCount += 1
                            ltaLog "WARN" (targetNode.name + ": " + targetSupport[2])
                        )
                        else
                        (
                            local oldBase = targetNode.baseObject
                            local assignmentAttempted = false
                            try
                            (
                                local independentBase = copy sourceBase
                                if independentBase == undefined then
                                (
                                    failedCount += 1
                                    ltaLog "ERROR" (targetNode.name + ": Source Base Object copy returned undefined.")
                                )
                                else
                                (
                                    assignmentAttempted = true
                                    targetNode.baseObject = independentBase
                                    if targetNode.baseObject == independentBase and targetNode.baseObject != sourceBase then
                                        successCount += 1
                                    else
                                    (
                                        failedCount += 1
                                        local rollbackText = ""
                                        try
                                        (
                                            targetNode.baseObject = oldBase
                                        )
                                        catch
                                        (
                                            rollbackText = " Rollback also failed: " + exceptionText()
                                        )
                                        ltaLog "ERROR" (targetNode.name +
                                            ": independent Base Object assignment could not be verified." + rollbackText)
                                    )
                                )
                            )
                            catch
                            (
                                local failureText = exceptionText()
                                if assignmentAttempted and oldBase != undefined do
                                (
                                    try
                                    (
                                        targetNode.baseObject = oldBase
                                    )
                                    catch
                                    (
                                        failureText += " Rollback also failed: " + exceptionText()
                                    )
                                )
                                failedCount += 1
                                ltaLog "ERROR" (targetNode.name + ": Copy Base Object failed: " + failureText)
                            )
                        )
                    )
                )

                if successCount > 0 do redrawViews()
                printBatchSummary "Copy Base Object" successCount skippedCount failedCount
                setStatus ("Copied Base Object to " + (successCount as string) + " Targets. Failed: " +
                    (failedCount as string) + ".")
            )
        )
    )

    on btnInstanceBase pressed do
    (
        if validateSourceAndTargets() then
        (
            local sourceSupport = isSupportedBaseNode sourceNode
            if not sourceSupport[1] then
            (
                setStatus "Source Base Object is unsupported."
                ltaLog "ERROR" ("Source: " + sourceSupport[2])
            )
            else
            (
                local successCount = 0
                local skippedCount = 0
                local failedCount = 0
                local sourceBase = sourceNode.baseObject

                undo "LTA Instance Base Object" on
                (
                    for targetNode in targetNodes do
                    (
                        local targetSupport = isSupportedBaseNode targetNode
                        if not targetSupport[1] then
                        (
                            skippedCount += 1
                            ltaLog "WARN" (targetNode.name + ": " + targetSupport[2])
                        )
                        else if targetNode.baseObject == sourceBase then
                        (
                            skippedCount += 1
                            ltaLog "WARN" (targetNode.name + ": already shares the Source Base Object.")
                        )
                        else
                        (
                            local oldBase = targetNode.baseObject
                            local assignmentAttempted = false
                            try
                            (
                                assignmentAttempted = true
                                targetNode.baseObject = sourceBase
                                if targetNode.baseObject == sourceBase then
                                    successCount += 1
                                else
                                (
                                    failedCount += 1
                                    local rollbackText = ""
                                    try
                                    (
                                        targetNode.baseObject = oldBase
                                    )
                                    catch
                                    (
                                        rollbackText = " Rollback also failed: " + exceptionText()
                                    )
                                    ltaLog "ERROR" (targetNode.name +
                                        ": shared Base Object assignment could not be verified." + rollbackText)
                                )
                            )
                            catch
                            (
                                local failureText = exceptionText()
                                if assignmentAttempted and oldBase != undefined do
                                (
                                    try
                                    (
                                        targetNode.baseObject = oldBase
                                    )
                                    catch
                                    (
                                        failureText += " Rollback also failed: " + exceptionText()
                                    )
                                )
                                failedCount += 1
                                ltaLog "ERROR" (targetNode.name + ": Instance Base Object failed: " + failureText)
                            )
                        )
                    )
                )

                if successCount > 0 do redrawViews()
                printBatchSummary "Instance Base Object" successCount skippedCount failedCount
                setStatus ("Instanced Base Object to " + (successCount as string) + " Targets. Failed: " +
                    (failedCount as string) + ".")
            )
        )
    )

    on btnUnhide pressed do
    (
        local nodes = selectedNodesArray()
        if nodes.count == 0 then
        (
            setStatus "Current selection is empty."
            ltaLog "WARN" "Unhide Selected Nodes requires a current selection."
        )
        else
        (
            local successCount = 0
            local skippedCount = 0
            local failedCount = 0
            local layerWarnings = 0

            undo "LTA Unhide Selected Nodes" on
            (
                for nodeValue in nodes do
                (
                    try
                    (
                        if nodeValue.isNodeHidden then
                        (
                            nodeValue.isNodeHidden = false
                            if not nodeValue.isNodeHidden then
                                successCount += 1
                            else
                            (
                                failedCount += 1
                                ltaLog "ERROR" (nodeValue.name + ": node hidden state could not be cleared.")
                            )
                        )
                        else
                        (
                            skippedCount += 1
                            ltaLog "INFO" (nodeValue.name + ": node was already unhidden.")
                        )

                        local nodeLayer = nodeValue.INodeLayerProperties.layer
                        if nodeLayer != undefined and nodeLayer.isHidden do
                        (
                            layerWarnings += 1
                            ltaLog "WARN" (nodeValue.name +
                                " node hide was cleared, but its Layer remains hidden.")
                        )
                    )
                    catch
                    (
                        failedCount += 1
                        ltaLog "ERROR" (nodeValue.name + ": Unhide failed: " + exceptionText())
                    )
                )
            )

            if successCount > 0 do redrawViews()
            printBatchSummary "Unhide Selected Nodes" successCount skippedCount failedCount
            setStatus ("Unhid " + (successCount as string) + " nodes. Layer warnings: " +
                (layerWarnings as string) + ".")
        )
    )

    fn applyCheckedLocks lockState =
    (
        local flagsToChange = lockChecks()
        local requestedCount = checkedCount flagsToChange
        local nodes = selectedNodesArray()

        if requestedCount == 0 then
        (
            setStatus "Select at least one Transform Lock flag."
            ltaLog "WARN" "Lock Checked/Unlock Checked requires at least one checked lock flag."
        )
        else if nodes.count == 0 then
        (
            setStatus "Current selection is empty."
            ltaLog "WARN" "Transform Lock operation requires a current selection."
        )
        else
        (
            local successCount = 0
            local skippedCount = 0
            local failedCount = 0
            local operationName = if lockState then "Lock Checked" else "Unlock Checked"

            undo label:("LTA " + operationName) on
            (
                for nodeValue in nodes do
                (
                    try
                    (
                        local oldFlags = getTransformLockFlags nodeValue
                        local newFlags = copy oldFlags
                        local needsChange = false

                        for bitIndex = 1 to 9 where flagsToChange[bitIndex] do
                        (
                            if newFlags[bitIndex] != lockState do needsChange = true
                            newFlags[bitIndex] = lockState
                        )

                        if not needsChange then
                        (
                            skippedCount += 1
                            ltaLog "INFO" (nodeValue.name + ": requested lock flags already match.")
                        )
                        else
                        (
                            setTransformLockFlags nodeValue newFlags
                            local actualFlags = getTransformLockFlags nodeValue
                            local verified = true

                            for bitIndex = 1 to 9 where flagsToChange[bitIndex] do
                            (
                                if actualFlags[bitIndex] != lockState do verified = false
                            )

                            for bitIndex = 1 to 9 where not flagsToChange[bitIndex] do
                            (
                                if actualFlags[bitIndex] != oldFlags[bitIndex] do verified = false
                            )

                            if verified then
                                successCount += 1
                            else
                            (
                                failedCount += 1
                                ltaLog "ERROR" (nodeValue.name +
                                    ": lock flags could not be verified or unchecked flags changed.")
                            )
                        )
                    )
                    catch
                    (
                        failedCount += 1
                        ltaLog "ERROR" (nodeValue.name + ": " + operationName + " failed: " + exceptionText())
                    )
                )
            )

            if successCount > 0 do redrawViews()
            printBatchSummary operationName successCount skippedCount failedCount
            setStatus (operationName + " on " + (successCount as string) + " nodes. Failed: " +
                (failedCount as string) + ".")
        )
    )

    fn applyAllLocks lockState =
    (
        local nodes = selectedNodesArray()
        if nodes.count == 0 then
        (
            setStatus "Current selection is empty."
            ltaLog "WARN" "Lock All/Unlock All requires a current selection."
        )
        else
        (
            local successCount = 0
            local skippedCount = 0
            local failedCount = 0
            local operationName = if lockState then "Lock All" else "Unlock All"
            local desiredFlags = if lockState then #{1..9} else #{}

            undo label:("LTA " + operationName) on
            (
                for nodeValue in nodes do
                (
                    try
                    (
                        local oldFlags = getTransformLockFlags nodeValue
                        local alreadyMatched = true
                        for bitIndex = 1 to 9 do
                        (
                            if oldFlags[bitIndex] != lockState do alreadyMatched = false
                        )

                        if alreadyMatched then
                        (
                            skippedCount += 1
                            ltaLog "INFO" (nodeValue.name + ": all lock flags already match.")
                        )
                        else
                        (
                            setTransformLockFlags nodeValue desiredFlags
                            local actualFlags = getTransformLockFlags nodeValue
                            local verified = true
                            for bitIndex = 1 to 9 do
                            (
                                if actualFlags[bitIndex] != lockState do verified = false
                            )

                            if verified then
                                successCount += 1
                            else
                            (
                                failedCount += 1
                                ltaLog "ERROR" (nodeValue.name + ": all lock flags could not be verified.")
                            )
                        )
                    )
                    catch
                    (
                        failedCount += 1
                        ltaLog "ERROR" (nodeValue.name + ": " + operationName + " failed: " + exceptionText())
                    )
                )
            )

            if successCount > 0 do redrawViews()
            printBatchSummary operationName successCount skippedCount failedCount
            setStatus (operationName + " on " + (successCount as string) + " nodes. Failed: " +
                (failedCount as string) + ".")
        )
    )

    on btnLockChecked pressed do applyCheckedLocks true
    on btnUnlockChecked pressed do applyCheckedLocks false
    on btnLockAll pressed do applyAllLocks true
    on btnUnlockAll pressed do applyAllLocks false

    on LunarTransformAssistantRollout open do
    (
        updateCaptureDisplay()
        setStatus "Ready"
        ltaLog "INFO" "Lunar Transform Assistant opened."
    )
)

createDialog LunarTransformAssistantRollout 380 754 \
    style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
