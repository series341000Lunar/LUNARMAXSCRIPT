/*
    Lunar Geometry Preprocessor MK1
    Autodesk 3ds Max 2026 / MAXScript only

    Source scene is authoritative:
    - Analyze is read-only and stores node handles.
    - Geometry grouping uses object-space TriMesh vertices and face topology.
    - Rename changes node names only and uses a collision-safe two-pass rename.
    - Instance Normalize uses the Base Object assignment method already verified
      by Lunar Transform Assistant, with state/bounds verification and rollback.
    - No pivot centering, Reset XForm, collapse, attach, conversion, material
      consolidation, layer changes, visibility changes, or tyFlow operations.
*/

global LunarGeometryPreprocessorRollout

struct LunarGeometrySignature
(
    numVerts = 0,
    numFaces = 0,
    boundsMin = [0,0,0],
    boundsMax = [0,0,0],
    bucketKey = "",
    hashValue = "",
    vertices = #(),
    faces = #()
)

struct LunarGeometryGroupRow
(
    id = 0,
    handles = #(),
    representativeHandle = 0,
    instanceSourceHandle = 0,
    signature = undefined,
    groupName = "",
    status = "",
    detail = "",
    sameCountDifferent = false,
    supported = true,
    stackSafe = true,
    sharedCount = 1,
    copyCount = 0,
    instanceUnsafe = false
)

struct LunarGeometryNodeState
(
    transformValue = undefined,
    positionValue = undefined,
    rotationValue = undefined,
    scaleValue = undefined,
    objectOffsetPosValue = undefined,
    objectOffsetRotValue = undefined,
    objectOffsetScaleValue = undefined,
    pivotValue = undefined,
    parentValue = undefined,
    layerValue = undefined,
    materialValue = undefined,
    hiddenValue = false,
    frozenValue = false,
    visibilityValue = 1.0,
    wireColorValue = undefined,
    boundsMin = undefined,
    boundsMax = undefined,
    baseObjectValue = undefined
)

if LunarGeometryPreprocessorRollout != undefined do
(
    try (destroyDialog LunarGeometryPreprocessorRollout) catch()
)

