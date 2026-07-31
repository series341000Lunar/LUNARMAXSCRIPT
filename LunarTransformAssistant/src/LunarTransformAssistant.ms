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
    groupBox gbSelectionMode "SELECTION MODE" pos:[8,8] width:364 height:184
    radiobuttons rbSelectionMode labels:#(
        "Manual",
        "First Selected = Source",
        "Last Selected = Source"
    ) default:1 columns:1 pos:[18,28] width:330 height:54
    button btnResetOrdered "Start / Reset Ordered Selection" pos:[18,88] width:340 height:26
    label lblSelectionOrder "Selection Order: None" pos:[18,120] width:340 height:18
    label lblActiveSource "Active Source: Not set" pos:[18,142] width:340 height:18
    label lblActiveTargets "Active Targets: 0 Objects" pos:[18,162] width:340 height:18

    groupBox gbManual "MANUAL CAPTURE" pos:[8,198] width:364 height:102
    button btnSetSource "Set Source" pos:[18,222] width:104 height:26 tooltip:"Manual mode only."
    button btnSetTargets "Set Targets" pos:[128,222] width:104 height:26 tooltip:"Manual mode only."
    button btnClearTargets "Clear Targets" pos:[238,222] width:120 height:26 tooltip:"Manual mode only."
    label lblSource "Manual Source: Not set" pos:[18,254] width:340 height:18
    label lblTargets "Manual Targets: 0 Objects" pos:[18,276] width:340 height:18

    groupBox gbCopy "TRANSFORM CHANNELS" pos:[8,308] width:364 height:176
    label lblCopyX "X" pos:[190,330] width:22 height:16
    label lblCopyY "Y" pos:[244,330] width:22 height:16
    label lblCopyZ "Z" pos:[298,330] width:22 height:16
    label lblCopyPos "Position" pos:[22,354] width:100 height:18
    checkbox cpyPosX "" pos:[190,352] width:18 height:18
    checkbox cpyPosY "" pos:[244,352] width:18 height:18
    checkbox cpyPosZ "" pos:[298,352] width:18 height:18
    label lblCopyRot "Rotation" pos:[22,380] width:100 height:18
    checkbox cpyRotX "" pos:[190,378] width:18 height:18
    checkbox cpyRotY "" pos:[244,378] width:18 height:18
    checkbox cpyRotZ "" pos:[298,378] width:18 height:18
    label lblCopyScale "Scale" pos:[22,406] width:100 height:18
    checkbox cpyScaleX "" pos:[190,404] width:18 height:18
    checkbox cpyScaleY "" pos:[244,404] width:18 height:18
    checkbox cpyScaleZ "" pos:[298,404] width:18 height:18
    button btnCopyChannels "Copy Selected Channels" pos:[18,440] width:164 height:28
    button btnInstanceChannels "Instance Selected Channels" pos:[190,440] width:168 height:28

    groupBox gbFull "FULL TRANSFORM" pos:[8,490] width:364 height:62
    button btnCopyFull "Copy Full Transform" pos:[18,514] width:164 height:26
    button btnInstanceFull "Instance Full Transform" pos:[190,514] width:168 height:26

    groupBox gbBase "BASE OBJECT" pos:[8,558] width:364 height:62
    button btnCopyBase "Copy Base Object" pos:[18,582] width:164 height:26
    button btnInstanceBase "Instance Base Object" pos:[190,582] width:168 height:26

    groupBox gbLock "TRANSFORM LOCK" pos:[8,626] width:364 height:160
    label lblLockX "X" pos:[190,648] width:22 height:16
    label lblLockY "Y" pos:[244,648] width:22 height:16
    label lblLockZ "Z" pos:[298,648] width:22 height:16
    label lblLockPos "Position" pos:[22,672] width:100 height:18
    checkbox lockPosX "" pos:[190,670] width:18 height:18
    checkbox lockPosY "" pos:[244,670] width:18 height:18
    checkbox lockPosZ "" pos:[298,670] width:18 height:18
    label lblLockRot "Rotation" pos:[22,698] width:100 height:18
    checkbox lockRotX "" pos:[190,696] width:18 height:18
    checkbox lockRotY "" pos:[244,696] width:18 height:18
    checkbox lockRotZ "" pos:[298,696] width:18 height:18
    label lblLockScale "Scale" pos:[22,724] width:100 height:18
    checkbox lockScaleX "" pos:[190,722] width:18 height:18
    checkbox lockScaleY "" pos:[244,722] width:18 height:18
    checkbox lockScaleZ "" pos:[298,722] width:18 height:18
    button btnLockChecked "Lock Checked" pos:[18,748] width:80 height:26
    button btnUnlockChecked "Unlock Checked" pos:[102,748] width:88 height:26
    button btnLockAll "Lock All" pos:[194,748] width:76 height:26
    button btnUnlockAll "Unlock All" pos:[274,748] width:84 height:26

    groupBox gbVisibility "VISIBILITY" pos:[8,792] width:364 height:58
    button btnUnhide "Unhide Selected Nodes" pos:[18,815] width:340 height:25

    label lblStatus "Status: Ready" pos:[10,858] width:360 height:20

    local sourceNode = undefined
    local targetNodes = #()
    local resolvedSourceNode = undefined
    local resolvedTargetNodes = #()
    local selectionMode = #manual
    local orderedNodes = #()
    local selectionTrackingCallback = undefined
    local suspendSelectionTracking = false
    local orderedSelectionIsValid = true
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

    fn currentValidSelection =
    (
        local nodes = #()
        for nodeValue in selection where nodeValue != undefined and isValidNode nodeValue do
        (
            if (findItem nodes nodeValue) == 0 do append nodes nodeValue
        )
        nodes
    )

    fn cleanStoredNodes =
    (
        local cleanTargets = #()

        if sourceNode != undefined and not isValidNode sourceNode do
        (
            ltaLog "WARN" "The stored Manual Source was deleted or became invalid."
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
                ltaLog "WARN" "A deleted or invalid stored Manual Target was removed."
            )
        )

        targetNodes = cleanTargets
    )

    fn cleanOrderedNodes =
    (
        local cleanNodes = #()

        for nodeValue in orderedNodes do
        (
            if nodeValue != undefined and isValidNode nodeValue then
            (
                if (findItem cleanNodes nodeValue) == 0 do append cleanNodes nodeValue
            )
            else
            (
                ltaLog "WARN" "A deleted or invalid node was removed from ordered selection."
            )
        )

        orderedNodes = cleanNodes
    )

    fn resolveSourceAndTargets =
    (
        cleanStoredNodes()
        cleanOrderedNodes()

        case selectionMode of
        (
            #manual:
            (
                if sourceNode == undefined then
                    #(undefined, #(), false, "No valid Manual Source. Select one node and press Set Source.")
                else if targetNodes.count == 0 then
                    #(undefined, #(), false, "No valid Manual Targets. Select nodes and press Set Targets.")
                else
                    #(sourceNode, for nodeValue in targetNodes collect nodeValue, true, "")
            )
            #sourceFirst:
            (
                if not orderedSelectionIsValid then
                    #(undefined, #(), false, "Ordered selection is invalid. Use Start / Reset Ordered Selection.")
                else if orderedNodes.count < 2 then
                    #(undefined, #(), false, "Ordered selection requires at least two valid nodes.")
                else
                    #(orderedNodes[1], for indexValue = 2 to orderedNodes.count collect orderedNodes[indexValue], true, "")
            )
            #sourceLast:
            (
                if not orderedSelectionIsValid then
                    #(undefined, #(), false, "Ordered selection is invalid. Use Start / Reset Ordered Selection.")
                else if orderedNodes.count < 2 then
                    #(undefined, #(), false, "Ordered selection requires at least two valid nodes.")
                else
                    #(orderedNodes[orderedNodes.count],
                        for indexValue = 1 to (orderedNodes.count - 1) collect orderedNodes[indexValue],
                        true, "")
            )
            default:
                #(undefined, #(), false, "Unknown Selection Mode.")
        )
    )

    fn orderedSelectionText =
    (
        cleanOrderedNodes()

        if orderedNodes.count == 0 then
            "None"
        else
        (
            local textValue = ""
            local shownCount = 0
            local maxCharacters = 46

            for nodeValue in orderedNodes while textValue.count <= maxCharacters do
            (
                local candidate = if shownCount == 0 then nodeValue.name else textValue + " -> " + nodeValue.name
                if candidate.count > maxCharacters then
                    exit
                else
                (
                    textValue = candidate
                    shownCount += 1
                )
            )

            if shownCount == 0 then
                "... (+" + (orderedNodes.count as string) + ")"
            else if shownCount < orderedNodes.count then
                textValue + " -> ... (+" + ((orderedNodes.count - shownCount) as string) + ")"
            else
                textValue
        )
    )

    fn updateSelectionUI =
    (
        cleanStoredNodes()
        cleanOrderedNodes()

        local manualEnabled = selectionMode == #manual
        btnSetSource.enabled = manualEnabled
        btnSetTargets.enabled = manualEnabled
        btnClearTargets.enabled = manualEnabled
        btnResetOrdered.enabled = not manualEnabled

        if sourceNode != undefined and isValidNode sourceNode then
            lblSource.text = "Manual Source: " + sourceNode.name
        else
            lblSource.text = "Manual Source: Not set"

        if targetNodes.count == 0 then
            lblTargets.text = "Manual Targets: 0 Objects"
        else if targetNodes.count == 1 then
            lblTargets.text = "Manual Targets: 1 Object (" + targetNodes[1].name + ")"
        else
            lblTargets.text = "Manual Targets: " + (targetNodes.count as string) +
                " Objects (first: " + targetNodes[1].name + ")"

        lblSelectionOrder.text = if orderedSelectionIsValid then
            "Selection Order: " + orderedSelectionText()
        else
            "Selection Order: Invalid - reset required"

        local resolution = resolveSourceAndTargets()
        if resolution[3] then
        (
            lblActiveSource.text = "Active Source: " + resolution[1].name
            lblActiveTargets.text = "Active Targets: " + (resolution[2].count as string) + " Objects"
        )
        else
        (
            lblActiveSource.text = "Active Source: Not ready"
            lblActiveTargets.text = "Active Targets: 0 Objects"
        )
    )

    fn validateSourceAndTargets =
    (
        local resolution = resolveSourceAndTargets()
        resolvedSourceNode = resolution[1]
        resolvedTargetNodes = resolution[2]
        updateSelectionUI()

        if not resolution[3] then
        (
            setStatus resolution[4]
            ltaLog "WARN" resolution[4]
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

    fn nodesFromAnimHandles nodeHandles =
    (
        local nodes = #()

        for handleValue in nodeHandles do
        (
            local nodeValue = undefined
            try
            (
                nodeValue = getAnimByHandle handleValue
            )
            catch
            (
                nodeValue = undefined
            )

            if nodeValue != undefined and isValidNode nodeValue and
                (findItem nodes nodeValue) == 0 do
            (
                append nodes nodeValue
            )
        )

        nodes
    )

    fn handleSelectionChanged eventName nodeHandles =
    (
        if not suspendSelectionTracking do
        (
            try
            (
                local eventNodes = nodesFromAnimHandles nodeHandles

                if selectionMode != #manual then
                (
                    cleanOrderedNodes()
                    local previousOrder = for nodeValue in orderedNodes collect nodeValue
                    local currentNodes = currentValidSelection()
                    local retainedNodes = #()
                    local addedNodes = #()

                    for nodeValue in previousOrder where
                        (findItem currentNodes nodeValue) > 0 do
                    (
                        append retainedNodes nodeValue
                    )

                    for nodeValue in currentNodes where
                        (findItem previousOrder nodeValue) == 0 do
                    (
                        append addedNodes nodeValue
                    )

                    orderedNodes = retainedNodes

                    if addedNodes.count == 1 then
                    (
                        append orderedNodes addedNodes[1]
                    )
                    else if addedNodes.count > 1 then
                    (
                        orderedSelectionIsValid = false
                        ltaLog "WARN" "Multiple nodes were selected simultaneously."
                        ltaLog "WARN" "Ordered selection cannot determine click order."
                        ltaLog "WARN" "Reset ordered selection and select nodes one at a time with Ctrl+Click."
                        setStatus "Multiple nodes changed selection at once. Reset ordered selection."
                    )

                    if eventNodes.count == 0 and nodeHandles.count > 0 do
                        cleanOrderedNodes()
                )

                updateSelectionUI()
            )
            catch
            (
                ltaLog "ERROR" ("Selection tracking callback failed: " + exceptionText())
            )
        )
    )

    fn handleNodesDeleted eventName nodeHandles =
    (
        if not suspendSelectionTracking do
        (
            try
            (
                cleanStoredNodes()
                cleanOrderedNodes()
                updateSelectionUI()
            )
            catch
            (
                ltaLog "ERROR" ("Deleted-node cleanup callback failed: " + exceptionText())
            )
        )
    )

    fn releaseSelectionTracking =
    (
        if selectionTrackingCallback != undefined do
        (
            try
            (
                selectionTrackingCallback.enabled = false
            )
            catch()

            selectionTrackingCallback = undefined
            gc light:true
        )
    )

    fn registerSelectionTracking =
    (
        releaseSelectionTracking()

        try
        (
            selectionTrackingCallback = NodeEventCallback mouseUp:true \
                selectionChanged:handleSelectionChanged deleted:handleNodesDeleted
        )
        catch
        (
            selectionTrackingCallback = undefined
            ltaLog "ERROR" ("Selection tracking callback registration failed: " + exceptionText())
        )
    )

    fn setSelectionMode modeIndex =
    (
        selectionMode = case modeIndex of
        (
            1: #manual
            2: #sourceFirst
            3: #sourceLast
            default: #manual
        )

        if selectionMode != #manual and orderedNodes.count == 0 and
            (currentValidSelection()).count > 0 do
        (
            orderedSelectionIsValid = false
            setStatus "Reset ordered selection before recording click order."
            ltaLog "WARN" "Current selection has no recorded click order. Reset ordered selection."
        )

        updateSelectionUI()
    )

    fn resetOrderedSelection =
    (
        if selectionMode == #manual then
        (
            setStatus "Start / Reset Ordered Selection is available in an ordered mode."
            ltaLog "WARN" "Choose First Selected or Last Selected mode before resetting ordered selection."
        )
        else
        (
            suspendSelectionTracking = true
            try
            (
                orderedNodes = #()
                orderedSelectionIsValid = true
                clearSelection()
            )
            catch
            (
                orderedSelectionIsValid = false
                ltaLog "ERROR" ("Ordered selection reset failed: " + exceptionText())
            )
            suspendSelectionTracking = false

            updateSelectionUI()
            if orderedSelectionIsValid then
            (
                setStatus "Ordered selection reset. Select nodes one at a time."
                ltaLog "INFO" "Ordered selection reset. Select nodes one at a time with Ctrl+Click."
            )
            else
            (
                setStatus "Ordered selection reset failed. See Listener."
            )
        )
    )

    fn captureManualSource =
    (
        if selectionMode != #manual then
        (
            setStatus "Set Source is available in Manual mode only."
            ltaLog "WARN" "Set Source is a Manual mode command."
        )
        else if selection.count != 1 then
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
                updateSelectionUI()
                setStatus ("Source set: " + sourceNode.name)
                ltaLog "INFO" ("Source set explicitly: " + sourceNode.name)
            )
        )
    )

    fn captureManualTargets =
    (
        if selectionMode != #manual then
        (
            setStatus "Set Targets is available in Manual mode only."
            ltaLog "WARN" "Set Targets is a Manual mode command."
        )
        else
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
            updateSelectionUI()

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
    )

    fn clearManualTargets =
    (
        if selectionMode != #manual then
        (
            setStatus "Clear Targets is available in Manual mode only."
            ltaLog "WARN" "Clear Targets is a Manual mode command."
        )
        else
        (
            targetNodes = #()
            updateSelectionUI()
            setStatus "Targets cleared."
            ltaLog "INFO" "Stored Manual Targets cleared."
        )
    )

    on rbSelectionMode changed state do setSelectionMode state
    on btnResetOrdered pressed do resetOrderedSelection()
    on btnSetSource pressed do captureManualSource()
    on btnSetTargets pressed do captureManualTargets()
    on btnClearTargets pressed do clearManualTargets()

    fn runCopyChannels =
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
                    for targetNode in resolvedTargetNodes do
                    (
                        local result = copySelectedChannelsToTarget resolvedSourceNode targetNode flags
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
                    (resolvedTargetNodes.count as string) + " Targets. Partial/failed: " +
                    (partialTargets as string) + ".")
            else
                setStatus "No channel values were copied. See Listener."
        )
        updateSelectionUI()
    )

    fn runInstanceChannels =
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
                for targetNode in resolvedTargetNodes do
                (
                    local appliedToTarget = 0
                    local reasons = #()

                    for channelIndex = 1 to 9 where flags[channelIndex] do
                    (
                        local result = instanceXYZAxis resolvedSourceNode targetNode channelIndex
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
        updateSelectionUI()
    )

    fn runCopyFull =
    (
        if validateSourceAndTargets() then
        (
            local successCount = 0
            local skippedCount = 0
            local failedCount = 0
            local sourceTransform = resolvedSourceNode.transform

            undo "LTA Copy Full Transform" on
            (
                for targetNode in resolvedTargetNodes do
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
        updateSelectionUI()
    )

    fn runInstanceFull =
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
                sourceController = resolvedSourceNode.transform.controller
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
                    for targetNode in resolvedTargetNodes do
                    (
                        local oldController = undefined
                        local assignmentAttempted = false

                        if targetNode.parent != resolvedSourceNode.parent do
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
        updateSelectionUI()
    )

    fn runCopyBase =
    (
        if validateSourceAndTargets() then
        (
            local sourceSupport = isSupportedBaseNode resolvedSourceNode
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
                local sourceBase = resolvedSourceNode.baseObject

                undo "LTA Copy Base Object" on
                (
                    for targetNode in resolvedTargetNodes do
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
        updateSelectionUI()
    )

    fn runInstanceBase =
    (
        if validateSourceAndTargets() then
        (
            local sourceSupport = isSupportedBaseNode resolvedSourceNode
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
                local sourceBase = resolvedSourceNode.baseObject

                undo "LTA Instance Base Object" on
                (
                    for targetNode in resolvedTargetNodes do
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
        updateSelectionUI()
    )

    on btnCopyChannels pressed do runCopyChannels()
    on btnInstanceChannels pressed do runInstanceChannels()
    on btnCopyFull pressed do runCopyFull()
    on btnInstanceFull pressed do runInstanceFull()
    on btnCopyBase pressed do runCopyBase()
    on btnInstanceBase pressed do runInstanceBase()

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
        registerSelectionTracking()
        updateSelectionUI()
        setStatus "Ready"
        ltaLog "INFO" "Lunar Transform Assistant opened."
    )

    on LunarTransformAssistantRollout close do
    (
        releaseSelectionTracking()
        ltaLog "INFO" "Lunar Transform Assistant selection tracking stopped."
    )
)

createDialog LunarTransformAssistantRollout 380 886 \
    style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
