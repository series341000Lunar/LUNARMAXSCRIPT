/*
    Lunar -> tyFlow Placement MK1
    Autodesk 3ds Max 2026 / tyFlow 2.0100

    Source scene is authoritative:
    - Analyze reads selected node names and stores node handles only.
    - Build creates or updates only LUNAR_ events in the registered tyFlow.
    - Every managed Event contains Birth Objects, Shape, Mesh, and Display.
    - Source nodes are never transformed, hidden, frozen, attached, collapsed,
      converted, deleted, relayered, or pivot-adjusted.

    The tyFlow API names used below were verified against the installed
    tyFlow_2026.dlo file version 2.0100.0.0.
*/

global LunarTyFlowPlacementRollout

struct LunarTyFlowPlacementFamilyRow
(
    groupKey = "",
    familyName = "",
    handles = #(),
    shapeHandle = 0,
    standardName = true,
    nonstandardCount = 0,
    eventName = "",
    status = "",
    detail = "",
    buildable = true
)

if LunarTyFlowPlacementRollout != undefined do
(
    try (destroyDialog LunarTyFlowPlacementRollout) catch()
)

rollout LunarTyFlowPlacementRollout "LUNAR -> TYFLOW PLACEMENT MK1" width:790 height:700
(
    groupBox gbTarget "TARGET TYFLOW" pos:[8,8] width:774 height:88
    button btnUseSelectedTyFlow "Use Selected tyFlow" pos:[20,32] width:180 height:30
    button btnClearTarget "Clear" pos:[210,32] width:80 height:30
    label lblTarget "Target: Not set" pos:[306,38] width:460 height:20
    label lblTargetHint "One selected tyFlow is required. The target is excluded from Source analysis." pos:[20,70] width:742 height:18

    groupBox gbSource "SOURCE" pos:[8,104] width:774 height:56
    label lblSelected "Selected Source Nodes: 0" pos:[20,128] width:350 height:20
    label lblAnalyzeSnapshot "Analyze Snapshot: Not ready" pos:[390,128] width:370 height:20

    groupBox gbOptions "OPTIONS" pos:[8,168] width:774 height:76
    checkbox chkIgnoreInstances "Ignore Instance Relationship" pos:[20,192] width:270 height:20 checked:true
    checkbox chkUpdateExisting "Update Existing LUNAR Events" pos:[310,192] width:270 height:20 checked:true
    label lblOptionsHint "OFF validates shared Base Object identity; mismatched or uncheckable Families are skipped." pos:[20,218] width:742 height:18

    button btnAnalyze "ANALYZE" pos:[8,254] width:774 height:36

    dotNetControl lvFamilies "System.Windows.Forms.ListView" pos:[8,300] width:774 height:260

    button btnBuild "BUILD / UPDATE" pos:[8,570] width:774 height:42 enabled:false

    label lblSummary "Selected: 0 | Families: 0 | Nonstandard: 0" pos:[10,622] width:770 height:18
    editText txtStatus "" pos:[8,644] width:774 height:48 readOnly:true style:#multiLine

    local targetFlow = undefined
    local familyRows = #()
    local analysisReady = false
    local analyzedSourceCount = 0
    local analyzedNonstandardCount = 0
    local lastBuildSummary = #(0, 0, 0, 0, 0)
    local regexClass = dotNetClass "System.Text.RegularExpressions.Regex"

    fn ltpLog levelValue messageValue =
    (
        format "[LTP][%] %\n" levelValue messageValue
    )

    fn exceptionText =
    (
        local messageValue = getCurrentException() as string
        messageValue = substituteString messageValue "\r" " "
        substituteString messageValue "\n" " "
    )

    fn setStatus messageValue =
    (
        txtStatus.text = messageValue
    )

    fn isValidStoredNode nodeValue =
    (
        nodeValue != undefined and isValidNode nodeValue
    )

    fn isTyFlowNode nodeValue =
    (
        isValidStoredNode nodeValue and (classOf nodeValue as string) == "tyFlow"
    )

    fn safeNodeHandle nodeValue =
    (
        local resultValue = 0
        if isValidStoredNode nodeValue do
            try (resultValue = getHandleByAnim nodeValue) catch (resultValue = 0)
        resultValue
    )

    fn nodeFromHandle handleValue =
    (
        local resultValue = undefined
        if handleValue != undefined and handleValue != 0 do
            try (resultValue = getAnimByHandle handleValue) catch (resultValue = undefined)
        if not isValidStoredNode resultValue do resultValue = undefined
        resultValue
    )

    fn nodeNameFromHandle handleValue =
    (
        local nodeValue = nodeFromHandle handleValue
        if nodeValue == undefined then "<deleted>" else nodeValue.name as string
    )

    fn parseFamilyName nodeName =
    (
        local textValue = nodeName as string
        local matchValue = regexClass.Match textValue "^(.*)_([0-9]+)$"
        if matchValue.Success then
            #(matchValue.Groups.Item[1].Value as string, true)
        else
            #(textValue, false)
    )

    fn findFamilyRowIndex keyValue =
    (
        local foundIndex = 0
        for rowIndex = 1 to familyRows.count while foundIndex == 0 do
            if familyRows[rowIndex].groupKey == keyValue do foundIndex = rowIndex
        foundIndex
    )

    fn resolveFamilyNodes rowValue =
    (
        local resultValue = #()
        for handleValue in rowValue.handles do
        (
            local nodeValue = nodeFromHandle handleValue
            if nodeValue != undefined and nodeValue != targetFlow do append resultValue nodeValue
        )
        resultValue
    )

    fn eventNameCollision rowIndex =
    (
        local collisionValue = false
        if rowIndex >= 1 and rowIndex <= familyRows.count do
        (
            local eventNameValue = familyRows[rowIndex].eventName
            for otherIndex = 1 to familyRows.count while not collisionValue do
                if otherIndex != rowIndex and familyRows[otherIndex].eventName == eventNameValue do collisionValue = true
        )
        collisionValue
    )

    fn findExistingLunarEvent eventNameValue =
    (
        local eventValue = undefined
        if isTyFlowNode targetFlow do
        (
            try (eventValue = getProperty targetFlow (eventNameValue as name)) catch (eventValue = undefined)
            if eventValue != undefined and (classOf eventValue as string) != "tyEvent" do eventValue = undefined
        )
        eventValue
    )

    fn familyValidation rowValue rowIndex =
    (
        local statusValue = "READY"
        local detailValue = ""
        local buildableValue = true
        local nodesValue = resolveFamilyNodes rowValue
        local deletedCount = rowValue.handles.count - nodesValue.count
        local shapeNode = nodeFromHandle rowValue.shapeHandle

        if eventNameCollision rowIndex then
        (
            statusValue = "EVENT NAME CONFLICT"
            detailValue = "A standard and nonstandard Family resolve to the same LUNAR_ Event name."
            buildableValue = false
        )
        else if shapeNode == undefined then
        (
            statusValue = "SHAPE SOURCE DELETED"
            detailValue = "Analyze again after restoring or replacing the original Shape Source."
            buildableValue = false
        )
        else if nodesValue.count == 0 then
        (
            statusValue = "NO VALID SOURCE NODES"
            detailValue = "All analyzed Source Nodes have been deleted."
            buildableValue = false
        )
        else if not chkIgnoreInstances.checked then
        (
            local sourceBase = undefined
            local canValidate = true
            try (sourceBase = shapeNode.baseObject) catch (canValidate = false)
            if sourceBase == undefined do canValidate = false

            if canValidate then
            (
                local mismatchValue = false
                for nodeValue in nodesValue while not mismatchValue and canValidate do
                (
                    local nodeBase = undefined
                    try (nodeBase = nodeValue.baseObject) catch (canValidate = false)
                    if canValidate and (nodeBase == undefined or nodeBase != sourceBase) do mismatchValue = true
                )

                if not canValidate then
                (
                    statusValue = "UNSUPPORTED / CANNOT VALIDATE"
                    detailValue = "Base Object identity could not be read safely."
                    buildableValue = false
                )
                else if mismatchValue then
                (
                    statusValue = "INSTANCE / GEOMETRY MISMATCH"
                    detailValue = "Family members do not all share the Shape Source Base Object."
                    buildableValue = false
                )
                else
                (
                    statusValue = "READY / SHARED BASE OBJECT"
                )
            )
            else
            (
                statusValue = "UNSUPPORTED / CANNOT VALIDATE"
                detailValue = "Base Object identity could not be read safely."
                buildableValue = false
            )
        )
        else
        (
            statusValue = "NAME GROUP / INSTANCE IGNORED"
        )

        if buildableValue and not rowValue.standardName do
        (
            statusValue = "NONSTANDARD NAME / " + statusValue
            if detailValue == "" do detailValue = "The full Node name is used as an independent Family name."
        )

        if buildableValue and deletedCount > 0 do
        (
            statusValue += " / DELETED " + deletedCount as string
            detailValue = "Deleted non-Shape Source Nodes will be skipped."
        )

        if buildableValue and isTyFlowNode targetFlow do
        (
            local existingEvent = findExistingLunarEvent rowValue.eventName
            if existingEvent != undefined then
            (
                if chkUpdateExisting.checked then
                    statusValue = "UPDATE READY / " + statusValue
                else
                (
                    statusValue = "ALREADY EXISTS"
                    detailValue = "Update Existing LUNAR Events is OFF; this Family will be skipped."
                    buildableValue = false
                )
            )
        )

        #(statusValue, detailValue, buildableValue)
    )

    fn refreshFamilyList =
    (
        lvFamilies.BeginUpdate()
        lvFamilies.Items.Clear()

        for rowValue in familyRows do
        (
            local itemValue = dotNetObject "System.Windows.Forms.ListViewItem" rowValue.familyName
            itemValue.SubItems.Add (rowValue.handles.count as string)
            itemValue.SubItems.Add (nodeNameFromHandle rowValue.shapeHandle)
            itemValue.SubItems.Add rowValue.status
            lvFamilies.Items.Add itemValue
        )

        lvFamilies.EndUpdate()
    )

    fn refreshBuildAvailability =
    (
        local hasBuildableFamily = false
        for rowValue in familyRows while not hasBuildableFamily do
            if rowValue.buildable do hasBuildableFamily = true
        btnBuild.enabled = analysisReady and isTyFlowNode targetFlow and hasBuildableFamily
    )

    fn refreshAnalysisStatuses updateUI:true =
    (
        if analysisReady do
        (
            for rowIndex = 1 to familyRows.count do
            (
                local validationValue = familyValidation familyRows[rowIndex] rowIndex
                familyRows[rowIndex].status = validationValue[1]
                familyRows[rowIndex].detail = validationValue[2]
                familyRows[rowIndex].buildable = validationValue[3]
            )
        )

        if updateUI do
        (
            refreshFamilyList()
            refreshBuildAvailability()
        )
    )

    fn updateTargetUI =
    (
        if isTyFlowNode targetFlow then
            lblTarget.text = "Target: " + targetFlow.name
        else
            lblTarget.text = "Target: Not set"

        if analysisReady do refreshAnalysisStatuses updateUI:true
        refreshBuildAvailability()
    )

    fn setTargetNode nodeValue =
    (
        if isTyFlowNode nodeValue then
        (
            targetFlow = nodeValue
            updateTargetUI()
            setStatus ("Target tyFlow registered: " + targetFlow.name)
            true
        )
        else
        (
            setStatus "Target registration failed: the Node is not a tyFlow Object."
            false
        )
    )

    fn clearTargetNode =
    (
        targetFlow = undefined
        updateTargetUI()
        setStatus "Target tyFlow cleared. Analyze data is unchanged."
        true
    )

    fn useSelectedTyFlow =
    (
        local candidatesValue = #()
        for nodeValue in selection do
            if isTyFlowNode nodeValue do append candidatesValue nodeValue

        if candidatesValue.count == 1 then
            setTargetNode candidatesValue[1]
        else
        (
            setStatus ("Select exactly one tyFlow Object. Found: " + candidatesValue.count as string)
            false
        )
    )

    fn analyzeNodes nodeValues updateUI:true =
    (
        familyRows = #()
        analysisReady = false
        analyzedSourceCount = 0
        analyzedNonstandardCount = 0
        lastBuildSummary = #(0, 0, 0, 0, 0)
        local seenHandles = #()

        for nodeValue in nodeValues do
        (
            if isValidStoredNode nodeValue and nodeValue != targetFlow and not isTyFlowNode nodeValue do
            (
                local handleValue = safeNodeHandle nodeValue
                if handleValue != 0 and findItem seenHandles handleValue == 0 do
                (
                    append seenHandles handleValue
                    local familyInfo = parseFamilyName nodeValue.name
                    local familyNameValue = familyInfo[1]
                    local standardValue = familyInfo[2]
                    local keyValue = (if standardValue then "STANDARD|" else "NONSTANDARD|") + familyNameValue
                    local rowIndex = findFamilyRowIndex keyValue

                    if rowIndex == 0 then
                    (
                        local newRow = LunarTyFlowPlacementFamilyRow groupKey:keyValue familyName:familyNameValue handles:#(handleValue) shapeHandle:handleValue standardName:standardValue nonstandardCount:(if standardValue then 0 else 1) eventName:("LUNAR_" + familyNameValue)
                        append familyRows newRow
                    )
                    else
                    (
                        append familyRows[rowIndex].handles handleValue
                        if not standardValue do familyRows[rowIndex].nonstandardCount += 1
                    )

                    analyzedSourceCount += 1
                    if not standardValue do analyzedNonstandardCount += 1
                )
            )
        )

        analysisReady = analyzedSourceCount > 0 and familyRows.count > 0
        if analysisReady do refreshAnalysisStatuses updateUI:false

        if updateUI do
        (
            lblSelected.text = "Selected Source Nodes: " + analyzedSourceCount as string
            lblAnalyzeSnapshot.text = if analysisReady then "Analyze Snapshot: Ready" else "Analyze Snapshot: Not ready"
            lblSummary.text = "Selected: " + analyzedSourceCount as string +
                " | Families: " + familyRows.count as string +
                " | Nonstandard: " + analyzedNonstandardCount as string
            refreshFamilyList()
            refreshBuildAvailability()
        )

        if analysisReady then
        (
            setStatus ("Analyze complete. Stored " + analyzedSourceCount as string + " Source Node handles in " + familyRows.count as string + " Families. Scene unchanged.")
            true
        )
        else
        (
            setStatus "Analyze stopped: select one or more valid Source Nodes. tyFlow Objects are excluded."
            false
        )
    )

    fn analyzeSelection =
    (
        analyzeNodes (selection as array) updateUI:true
    )

    fn hasRequiredProperties objectValue propertyNames =
    (
        local supportedValue = objectValue != undefined
        for propertyNameValue in propertyNames while supportedValue do
            if not isProperty objectValue propertyNameValue do supportedValue = false
        supportedValue
    )

    fn nodeArraysEqual leftValue rightValue =
    (
        local equalValue = leftValue.count == rightValue.count
        if equalValue do
        (
            for indexValue = 1 to leftValue.count while equalValue do
                if leftValue[indexValue] != rightValue[indexValue] do equalValue = false
        )
        equalValue
    )

    fn configureBirthObjects operatorValue sourceNodes =
    (
        local requiredProperties = #(
            #objectList, #objectsInheritGeometry, #objectsSplitGroup, #objectsSplitElements,
            #objectsCenterPivots, #inheritPosition, #inheritRotation, #inheritScale, #inheritVelocity
        )
        local successValue = hasRequiredProperties operatorValue requiredProperties
        local messageValue = ""

        if not successValue then
            messageValue = "Birth Objects does not expose the required tyFlow 2.0100 properties."
        else
        (
            try
            (
                operatorValue.objectList = sourceNodes
                operatorValue.objectsInheritGeometry = false
                operatorValue.objectsSplitGroup = false
                operatorValue.objectsSplitElements = false
                operatorValue.objectsCenterPivots = false
                operatorValue.inheritPosition = true
                operatorValue.inheritRotation = true
                operatorValue.inheritScale = true
                operatorValue.inheritVelocity = false

                successValue = nodeArraysEqual operatorValue.objectList sourceNodes and
                    operatorValue.objectsInheritGeometry == false and
                    operatorValue.objectsCenterPivots == false and
                    operatorValue.inheritPosition == true and
                    operatorValue.inheritRotation == true and
                    operatorValue.inheritScale == true

                if not successValue do messageValue = "Birth Objects property verification failed after assignment."
            )
            catch
            (
                successValue = false
                messageValue = "Birth Objects configuration failed: " + exceptionText()
            )
        )

        #(successValue, messageValue)
    )

    fn configureShape operatorValue shapeNode =
    (
        local requiredProperties = #(
            #frequency_tab, #scale_tab, #scaleVal_tab, #scaleVariation_tab,
            #shape_type_tab, #instancedGeo_tab, #meshSplitGroup_tab,
            #meshSplitElements_tab, #meshCenterPivots_tab, #referenceNode, #shapeMode
        )
        local successValue = hasRequiredProperties operatorValue requiredProperties
        local messageValue = ""

        if not successValue then
            messageValue = "Shape does not expose the required tyFlow 2.0100 properties."
        else
        (
            try
            (
                operatorValue.frequency_tab = #(100.0)
                operatorValue.scale_tab = #(false)
                operatorValue.scaleVal_tab = #(100.0)
                operatorValue.scaleVariation_tab = #(0.0)
                operatorValue.shape_type_tab = #(2)
                operatorValue.instancedGeo_tab = #(shapeNode)
                operatorValue.meshSplitGroup_tab = #(false)
                operatorValue.meshSplitElements_tab = #(false)
                operatorValue.meshCenterPivots_tab = #(false)

                successValue = operatorValue.shapeMode == 2 and
                    operatorValue.referenceNode == shapeNode and
                    operatorValue.meshCenterPivots_tab.count == 1 and
                    operatorValue.meshCenterPivots_tab[1] == false and
                    operatorValue.scale_tab.count == 1 and
                    operatorValue.scale_tab[1] == false

                if not successValue do messageValue = "Shape Reference Object or pivot verification failed after assignment."
            )
            catch
            (
                successValue = false
                messageValue = "Shape configuration failed: " + exceptionText()
            )
        )

        #(successValue, messageValue)
    )

    fn configureMesh operatorValue =
    (
        local successValue = hasRequiredProperties operatorValue #(#meshType, #renderOnly)
        local messageValue = ""

        if not successValue then
            messageValue = "Mesh does not expose the required tyFlow 2.0100 properties."
        else
        (
            try
            (
                -- Verified installed values for Mesh (TriMesh [Render]).
                operatorValue.meshType = 0
                operatorValue.renderOnly = true
                successValue = operatorValue.meshType == 0 and operatorValue.renderOnly == true
                if not successValue do messageValue = "Mesh TriMesh / Render Only verification failed after assignment."
            )
            catch
            (
                successValue = false
                messageValue = "Mesh configuration failed: " + exceptionText()
            )
        )

        #(successValue, messageValue)
    )

    fn configureDisplay operatorValue =
    (
        local successValue = hasRequiredProperties operatorValue #(#displayMode)
        local messageValue = ""

        if not successValue then
            messageValue = "Display does not expose the required tyFlow 2.0100 properties."
        else
        (
            try
            (
                -- Verified installed value for Display (Geometry).
                operatorValue.displayMode = 4
                successValue = operatorValue.displayMode == 4
                if not successValue do messageValue = "Display Geometry verification failed after assignment."
            )
            catch
            (
                successValue = false
                messageValue = "Display configuration failed: " + exceptionText()
            )
        )

        #(successValue, messageValue)
    )

    fn captureBirthState operatorValue =
    (
        local stateValue = undefined
        try
        (
            stateValue = #(
                copy operatorValue.objectList,
                operatorValue.objectsInheritGeometry,
                operatorValue.objectsSplitGroup,
                operatorValue.objectsSplitElements,
                operatorValue.objectsCenterPivots,
                operatorValue.inheritPosition,
                operatorValue.inheritRotation,
                operatorValue.inheritScale,
                operatorValue.inheritVelocity
            )
        )
        catch (stateValue = undefined)
        stateValue
    )

    fn restoreBirthState operatorValue stateValue =
    (
        local restoredValue = operatorValue != undefined and stateValue != undefined
        if restoredValue do
        (
            try
            (
                operatorValue.objectList = stateValue[1]
                operatorValue.objectsInheritGeometry = stateValue[2]
                operatorValue.objectsSplitGroup = stateValue[3]
                operatorValue.objectsSplitElements = stateValue[4]
                operatorValue.objectsCenterPivots = stateValue[5]
                operatorValue.inheritPosition = stateValue[6]
                operatorValue.inheritRotation = stateValue[7]
                operatorValue.inheritScale = stateValue[8]
                operatorValue.inheritVelocity = stateValue[9]
            )
            catch (restoredValue = false)
        )
        restoredValue
    )

    fn captureShapeState operatorValue =
    (
        local stateValue = undefined
        try
        (
            stateValue = #(
                copy operatorValue.frequency_tab,
                copy operatorValue.scale_tab,
                copy operatorValue.scaleVal_tab,
                copy operatorValue.scaleVariation_tab,
                copy operatorValue.shape_type_tab,
                copy operatorValue.instancedGeo_tab,
                copy operatorValue.meshSplitGroup_tab,
                copy operatorValue.meshSplitElements_tab,
                copy operatorValue.meshCenterPivots_tab
            )
        )
        catch (stateValue = undefined)
        stateValue
    )

    fn restoreShapeState operatorValue stateValue =
    (
        local restoredValue = operatorValue != undefined and stateValue != undefined
        if restoredValue do
        (
            try
            (
                operatorValue.frequency_tab = stateValue[1]
                operatorValue.scale_tab = stateValue[2]
                operatorValue.scaleVal_tab = stateValue[3]
                operatorValue.scaleVariation_tab = stateValue[4]
                operatorValue.shape_type_tab = stateValue[5]
                operatorValue.instancedGeo_tab = stateValue[6]
                operatorValue.meshSplitGroup_tab = stateValue[7]
                operatorValue.meshSplitElements_tab = stateValue[8]
                operatorValue.meshCenterPivots_tab = stateValue[9]
            )
            catch (restoredValue = false)
        )
        restoredValue
    )

    fn captureMeshState operatorValue =
    (
        local stateValue = undefined
        try (stateValue = #(operatorValue.meshType, operatorValue.renderOnly)) catch (stateValue = undefined)
        stateValue
    )

    fn restoreMeshState operatorValue stateValue =
    (
        local restoredValue = operatorValue != undefined and stateValue != undefined
        if restoredValue do
        (
            try
            (
                operatorValue.meshType = stateValue[1]
                operatorValue.renderOnly = stateValue[2]
            )
            catch (restoredValue = false)
        )
        restoredValue
    )

    fn captureDisplayState operatorValue =
    (
        local stateValue = undefined
        try (stateValue = #(operatorValue.displayMode)) catch (stateValue = undefined)
        stateValue
    )

    fn restoreDisplayState operatorValue stateValue =
    (
        local restoredValue = operatorValue != undefined and stateValue != undefined
        if restoredValue do
        (
            try (operatorValue.displayMode = stateValue[1]) catch (restoredValue = false)
        )
        restoredValue
    )

    fn operatorObjectAt eventValue indexValue =
    (
        local operatorValue = undefined
        try
        (
            local subAnimValue = eventValue[indexValue]
            if subAnimValue != undefined do operatorValue = subAnimValue.object
        )
        catch (operatorValue = undefined)
        if operatorValue != undefined and (classOf operatorValue as string) != "tyOperator" do operatorValue = undefined
        operatorValue
    )

    fn findEventOperator eventValue requiredProperty =
    (
        local resultValue = undefined
        local indexValue = 1
        local continueValue = true

        while continueValue and indexValue <= 512 do
        (
            local operatorValue = operatorObjectAt eventValue indexValue
            if operatorValue == undefined then
                continueValue = false
            else
            (
                if isProperty operatorValue requiredProperty do resultValue = operatorValue
                if resultValue != undefined then continueValue = false else indexValue += 1
            )
        )
        resultValue
    )

    fn buildFamily rowValue sourceNodes shapeNode createdOffset =
    (
        local existingEvent = findExistingLunarEvent rowValue.eventName
        local eventValue = existingEvent
        local createdEvent = false
        local addedBirth = undefined
        local addedShape = undefined
        local addedMesh = undefined
        local addedDisplay = undefined
        local birthOperator = undefined
        local shapeOperator = undefined
        local meshOperator = undefined
        local displayOperator = undefined
        local birthState = undefined
        local shapeState = undefined
        local meshState = undefined
        local displayState = undefined
        local successValue = false
        local stateValue = #failed
        local messageValue = ""

        if existingEvent != undefined and not chkUpdateExisting.checked then
        (
            stateValue = #skipped
            messageValue = "ALREADY EXISTS"
        )
        else
        (
            try
            (
                if eventValue == undefined then
                (
                    eventValue = targetFlow.addEvent()
                    if eventValue == undefined do throw "tyFlow.addEvent() returned undefined."
                    createdEvent = true
                    eventValue.setName rowValue.eventName
                    try
                    (
                        local defaultPosition = eventValue.getPosition()
                        eventValue.setPosition (defaultPosition + [0, createdOffset * 170])
                    )
                    catch()
                )

                birthOperator = findEventOperator eventValue #objectList
                if birthOperator == undefined then
                (
                    birthOperator = eventValue.addOperator "Birth Objects" -1
                    addedBirth = birthOperator
                )
                else
                (
                    birthState = captureBirthState birthOperator
                )

                shapeOperator = findEventOperator eventValue #instancedGeo_tab
                if shapeOperator == undefined then
                (
                    shapeOperator = eventValue.addOperator "Shape" -1
                    addedShape = shapeOperator
                )
                else
                (
                    shapeState = captureShapeState shapeOperator
                )

                meshOperator = findEventOperator eventValue #meshType
                if meshOperator == undefined then
                (
                    meshOperator = eventValue.addOperator "Mesh" -1
                    addedMesh = meshOperator
                )
                else
                (
                    meshState = captureMeshState meshOperator
                )

                displayOperator = findEventOperator eventValue #displayMode
                if displayOperator == undefined then
                (
                    displayOperator = eventValue.addOperator "Display" -1
                    addedDisplay = displayOperator
                )
                else
                (
                    displayState = captureDisplayState displayOperator
                )

                local birthResult = configureBirthObjects birthOperator sourceNodes
                if not birthResult[1] do throw birthResult[2]
                local shapeResult = configureShape shapeOperator shapeNode
                if not shapeResult[1] do throw shapeResult[2]
                local meshResult = configureMesh meshOperator
                if not meshResult[1] do throw meshResult[2]
                local displayResult = configureDisplay displayOperator
                if not displayResult[1] do throw displayResult[2]

                successValue = true
                stateValue = if createdEvent then #created else #updated
                messageValue = if createdEvent then "CREATED" else "UPDATED"
            )
            catch
            (
                messageValue = exceptionText()
                if createdEvent and eventValue != undefined then
                    try (eventValue.remove()) catch()
                else
                (
                    if addedDisplay != undefined then
                        try (addedDisplay.remove()) catch()
                    else if displayState != undefined do
                        if not restoreDisplayState displayOperator displayState do ltpLog "ERROR" (rowValue.eventName + ": Display rollback failed.")

                    if addedMesh != undefined then
                        try (addedMesh.remove()) catch()
                    else if meshState != undefined do
                        if not restoreMeshState meshOperator meshState do ltpLog "ERROR" (rowValue.eventName + ": Mesh rollback failed.")

                    if addedShape != undefined then
                        try (addedShape.remove()) catch()
                    else if shapeState != undefined do
                        if not restoreShapeState shapeOperator shapeState do ltpLog "ERROR" (rowValue.eventName + ": Shape rollback failed.")

                    if addedBirth != undefined then
                        try (addedBirth.remove()) catch()
                    else if birthState != undefined do
                        if not restoreBirthState birthOperator birthState do ltpLog "ERROR" (rowValue.eventName + ": Birth Objects rollback failed.")
                )
                successValue = false
                stateValue = #failed
            )
        )

        #(successValue, stateValue, messageValue)
    )

    fn buildAnalyzed updateUI:true =
    (
        if not analysisReady then
        (
            setStatus "Build stopped: run Analyze first."
            false
        )
        else if not isTyFlowNode targetFlow then
        (
            setStatus "Build stopped: register a valid Target tyFlow."
            false
        )
        else
        (
            refreshAnalysisStatuses updateUI:false
            local createdCount = 0
            local updatedCount = 0
            local skippedCount = 0
            local failedCount = 0
            local sourceNodeCount = 0
            local createdOffset = 0

            undo "Lunar tyFlow Placement Build / Update" on
            (
                for rowIndex = 1 to familyRows.count do
                (
                    local rowValue = familyRows[rowIndex]
                    local validationValue = familyValidation rowValue rowIndex
                    rowValue.status = validationValue[1]
                    rowValue.detail = validationValue[2]
                    rowValue.buildable = validationValue[3]

                    if not rowValue.buildable then
                    (
                        skippedCount += 1
                        ltpLog "WARN" (rowValue.eventName + ": " + rowValue.status)
                    )
                    else
                    (
                        local sourceNodes = resolveFamilyNodes rowValue
                        local shapeNode = nodeFromHandle rowValue.shapeHandle
                        sourceNodeCount += sourceNodes.count
                        local buildResult = buildFamily rowValue sourceNodes shapeNode createdOffset

                        case buildResult[2] of
                        (
                            #created:
                            (
                                createdCount += 1
                                createdOffset += 1
                            )
                            #updated: updatedCount += 1
                            #skipped: skippedCount += 1
                            default: failedCount += 1
                        )

                        if buildResult[1] then
                            ltpLog "INFO" (rowValue.eventName + ": " + buildResult[3])
                        else
                            ltpLog "ERROR" (rowValue.eventName + ": " + buildResult[3])
                    )
                )

                if createdCount + updatedCount > 0 do
                    try (targetFlow.reset_simulation()) catch (ltpLog "WARN" ("Simulation reset failed: " + exceptionText()))
            )

            lastBuildSummary = #(createdCount, updatedCount, skippedCount, failedCount, sourceNodeCount)
            refreshAnalysisStatuses updateUI:false

            if updateUI do
            (
                refreshFamilyList()
                refreshBuildAvailability()
                lblSummary.text = "Created Events: " + createdCount as string +
                    " | Updated Events: " + updatedCount as string +
                    " | Skipped: " + skippedCount as string +
                    " | Failed: " + failedCount as string +
                    " | Source Nodes: " + sourceNodeCount as string
            )

            setStatus ("Build / Update complete. Created " + createdCount as string +
                ", Updated " + updatedCount as string +
                ", Skipped " + skippedCount as string +
                ", Failed " + failedCount as string + ". Source Nodes were not modified.")
            failedCount == 0
        )
    )

    fn getFamilyData =
    (
        for rowValue in familyRows collect #(
            rowValue.familyName,
            rowValue.handles.count,
            nodeNameFromHandle rowValue.shapeHandle,
            rowValue.status,
            rowValue.buildable,
            rowValue.standardName,
            rowValue.eventName
        )
    )

    fn getLastBuildSummary =
    (
        lastBuildSummary
    )

    fn getTargetNode =
    (
        if isTyFlowNode targetFlow then targetFlow else undefined
    )

    fn setIgnoreInstanceRelationship stateValue refresh:true =
    (
        chkIgnoreInstances.checked = stateValue
        if refresh and analysisReady do refreshAnalysisStatuses updateUI:true
        true
    )

    fn setUpdateExisting stateValue refresh:true =
    (
        chkUpdateExisting.checked = stateValue
        if refresh and analysisReady do refreshAnalysisStatuses updateUI:true
        true
    )

    on LunarTyFlowPlacementRollout open do
    (
        lvFamilies.View = (dotNetClass "System.Windows.Forms.View").Details
        lvFamilies.FullRowSelect = true
        lvFamilies.GridLines = true
        lvFamilies.MultiSelect = false
        lvFamilies.HideSelection = false
        lvFamilies.Columns.Add "Family" 180
        lvFamilies.Columns.Add "Count" 58
        lvFamilies.Columns.Add "Shape Source" 180
        lvFamilies.Columns.Add "Status" 330
        setStatus "Ready. Register a Target tyFlow at any time; Analyze itself is read-only."
    )

    on btnUseSelectedTyFlow pressed do useSelectedTyFlow()
    on btnClearTarget pressed do clearTargetNode()
    on btnAnalyze pressed do analyzeSelection()
    on btnBuild pressed do buildAnalyzed updateUI:true

    on chkIgnoreInstances changed stateValue do
        if analysisReady do refreshAnalysisStatuses updateUI:true

    on chkUpdateExisting changed stateValue do
        if analysisReady do refreshAnalysisStatuses updateUI:true
)

createDialog LunarTyFlowPlacementRollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