rollout LunarGeometryPreprocessorRollout "LUNAR GEOMETRY PREPROCESSOR MK1" width:920 height:760
(
    groupBox gbSource "SOURCE" pos:[8,8] width:904 height:76
    label lblSelected "Selected Nodes : 0" pos:[20,30] width:270 height:18
    label lblValid "Valid Geometry : 0" pos:[310,30] width:270 height:18
    label lblSkipped "Skipped : 0" pos:[600,30] width:270 height:18
    label lblSnapshot "Analyze Snapshot : Not ready" pos:[20,54] width:850 height:18

    button btnAnalyze "ANALYZE SELECTED GEOMETRY" pos:[8,92] width:904 height:38

    dotNetControl gridGroups "System.Windows.Forms.DataGridView" pos:[8,140] width:904 height:344

    button btnSelectGroup "SELECT GROUP" pos:[8,494] width:210 height:32 enabled:false
    button btnFrameGroup "FRAME GROUP" pos:[228,494] width:210 height:32 enabled:false
    label lblSelectionHint "Select one table row, then inspect that strict Geometry Group in the viewport." pos:[456,502] width:450 height:18

    groupBox gbOptions "OPTIONS / SAFETY" pos:[8,536] width:904 height:64
    checkbox chkMakeInstances "Make Matching Copies Instances in APPLY ALL" pos:[20,558] width:330 height:20 checked:true
    label lblSafety "Renumber: 001 per Group  |  Transform/Pivot/Parent/Layer/Material/Visibility: always preserved" pos:[370,558] width:525 height:20

    button btnRename "RENAME GROUPS" pos:[8,610] width:290 height:40 enabled:false
    button btnInstances "MAKE INSTANCES" pos:[315,610] width:290 height:40 enabled:false
    button btnApplyAll "APPLY ALL" pos:[622,610] width:290 height:40 enabled:false

    label lblSummary "Groups: 0 | Source Nodes: 0 | Renamed: 0 | Already: 0 | Converted: 0 | Skipped: 0 | Failed: 0" pos:[10,664] width:900 height:18
    editText txtStatus "" pos:[8,690] width:904 height:60 readOnly:true style:#multiLine

    local geometryTolerance = 0.0001
    local boundsTolerance = 0.001
    local groups = #()
    local analysisReady = false
    local analyzedSelectedCount = 0
    local analyzedValidCount = 0
    local analyzedSkippedCount = 0
    local updatingGrid = false
    local lastSummary = #(0,0,0,0,0,0,0)
    local regexClass = dotNetClass "System.Text.RegularExpressions.Regex"

    fn lgpLog levelValue messageValue =
    (
        format "[LGP][%] %\n" levelValue messageValue
    )

    fn exceptionText =
    (
        local textValue = getCurrentException() as string
        textValue = substituteString textValue "\r" " "
        substituteString textValue "\n" " "
    )

    fn setStatus messageValue =
    (
        txtStatus.text = messageValue
    )

    fn isValidStoredNode nodeValue =
    (
        nodeValue != undefined and isValidNode nodeValue
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

    fn normalizedText textValue =
    (
        local resultValue = if textValue == undefined then "" else textValue as string
        regexClass.Replace resultValue "^\\s+|\\s+$" ""
    )

    fn isExcludedGeometryClass nodeValue =
    (
        local classText = ""
        local baseText = ""
        try (classText = classOf nodeValue as string) catch()
        try (baseText = classOf nodeValue.baseObject as string) catch()
        matchPattern classText pattern:"*tyFlow*" ignoreCase:true or
        matchPattern baseText pattern:"*tyFlow*" ignoreCase:true or
        matchPattern classText pattern:"*Particle*" ignoreCase:true or
        matchPattern baseText pattern:"*Particle*" ignoreCase:true or
        classText == "PF_Source" or baseText == "PF_Source"
    )

    fn isGeometryCandidate nodeValue =
    (
        local resultValue = false
        if isValidStoredNode nodeValue and not isGroupHead nodeValue and not isExcludedGeometryClass nodeValue do
        (
            try
            (
                local baseValue = nodeValue.baseObject
                resultValue = baseValue != undefined and superClassOf baseValue == GeometryClass and
                    not matchPattern (classOf baseValue as string) pattern:"*XRef*" ignoreCase:true
            )
            catch (resultValue = false)
        )
        resultValue
    )

    fn pointNear leftValue rightValue toleranceValue =
    (
        leftValue != undefined and rightValue != undefined and
        abs (leftValue.x - rightValue.x) <= toleranceValue and
        abs (leftValue.y - rightValue.y) <= toleranceValue and
        abs (leftValue.z - rightValue.z) <= toleranceValue
    )

    fn quantizedString value =
    (
        local scaledValue = value / geometryTolerance
        local roundedValue = if scaledValue >= 0.0 then floor (scaledValue + 0.5) else ceil (scaledValue - 0.5)
        formattedPrint roundedValue format:".0f"
    )

    fn sha256String textValue =
    (
        local resultValue = "HASH_ERROR"
        try
        (
            local shaClass = dotNetClass "System.Security.Cryptography.SHA256"
            local encodingClass = dotNetClass "System.Text.Encoding"
            local converterClass = dotNetClass "System.BitConverter"
            local shaValue = shaClass.Create()
            local bytesValue = encodingClass.UTF8.GetBytes textValue
            local hashBytes = shaValue.ComputeHash bytesValue
            resultValue = converterClass.ToString hashBytes
            resultValue = substituteString resultValue "-" ""
            shaValue.Dispose()
        )
        catch
        (
            lgpLog "WARN" ("SHA-256 generation failed; strict comparison remains active: " + exceptionText())
        )
        resultValue
    )

    fn buildGeometrySignature nodeValue =
    (
        local meshValue = undefined
        local resultValue = undefined
        try
        (
            meshValue = snapshotAsMesh nodeValue
            if meshValue == undefined do throw "snapshotAsMesh returned undefined."

            local vertexCount = meshValue.numverts
            local faceCount = meshValue.numfaces
            if vertexCount < 1 or faceCount < 1 do throw "The evaluated mesh is empty."

            local verticesValue = #()
            local facesValue = #()
            verticesValue.count = vertexCount
            facesValue.count = faceCount
            local firstVertex = getVert meshValue 1
            local inverseObjectTM = inverse nodeValue.objectTransform
            firstVertex = firstVertex * inverseObjectTM
            local minValue = firstVertex
            local maxValue = firstVertex
            local builderValue = dotNetObject "System.Text.StringBuilder"

            builderValue.Append (vertexCount as string)
            builderValue.Append "|"
            builderValue.Append (faceCount as string)
            builderValue.Append "|V|"

            for vertexIndex = 1 to vertexCount do
            (
                local vertexValue = (getVert meshValue vertexIndex) * inverseObjectTM
                verticesValue[vertexIndex] = vertexValue
                minValue.x = amin minValue.x vertexValue.x
                minValue.y = amin minValue.y vertexValue.y
                minValue.z = amin minValue.z vertexValue.z
                maxValue.x = amax maxValue.x vertexValue.x
                maxValue.y = amax maxValue.y vertexValue.y
                maxValue.z = amax maxValue.z vertexValue.z
                builderValue.Append (quantizedString vertexValue.x)
                builderValue.Append ","
                builderValue.Append (quantizedString vertexValue.y)
                builderValue.Append ","
                builderValue.Append (quantizedString vertexValue.z)
                builderValue.Append ";"
            )

            builderValue.Append "|F|"
            for faceIndex = 1 to faceCount do
            (
                local faceValue = getFace meshValue faceIndex
                facesValue[faceIndex] = faceValue
                builderValue.Append ((faceValue.x as integer) as string)
                builderValue.Append ","
                builderValue.Append ((faceValue.y as integer) as string)
                builderValue.Append ","
                builderValue.Append ((faceValue.z as integer) as string)
                builderValue.Append ";"
            )

            local bucketValue = (vertexCount as string) + "|" + (faceCount as string)

            resultValue = LunarGeometrySignature numVerts:vertexCount numFaces:faceCount \
                boundsMin:minValue boundsMax:maxValue bucketKey:bucketValue \
                hashValue:(sha256String (builderValue.ToString())) vertices:verticesValue faces:facesValue
        )
        catch
        (
            lgpLog "WARN" ((try (nodeValue.name) catch ("<node>")) + ": Geometry analysis failed: " + exceptionText())
            resultValue = undefined
        )
        meshValue = undefined
        resultValue
    )

    fn signaturesStrictEqual leftValue rightValue =
    (
        local equalValue = leftValue != undefined and rightValue != undefined
        if equalValue do equalValue = leftValue.numVerts == rightValue.numVerts and leftValue.numFaces == rightValue.numFaces
        if equalValue do
        (
            for vertexIndex = 1 to leftValue.vertices.count while equalValue do
                if not pointNear leftValue.vertices[vertexIndex] rightValue.vertices[vertexIndex] geometryTolerance do equalValue = false
        )
        if equalValue do
        (
            for faceIndex = 1 to leftValue.faces.count while equalValue do
            (
                local leftFace = leftValue.faces[faceIndex]
                local rightFace = rightValue.faces[faceIndex]
                if (leftFace.x as integer) != (rightFace.x as integer) or
                   (leftFace.y as integer) != (rightFace.y as integer) or
                   (leftFace.z as integer) != (rightFace.z as integer) do equalValue = false
            )
        )
        equalValue
    )

    fn trailingNumberInfo nodeName =
    (
        local matchValue = regexClass.Match (nodeName as string) "^(.*?)([0-9]+)$"
        if matchValue.Success then
        (
            local numberValue = 0
            try (numberValue = matchValue.Groups.Item[2].Value as integer) catch (numberValue = 0)
            #(true, numberValue)
        )
        else #(false, 0)
    )

    fn compareHandles leftHandle rightHandle =
    (
        local leftNode = nodeFromHandle leftHandle
        local rightNode = nodeFromHandle rightHandle
        if leftNode == undefined and rightNode == undefined then
        (
            if leftHandle < rightHandle then -1 else if leftHandle > rightHandle then 1 else 0
        )
        else if leftNode == undefined then 1
        else if rightNode == undefined then -1
        else
        (
            local leftInfo = trailingNumberInfo leftNode.name
            local rightInfo = trailingNumberInfo rightNode.name
            if leftInfo[1] and not rightInfo[1] then -1
            else if not leftInfo[1] and rightInfo[1] then 1
            else if leftInfo[1] and rightInfo[1] and leftInfo[2] != rightInfo[2] then
                (if leftInfo[2] < rightInfo[2] then -1 else 1)
            else
            (
                local leftName = toLower (leftNode.name as string)
                local rightName = toLower (rightNode.name as string)
                if leftName < rightName then -1
                else if leftName > rightName then 1
                else if leftHandle < rightHandle then -1
                else if leftHandle > rightHandle then 1
                else 0
            )
        )
    )

    fn sortedHandles handleValues =
    (
        local resultValue = for handleValue in handleValues collect handleValue
        qsort resultValue compareHandles
        resultValue
    )

    fn suggestedGroupName handleValues =
    (
        local resultValue = ""
        local firstValue = true
        local consistentValue = true
        for handleValue in handleValues while consistentValue do
        (
            local nodeValue = nodeFromHandle handleValue
            if nodeValue != undefined do
            (
                local prefixValue = regexClass.Replace (nodeValue.name as string) "[_\\-\\s]*[0-9]+$" ""
                prefixValue = normalizedText prefixValue
                if firstValue then
                (
                    resultValue = prefixValue
                    firstValue = false
                )
                else if toLower prefixValue != toLower resultValue do consistentValue = false
            )
        )
        if consistentValue then resultValue else ""
    )

    fn isSupportedBaseNode nodeValue =
    (
        if not isValidStoredNode nodeValue then #(false, "Node is invalid.")
        else if isGroupHead nodeValue then #(false, "Group heads are not supported.")
        else
        (
            local baseValue = undefined
            try (baseValue = nodeValue.baseObject) catch (return #(false, "Base Object access failed."))
            if baseValue == undefined then #(false, "Base Object does not exist.")
            else if superClassOf baseValue != GeometryClass then #(false, "Only ordinary Geometry Base Objects are supported.")
            else if matchPattern (classOf baseValue as string) pattern:"*XRef*" ignoreCase:true then #(false, "XRef Base Objects are not supported.")
            else #(true, "")
        )
    )

    fn updateInstanceAnalysis groupValue =
    (
        groupValue.stackSafe = groupValue.supported
        groupValue.sharedCount = 1
        groupValue.copyCount = amax 0 (groupValue.handles.count - 1)
        groupValue.instanceSourceHandle = groupValue.representativeHandle

        local baseValues = #()
        local baseHandles = #()
        local baseClasses = #()
        for handleValue in groupValue.handles do
        (
            local nodeValue = nodeFromHandle handleValue
            if nodeValue == undefined then
                groupValue.stackSafe = false
            else
            (
                local supportValue = isSupportedBaseNode nodeValue
                local modifierCount = 0
                try (modifierCount = nodeValue.modifiers.count) catch (modifierCount = -1)
                if not supportValue[1] or modifierCount != 0 do groupValue.stackSafe = false
                local baseValue = undefined
                try (baseValue = nodeValue.baseObject) catch()
                if baseValue == undefined then
                    groupValue.stackSafe = false
                else
                (
                    local baseIndex = findItem baseValues baseValue
                    if baseIndex == 0 then
                    (
                        append baseValues baseValue
                        append baseHandles #(handleValue)
                        append baseClasses (classOf baseValue)
                    )
                    else append baseHandles[baseIndex] handleValue
                )
            )
        )

        if baseClasses.count > 1 do
        (
            local firstClass = baseClasses[1]
            for classValue in baseClasses while groupValue.stackSafe do
                if classValue != firstClass do groupValue.stackSafe = false
        )

        local largestCount = 0
        local largestHandles = #()
        for handlesValue in baseHandles do
        (
            if handlesValue.count > largestCount then
            (
                largestCount = handlesValue.count
                largestHandles = handlesValue
            )
            else if handlesValue.count == largestCount and handlesValue.count > 0 do
            (
                local candidateSorted = sortedHandles handlesValue
                local currentSorted = sortedHandles largestHandles
                if compareHandles candidateSorted[1] currentSorted[1] < 0 do largestHandles = handlesValue
            )
        )

        if largestHandles.count > 0 do
        (
            local sortedLargest = sortedHandles largestHandles
            groupValue.instanceSourceHandle = sortedLargest[1]
        )
        groupValue.sharedCount = largestCount
        groupValue.copyCount = amax 0 (groupValue.handles.count - largestCount)
        true
    )

    fn analyzeBaseStatus groupValue =
    (
        if not groupValue.supported then "UNSUPPORTED GEOMETRY"
        else if groupValue.instanceUnsafe then "INSTANCE UNSAFE"
        else if not groupValue.stackSafe then "STACK UNSAFE / INSTANCE SKIPPED"
        else if groupValue.sharedCount == groupValue.handles.count and groupValue.handles.count > 1 then "ALREADY INSTANCED"
        else if groupValue.sharedCount > 1 and groupValue.copyCount > 0 then
            ("PARTIAL INSTANCE " + groupValue.sharedCount as string + " Shared / " + groupValue.copyCount as string + " Copies")
        else if groupValue.sameCountDifferent then "SAME COUNT / DIFFERENT GEOMETRY"
        else "READY"
    )

    fn invalidGroupNameReason groupNameValue =
    (
        local nameValue = normalizedText groupNameValue
        if nameValue == "" then "EMPTY GROUP NAME"
        else if nameValue != groupNameValue then "INVALID GROUP NAME"
        else
        (
            local invalidValue = false
            for tokenValue in #( "\\", "/", ":", "*", "?", "\"", "<", ">", "|", "\r", "\n", "\t" ) while not invalidValue do
                if findString nameValue tokenValue != undefined do invalidValue = true
            if invalidValue then "INVALID GROUP NAME" else ""
        )
    )

    fn collectSceneNodes parentValue resultValues =
    (
        for childIndex = 1 to parentValue.children.count do
        (
            local childValue = parentValue.children[childIndex]
            append resultValues childValue
            collectSceneNodes childValue resultValues
        )
        resultValues
    )

    fn finalNamesForGroup groupValue =
    (
        local resultValue = #()
        local orderedHandles = sortedHandles groupValue.handles
        for indexValue = 1 to orderedHandles.count do
            append resultValue (groupValue.groupName + "_" + formattedPrint indexValue format:"03d")
        resultValue
    )

    fn validateGroupNames updateStatuses:true =
    (
        local validValue = analysisReady and groups.count > 0
        local analyzedHandles = #()
        for groupValue in groups do join analyzedHandles groupValue.handles
        local sceneNodes = collectSceneNodes rootNode #()

        for groupIndex = 1 to groups.count do
        (
            local groupValue = groups[groupIndex]
            local reasonValue = invalidGroupNameReason groupValue.groupName

            if reasonValue == "" do
            (
                for otherIndex = 1 to groups.count while reasonValue == "" do
                    if otherIndex != groupIndex and toLower groups[otherIndex].groupName == toLower groupValue.groupName do
                        reasonValue = "DUPLICATE GROUP NAME"
            )

            if reasonValue == "" do
            (
                for handleValue in groupValue.handles while reasonValue == "" do
                    if nodeFromHandle handleValue == undefined do reasonValue = "DELETED NODE"
            )

            if reasonValue == "" and not groupValue.supported do reasonValue = "UNSUPPORTED GEOMETRY"

            if reasonValue == "" do
            (
                local finalNames = finalNamesForGroup groupValue
                for finalName in finalNames while reasonValue == "" do
                (
                    local finalLower = toLower finalName
                    for sceneNode in sceneNodes while reasonValue == "" do
                    (
                        local sceneHandle = safeNodeHandle sceneNode
                        if findItem analyzedHandles sceneHandle == 0 and toLower (sceneNode.name as string) == finalLower do
                            reasonValue = "NAME COLLISION"
                    )
                )
            )

            if reasonValue != "" then
            (
                validValue = false
                if updateStatuses do
                (
                    local baseStatusValue = analyzeBaseStatus groupValue
                    groupValue.status = reasonValue + (if baseStatusValue == "READY" then "" else " / " + baseStatusValue)
                    groupValue.detail = reasonValue
                )
            )
            else if updateStatuses do
            (
                groupValue.status = analyzeBaseStatus groupValue
                groupValue.detail = ""
            )
        )
        validValue
    )

    fn updateGridStatuses =
    (
        if gridGroups.Rows.Count == groups.count do
        (
            for groupIndex = 1 to groups.count do
            (
                local rowValue = gridGroups.Rows.Item[groupIndex - 1]
                rowValue.Cells.Item[4].Value = nodeNameFromHandle groups[groupIndex].representativeHandle
                rowValue.Cells.Item[6].Value = groups[groupIndex].status
            )
        )
    )

    fn updateActionAvailability =
    (
        local namesValid = validateGroupNames updateStatuses:true
        btnRename.enabled = analysisReady and namesValid
        btnInstances.enabled = analysisReady
        btnApplyAll.enabled = analysisReady and namesValid
        local hasSelection = analysisReady and gridGroups.CurrentCell != undefined
        btnSelectGroup.enabled = hasSelection
        btnFrameGroup.enabled = hasSelection
        updateGridStatuses()
    )

    fn refreshSummary =
    (
        lblSummary.text = "Groups: " + lastSummary[1] as string +
            " | Source Nodes: " + lastSummary[2] as string +
            " | Renamed: " + lastSummary[3] as string +
            " | Already: " + lastSummary[4] as string +
            " | Converted: " + lastSummary[5] as string +
            " | Skipped: " + lastSummary[6] as string +
            " | Failed: " + lastSummary[7] as string
    )

    fn refreshGrid =
    (
        updatingGrid = true
        gridGroups.SuspendLayout()
        gridGroups.Rows.Clear()
        for groupValue in groups do
        (
            local rowIndex = gridGroups.Rows.Add()
            local rowValue = gridGroups.Rows.Item[rowIndex]
            rowValue.Cells.Item[0].Value = formattedPrint groupValue.id format:"02d"
            rowValue.Cells.Item[1].Value = if groupValue.signature == undefined then "-" else groupValue.signature.numVerts as string
            rowValue.Cells.Item[2].Value = if groupValue.signature == undefined then "-" else groupValue.signature.numFaces as string
            rowValue.Cells.Item[3].Value = groupValue.handles.count as string
            rowValue.Cells.Item[4].Value = nodeNameFromHandle groupValue.representativeHandle
            rowValue.Cells.Item[5].Value = groupValue.groupName
            rowValue.Cells.Item[6].Value = groupValue.status
        )
        gridGroups.ResumeLayout()
        updatingGrid = false
        updateActionAvailability()
    )

    fn selectedGroupIndex =
    (
        if gridGroups.CurrentCell == undefined then 0
        else
        (
            local resultValue = gridGroups.CurrentCell.RowIndex + 1
            if resultValue < 1 or resultValue > groups.count then 0 else resultValue
        )
    )

    fn signatureForNodeCached nodeValue baseCache signatureCache =
    (
        local baseValue = undefined
        local modifierCount = -1
        try
        (
            baseValue = nodeValue.baseObject
            modifierCount = nodeValue.modifiers.count
        )
        catch()

        if baseValue != undefined and modifierCount == 0 then
        (
            local cacheIndex = findItem baseCache baseValue
            if cacheIndex > 0 then signatureCache[cacheIndex]
            else
            (
                local newSignature = buildGeometrySignature nodeValue
                append baseCache baseValue
                append signatureCache newSignature
                newSignature
            )
        )
        else buildGeometrySignature nodeValue
    )

    fn analyzeNodes nodeValues updateUI:true =
    (
        groups = #()
        analysisReady = false
        analyzedSelectedCount = nodeValues.count
        analyzedValidCount = 0
        analyzedSkippedCount = 0
        lastSummary = #(0,0,0,0,0,0,0)

        local seenHandles = #()
        local validHandles = #()
        for nodeValue in nodeValues do
        (
            local handleValue = safeNodeHandle nodeValue
            if handleValue != 0 and findItem seenHandles handleValue == 0 do
            (
                append seenHandles handleValue
                if isGeometryCandidate nodeValue then append validHandles handleValue else analyzedSkippedCount += 1
            )
        )
        validHandles = sortedHandles validHandles
        analyzedValidCount = validHandles.count

        local baseCache = #()
        local signatureCache = #()
        local bucketKeys = #()
        local bucketGroups = #()

        for handleValue in validHandles do
        (
            local nodeValue = nodeFromHandle handleValue
            local signatureValue = if nodeValue == undefined then undefined else signatureForNodeCached nodeValue baseCache signatureCache
            if signatureValue == undefined then
            (
                local unsupportedGroup = LunarGeometryGroupRow handles:#(handleValue) representativeHandle:handleValue \
                    instanceSourceHandle:handleValue signature:undefined groupName:(suggestedGroupName #(handleValue)) \
                    status:"UNSUPPORTED GEOMETRY" detail:"snapshotAsMesh failed." supported:false stackSafe:false
                append groups unsupportedGroup
            )
            else
            (
                local bucketIndex = findItem bucketKeys signatureValue.bucketKey
                if bucketIndex == 0 then
                (
                    append bucketKeys signatureValue.bucketKey
                    append bucketGroups #()
                    bucketIndex = bucketKeys.count
                )

                local matchingGroupIndex = 0
                for groupIndex in bucketGroups[bucketIndex] while matchingGroupIndex == 0 do
                (
                    local candidateSignature = groups[groupIndex].signature
                    if candidateSignature.hashValue == signatureValue.hashValue and signaturesStrictEqual candidateSignature signatureValue do
                        matchingGroupIndex = groupIndex
                )

                -- Quantization is only a hash acceleration. A value can sit on a
                -- quantization-cell boundary while still being within the strict
                -- transform-inversion tolerance, so the final comparison remains
                -- authoritative inside the already-small Verts/Faces bucket.
                if matchingGroupIndex == 0 do
                (
                    for groupIndex in bucketGroups[bucketIndex] while matchingGroupIndex == 0 do
                    (
                        local candidateSignature = groups[groupIndex].signature
                        if candidateSignature.hashValue != signatureValue.hashValue and signaturesStrictEqual candidateSignature signatureValue do
                            matchingGroupIndex = groupIndex
                    )
                )

                if matchingGroupIndex == 0 then
                (
                    local newGroup = LunarGeometryGroupRow handles:#(handleValue) representativeHandle:handleValue \
                        instanceSourceHandle:handleValue signature:signatureValue groupName:"" status:"READY"
                    append groups newGroup
                    append bucketGroups[bucketIndex] groups.count
                )
                else append groups[matchingGroupIndex].handles handleValue
            )
        )

        for groupIndex = 1 to groups.count do
        (
            groups[groupIndex].id = groupIndex
            groups[groupIndex].handles = sortedHandles groups[groupIndex].handles
            groups[groupIndex].representativeHandle = groups[groupIndex].handles[1]
            groups[groupIndex].groupName = suggestedGroupName groups[groupIndex].handles
        )

        for leftIndex = 1 to groups.count do
        (
            if groups[leftIndex].signature != undefined do
            (
                for rightIndex = 1 to groups.count while not groups[leftIndex].sameCountDifferent do
                (
                    if leftIndex != rightIndex and groups[rightIndex].signature != undefined and
                       groups[leftIndex].signature.numVerts == groups[rightIndex].signature.numVerts and
                       groups[leftIndex].signature.numFaces == groups[rightIndex].signature.numFaces and
                       not signaturesStrictEqual groups[leftIndex].signature groups[rightIndex].signature do
                        groups[leftIndex].sameCountDifferent = true
                )
            )
            updateInstanceAnalysis groups[leftIndex]
            groups[leftIndex].status = analyzeBaseStatus groups[leftIndex]
        )

        analysisReady = groups.count > 0 and analyzedValidCount > 0
        validateGroupNames updateStatuses:true
        lastSummary = #(groups.count, analyzedValidCount, 0, 0, 0, analyzedSkippedCount, 0)

        if updateUI do
        (
            lblSelected.text = "Selected Nodes : " + analyzedSelectedCount as string
            lblValid.text = "Valid Geometry : " + analyzedValidCount as string
            lblSkipped.text = "Skipped : " + analyzedSkippedCount as string
            lblSnapshot.text = if analysisReady then
                ("Analyze Snapshot : Ready (" + groups.count as string + " strict Geometry Groups, node handles retained)")
                else "Analyze Snapshot : Not ready"
            refreshGrid()
            refreshSummary()
        )

        if analysisReady then
        (
            setStatus ("Analyze complete. " + analyzedValidCount as string + " Geometry Nodes classified into " +
                groups.count as string + " strict Groups. Scene unchanged.")
            true
        )
        else
        (
            setStatus "Analyze stopped: select one or more supported Geometry Nodes. Non-Geometry Nodes are skipped."
            false
        )
    )

    fn analyzeSelection =
    (
        analyzeNodes (selection as array) updateUI:true
    )

    fn selectGroupByIndex groupIndex frameValue:false =
    (
        if groupIndex < 1 or groupIndex > groups.count then false
        else
        (
            local nodesValue = #()
            for handleValue in groups[groupIndex].handles do
            (
                local nodeValue = nodeFromHandle handleValue
                if nodeValue != undefined do append nodesValue nodeValue
            )
            if nodesValue.count == 0 then
            (
                setStatus "Group selection failed: all analyzed Nodes were deleted."
                false
            )
            else
            (
                select nodesValue
                if frameValue do try (max zoomext sel all) catch()
                setStatus ("Selected Group " + formattedPrint groupIndex format:"02d" + ": " + nodesValue.count as string + " Nodes.")
                true
            )
        )
    )

    fn sceneNameExists nameValue =
    (
        local existsValue = false
        local sceneNodes = collectSceneNodes rootNode #()
        local lowerName = toLower nameValue
        for nodeValue in sceneNodes while not existsValue do
            if toLower (nodeValue.name as string) == lowerName do existsValue = true
        existsValue
    )

    fn temporaryName handleValue saltValue =
    (
        local suffixValue = 0
        local candidateValue = "__LGP_MK1_TEMP_" + saltValue as string + "_" + handleValue as string
        while sceneNameExists candidateValue do
        (
            suffixValue += 1
            candidateValue = "__LGP_MK1_TEMP_" + saltValue as string + "_" + handleValue as string + "_" + suffixValue as string
        )
        candidateValue
    )

    fn renameWorker =
    (
        if not validateGroupNames updateStatuses:true then
        (
            setStatus "Rename blocked: fix Empty, Duplicate, Invalid, Deleted, Unsupported, or Name Collision rows."
            return #(false, 0)
        )

        local handlesValue = #()
        local oldNames = #()
        local finalNames = #()
        for groupValue in groups do
        (
            local orderedHandles = sortedHandles groupValue.handles
            for itemIndex = 1 to orderedHandles.count do
            (
                local nodeValue = nodeFromHandle orderedHandles[itemIndex]
                if nodeValue == undefined do return #(false, 0)
                append handlesValue orderedHandles[itemIndex]
                append oldNames (nodeValue.name as string)
                append finalNames (groupValue.groupName + "_" + formattedPrint itemIndex format:"03d")
            )
        )

        local changedCount = 0
        local successValue = true
        local failureValue = ""
        local saltValue = timeStamp()
        try
        (
            for itemIndex = 1 to handlesValue.count do
            (
                local nodeValue = nodeFromHandle handlesValue[itemIndex]
                nodeValue.name = temporaryName handlesValue[itemIndex] saltValue
            )
            for itemIndex = 1 to handlesValue.count do
            (
                local nodeValue = nodeFromHandle handlesValue[itemIndex]
                nodeValue.name = finalNames[itemIndex]
                if nodeValue.name != finalNames[itemIndex] do throw ("Final name assignment was altered: " + finalNames[itemIndex])
                if oldNames[itemIndex] != finalNames[itemIndex] do changedCount += 1
            )
        )
        catch
        (
            successValue = false
            failureValue = exceptionText()
        )

        if not successValue do
        (
            lgpLog "ERROR" ("Rename failed; restoring original names: " + failureValue)
            try
            (
                saltValue = timeStamp()
                for itemIndex = 1 to handlesValue.count do
                (
                    local nodeValue = nodeFromHandle handlesValue[itemIndex]
                    if nodeValue != undefined do nodeValue.name = temporaryName handlesValue[itemIndex] saltValue
                )
                for itemIndex = 1 to handlesValue.count do
                (
                    local nodeValue = nodeFromHandle handlesValue[itemIndex]
                    if nodeValue != undefined do nodeValue.name = oldNames[itemIndex]
                )
            )
            catch (lgpLog "ERROR" ("Rename rollback also failed: " + exceptionText()))
            changedCount = 0
        )

        for groupValue in groups do
        (
            groupValue.handles = sortedHandles groupValue.handles
            updateInstanceAnalysis groupValue
        )
        #(successValue, changedCount)
    )

    fn captureWorldBounds nodeValue =
    (
        local resultValue = #(undefined, undefined)
        try
        (
            local boundsValue = nodeGetBoundingBox nodeValue (matrix3 1)
            resultValue = #(boundsValue[1], boundsValue[2])
        )
        catch()
        resultValue
    )

    fn captureNodeState nodeValue =
    (
        local boundsValue = captureWorldBounds nodeValue
        LunarGeometryNodeState \
            transformValue:nodeValue.transform positionValue:nodeValue.position rotationValue:nodeValue.rotation scaleValue:nodeValue.scale \
            objectOffsetPosValue:nodeValue.objectOffsetPos objectOffsetRotValue:nodeValue.objectOffsetRot \
            objectOffsetScaleValue:nodeValue.objectOffsetScale pivotValue:nodeValue.pivot parentValue:nodeValue.parent \
            layerValue:nodeValue.layer materialValue:nodeValue.material hiddenValue:nodeValue.isHidden frozenValue:nodeValue.isFrozen \
            visibilityValue:nodeValue.visibility wireColorValue:nodeValue.wireColor boundsMin:boundsValue[1] boundsMax:boundsValue[2] \
            baseObjectValue:nodeValue.baseObject
    )

    fn nodeStatePreserved nodeValue stateValue includeBase:false =
    (
        local equalValue = isValidStoredNode nodeValue
        if equalValue do equalValue = nodeValue.transform == stateValue.transformValue
        if equalValue do equalValue = pointNear nodeValue.position stateValue.positionValue geometryTolerance
        if equalValue do equalValue = nodeValue.rotation == stateValue.rotationValue
        if equalValue do equalValue = pointNear nodeValue.scale stateValue.scaleValue geometryTolerance
        if equalValue do equalValue = pointNear nodeValue.objectOffsetPos stateValue.objectOffsetPosValue geometryTolerance
        if equalValue do equalValue = nodeValue.objectOffsetRot == stateValue.objectOffsetRotValue
        if equalValue do equalValue = pointNear nodeValue.objectOffsetScale stateValue.objectOffsetScaleValue geometryTolerance
        if equalValue do equalValue = pointNear nodeValue.pivot stateValue.pivotValue boundsTolerance
        if equalValue do equalValue = nodeValue.parent == stateValue.parentValue
        if equalValue do equalValue = nodeValue.layer == stateValue.layerValue
        if equalValue do equalValue = nodeValue.material == stateValue.materialValue
        if equalValue do equalValue = nodeValue.isHidden == stateValue.hiddenValue
        if equalValue do equalValue = nodeValue.isFrozen == stateValue.frozenValue
        if equalValue do equalValue = nodeValue.visibility == stateValue.visibilityValue
        if equalValue do equalValue = nodeValue.wireColor == stateValue.wireColorValue
        if equalValue and includeBase do equalValue = nodeValue.baseObject == stateValue.baseObjectValue

        if equalValue do
        (
            local boundsValue = captureWorldBounds nodeValue
            if stateValue.boundsMin != undefined and boundsValue[1] != undefined do
                equalValue = pointNear boundsValue[1] stateValue.boundsMin boundsTolerance and pointNear boundsValue[2] stateValue.boundsMax boundsTolerance
        )
        equalValue
    )

    fn revalidateStrictGroup groupValue =
    (
        local validValue = groupValue.supported and groupValue.signature != undefined
        local baseCache = #()
        local signatureCache = #()
        for handleValue in groupValue.handles while validValue do
        (
            local nodeValue = nodeFromHandle handleValue
            if nodeValue == undefined then validValue = false
            else
            (
                local currentSignature = signatureForNodeCached nodeValue baseCache signatureCache
                if not signaturesStrictEqual groupValue.signature currentSignature do validValue = false
            )
        )
        validValue
    )

    fn makeInstancesWorker =
    (
        local alreadyCount = 0
        local convertedCount = 0
        local skippedCount = 0
        local failedCount = 0

        for groupValue in groups do
        (
            groupValue.instanceUnsafe = false
            updateInstanceAnalysis groupValue
            if not groupValue.supported or not groupValue.stackSafe then
            (
                skippedCount += groupValue.handles.count
                lgpLog "WARN" ("Group " + groupValue.id as string + ": STACK UNSAFE / INSTANCE SKIPPED")
            )
            else if not revalidateStrictGroup groupValue then
            (
                groupValue.instanceUnsafe = true
                skippedCount += groupValue.handles.count
                lgpLog "WARN" ("Group " + groupValue.id as string + ": Strict Geometry revalidation failed; instance skipped.")
            )
            else
            (
                local sourceNode = nodeFromHandle groupValue.instanceSourceHandle
                if sourceNode == undefined then
                (
                    groupValue.instanceUnsafe = true
                    failedCount += groupValue.handles.count
                )
                else
                (
                    local sourceBase = sourceNode.baseObject
                    for handleValue in groupValue.handles do
                    (
                        local targetNode = nodeFromHandle handleValue
                        if targetNode == undefined then
                            failedCount += 1
                        else if targetNode.baseObject == sourceBase then
                            alreadyCount += 1
                        else
                        (
                            local stateValue = captureNodeState targetNode
                            local assignmentAttempted = false
                            local convertedValue = false
                            try
                            (
                                assignmentAttempted = true
                                targetNode.baseObject = sourceBase
                                convertedValue = targetNode.baseObject == sourceBase and nodeStatePreserved targetNode stateValue includeBase:false
                                if not convertedValue do throw "Base Object assignment or preservation verification failed."
                            )
                            catch
                            (
                                local failureValue = exceptionText()
                                if assignmentAttempted do
                                (
                                    try (targetNode.baseObject = stateValue.baseObjectValue) catch (failureValue += " Rollback also failed: " + exceptionText())
                                )
                                convertedValue = false
                                groupValue.instanceUnsafe = true
                                lgpLog "ERROR" (targetNode.name + ": INSTANCE CONVERSION UNSAFE. " + failureValue)
                            )

                            if convertedValue then convertedCount += 1
                            else
                            (
                                failedCount += 1
                                if not nodeStatePreserved targetNode stateValue includeBase:true do
                                    lgpLog "ERROR" (targetNode.name + ": rollback preservation verification failed.")
                            )
                        )
                    )
                )
            )
            updateInstanceAnalysis groupValue
            groupValue.status = analyzeBaseStatus groupValue
        )
        #(alreadyCount, convertedCount, skippedCount, failedCount)
    )

    fn finishOperation renamedValue instanceResult messageValue updateUI:true =
    (
        local alreadyValue = if instanceResult == undefined then 0 else instanceResult[1]
        local convertedValue = if instanceResult == undefined then 0 else instanceResult[2]
        local skippedValue = analyzedSkippedCount + (if instanceResult == undefined then 0 else instanceResult[3])
        local failedValue = if instanceResult == undefined then 0 else instanceResult[4]
        lastSummary = #(groups.count, analyzedValidCount, renamedValue, alreadyValue, convertedValue, skippedValue, failedValue)
        validateGroupNames updateStatuses:true
        if updateUI do
        (
            refreshGrid()
            refreshSummary()
        )
        setStatus messageValue
        redrawViews()
        true
    )

    fn renameAnalyzed updateUI:true =
    (
        if not analysisReady then
        (
            setStatus "Rename stopped: run Analyze first."
            false
        )
        else
        (
            local resultValue = undefined
            undo "Lunar Geometry Preprocessor - Rename" on
            (
                resultValue = renameWorker()
            )
            if resultValue[1] then
            (
                finishOperation resultValue[2] undefined ("Rename complete: " + resultValue[2] as string + " Node names changed. No other Scene state was modified.") updateUI:updateUI
                true
            )
            else
            (
                if updateUI do refreshGrid()
                false
            )
        )
    )

    fn makeInstancesAnalyzed updateUI:true =
    (
        if not analysisReady then
        (
            setStatus "Instance Normalize stopped: run Analyze first."
            false
        )
        else
        (
            local resultValue = undefined
            undo "Lunar Geometry Preprocessor - Make Instances" on
            (
                resultValue = makeInstancesWorker()
            )
            finishOperation 0 resultValue ("Instance Normalize complete. Already: " + resultValue[1] as string +
                ", Converted: " + resultValue[2] as string + ", Skipped: " + resultValue[3] as string +
                ", Failed: " + resultValue[4] as string + ".") updateUI:updateUI
            resultValue[4] == 0
        )
    )

    fn applyAllAnalyzed makeInstancesValue:true updateUI:true =
    (
        if not analysisReady then
        (
            setStatus "Apply All stopped: run Analyze first."
            false
        )
        else if not validateGroupNames updateStatuses:true then
        (
            if updateUI do updateGridStatuses()
            setStatus "Apply All blocked: resolve Group Name validation errors first."
            false
        )
        else
        (
            local renameResult = undefined
            local instanceResult = undefined
            undo "Lunar Geometry Preprocessor" on
            (
                renameResult = renameWorker()
                if renameResult[1] and makeInstancesValue do instanceResult = makeInstancesWorker()
            )
            if not renameResult[1] then
            (
                if updateUI do refreshGrid()
                false
            )
            else
            (
                finishOperation renameResult[2] instanceResult ("Apply All complete. Renamed: " + renameResult[2] as string +
                    (if instanceResult == undefined then ". Instance Normalize was OFF."
                     else ", Converted Instances: " + instanceResult[2] as string + ", Instance Failed: " + instanceResult[4] as string + ".")) updateUI:updateUI
                instanceResult == undefined or instanceResult[4] == 0
            )
        )
    )

    fn setGroupName groupIndex nameValue refresh:true =
    (
        if groupIndex < 1 or groupIndex > groups.count then false
        else
        (
            groups[groupIndex].groupName = nameValue as string
            validateGroupNames updateStatuses:true
            if refresh do refreshGrid()
            true
        )
    )

    fn getGroupData =
    (
        for groupValue in groups collect
        #(
            groupValue.id,
            if groupValue.signature == undefined then 0 else groupValue.signature.numVerts,
            if groupValue.signature == undefined then 0 else groupValue.signature.numFaces,
            groupValue.handles.count,
            nodeNameFromHandle groupValue.representativeHandle,
            groupValue.groupName,
            groupValue.status,
            (for handleValue in groupValue.handles collect handleValue),
            if groupValue.signature == undefined then "" else groupValue.signature.hashValue,
            groupValue.sharedCount,
            groupValue.copyCount
        )
    )

    fn getLastSummary =
    (
        for value in lastSummary collect value
    )

    fn addGridColumn headerValue nameValue widthValue readOnlyValue =
    (
        local columnValue = dotNetObject "System.Windows.Forms.DataGridViewTextBoxColumn"
        columnValue.HeaderText = headerValue
        columnValue.Name = nameValue
        columnValue.Width = widthValue
        columnValue.ReadOnly = readOnlyValue
        columnValue.SortMode = (dotNetClass "System.Windows.Forms.DataGridViewColumnSortMode").NotSortable
        gridGroups.Columns.Add columnValue
    )

    fn initializeGrid =
    (
        gridGroups.AllowUserToAddRows = false
        gridGroups.AllowUserToDeleteRows = false
        gridGroups.AllowUserToResizeRows = false
        gridGroups.AutoGenerateColumns = false
        gridGroups.MultiSelect = false
        gridGroups.ReadOnly = false
        gridGroups.RowHeadersVisible = false
        gridGroups.SelectionMode = (dotNetClass "System.Windows.Forms.DataGridViewSelectionMode").FullRowSelect
        gridGroups.EditMode = (dotNetClass "System.Windows.Forms.DataGridViewEditMode").EditOnEnter
        gridGroups.BackgroundColor = (dotNetClass "System.Drawing.SystemColors").Window
        gridGroups.Columns.Clear()
        addGridColumn "ID" "GroupID" 42 true
        addGridColumn "Verts" "Verts" 72 true
        addGridColumn "Faces" "Faces" 72 true
        addGridColumn "Count" "Count" 58 true
        addGridColumn "Representative" "Representative" 150 true
        addGridColumn "Group Name (edit)" "GroupName" 170 false
        addGridColumn "Status" "Status" 310 true
    )

    on LunarGeometryPreprocessorRollout open do
    (
        initializeGrid()
        setStatus "Ready. Analyze reads selected Geometry only and does not change the Scene."
    )

    on btnAnalyze pressed do analyzeSelection()

    on btnSelectGroup pressed do selectGroupByIndex (selectedGroupIndex()) frameValue:false

    on btnFrameGroup pressed do selectGroupByIndex (selectedGroupIndex()) frameValue:true

    on btnRename pressed do renameAnalyzed updateUI:true

    on btnInstances pressed do makeInstancesAnalyzed updateUI:true

    on btnApplyAll pressed do applyAllAnalyzed makeInstancesValue:chkMakeInstances.checked updateUI:true

    on gridGroups SelectionChanged sender args do
    (
        if not updatingGrid do updateActionAvailability()
    )

    on gridGroups CellEndEdit sender args do
    (
        if not updatingGrid and args.RowIndex >= 0 and args.RowIndex < groups.count and args.ColumnIndex == 5 do
        (
            local cellValue = gridGroups.Rows.Item[args.RowIndex].Cells.Item[5].Value
            groups[args.RowIndex + 1].groupName = if cellValue == undefined then "" else cellValue as string
            validateGroupNames updateStatuses:true
            updateActionAvailability()
        )
    )
)

createDialog LunarGeometryPreprocessorRollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing)
