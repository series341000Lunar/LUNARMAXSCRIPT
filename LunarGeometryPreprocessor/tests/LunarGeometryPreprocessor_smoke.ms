/* Automated smoke/acceptance tests for Lunar Geometry Preprocessor MK1. */

global LGP_TEST_PASSED = 0
global LGP_TEST_FAILED = 0
global LGP_TEST_REPORT = "C:\\tmp\\LunarGeometryPreprocessor-smoke.txt"
global LunarGeometryPreprocessorRollout

fn lgpTestWrite textValue =
(
    local streamValue = openFile LGP_TEST_REPORT mode:"a"
    format "%\n" textValue to:streamValue
    close streamValue
)

fn lgpAssert conditionValue labelValue =
(
    if conditionValue then
    (
        LGP_TEST_PASSED += 1
        lgpTestWrite ("PASS: " + labelValue)
    )
    else
    (
        LGP_TEST_FAILED += 1
        lgpTestWrite ("FAIL: " + labelValue)
    )
)

fn lgpPointNear leftValue rightValue toleranceValue =
(
    distance leftValue rightValue <= toleranceValue
)

fn lgpNodeState nodeValue =
(
    #(
        nodeValue.name,
        nodeValue.transform,
        nodeValue.position,
        nodeValue.rotation,
        nodeValue.scale,
        nodeValue.objectOffsetPos,
        nodeValue.objectOffsetRot,
        nodeValue.objectOffsetScale,
        nodeValue.pivot,
        nodeValue.parent,
        nodeValue.layer,
        nodeValue.material,
        nodeValue.isHidden,
        nodeValue.isFrozen,
        nodeValue.visibility,
        nodeValue.wireColor,
        nodeValue.baseObject
    )
)

fn lgpNodeStateEqual nodeValue stateValue includeName:true includeBase:true =
(
    (not includeName or nodeValue.name == stateValue[1]) and
    nodeValue.transform == stateValue[2] and
    lgpPointNear nodeValue.position stateValue[3] 0.00001 and
    nodeValue.rotation == stateValue[4] and
    lgpPointNear nodeValue.scale stateValue[5] 0.00001 and
    lgpPointNear nodeValue.objectOffsetPos stateValue[6] 0.00001 and
    nodeValue.objectOffsetRot == stateValue[7] and
    lgpPointNear nodeValue.objectOffsetScale stateValue[8] 0.00001 and
    lgpPointNear nodeValue.pivot stateValue[9] 0.001 and
    nodeValue.parent == stateValue[10] and
    nodeValue.layer == stateValue[11] and
    nodeValue.material == stateValue[12] and
    nodeValue.isHidden == stateValue[13] and
    nodeValue.isFrozen == stateValue[14] and
    nodeValue.visibility == stateValue[15] and
    nodeValue.wireColor == stateValue[16] and
    (not includeBase or nodeValue.baseObject == stateValue[17])
)

fn lgpIndependentCopy sourceValue nameValue =
(
    local resultValue = copy sourceValue
    resultValue.name = nameValue
    resultValue.baseObject = copy sourceValue.baseObject
    resultValue
)

fn lgpFindGroupByRepresentative groupData nameValue =
(
    local resultValue = 0
    for groupIndex = 1 to groupData.count while resultValue == 0 do
        if groupData[groupIndex][5] == nameValue do resultValue = groupIndex
    resultValue
)

try (deleteFile LGP_TEST_REPORT) catch()
lgpTestWrite "Lunar Geometry Preprocessor MK1 smoke test"

try
(
    resetMaxFile #noPrompt
    fileIn "C:\\Users\\user\\Documents\\MAXSCRIPT\\LunarGeometryPreprocessor\\src\\LunarGeometryPreprocessor_MK1.ms"
    lgpAssert (LunarGeometryPreprocessorRollout != undefined) "Script loads and rollout exists"

    -- Acceptance A/B/C: strict groups, same-count different Geometry, transform independence.
    matA = standardMaterial name:"LGP_Mat_A" diffuse:[255,0,0]
    matB = standardMaterial name:"LGP_Mat_B" diffuse:[0,0,255]
    houseA1 = box name:"House_001" length:10 width:20 height:30
    houseA3 = lgpIndependentCopy houseA1 "House_003"
    houseA6 = lgpIndependentCopy houseA1 "House_006"
    houseA1.material = matA
    houseA3.material = matB
    houseA3.position = [100,200,30]
    houseA3.rotation = eulerAngles 10 20 73
    houseA3.pivot = houseA3.position + [3,2,1]
    houseA6.position = [-300,50,80]
    houseA6.rotation = eulerAngles -40 5 12
    houseA6.scale = [0.65,0.65,0.65]
    houseA6.wireColor = [20,220,80]

    houseB2 = box name:"House_002" length:12 width:20 height:30
    houseB5 = lgpIndependentCopy houseB2 "House_005"
    houseB5.position = [500,100,20]
    testLayer = LayerManager.newLayerFromName "LGP_Test_Layer"
    testLayer.addNode houseB5
    houseC4 = sphere name:"House_004" radius:18 segs:12
    helperA = point name:"NonGeometry_Helper"
    houseA6.parent = helperA

    sourceNodes = #(houseA1,houseB2,houseA3,houseC4,houseB5,houseA6,helperA)
    sourceStates = for nodeValue in sourceNodes collect lgpNodeState nodeValue
    select sourceNodes
    lgpAssert (LunarGeometryPreprocessorRollout.analyzeNodes sourceNodes updateUI:false) "A Analyze succeeds"
    groupData = LunarGeometryPreprocessorRollout.getGroupData()
    lgpAssert (groupData.count == 3) "A Analyze creates exactly three strict Geometry Groups"
    lgpAssert (groupData[1][4] == 3 and groupData[2][4] == 2 and groupData[3][4] == 1) "A Group membership counts are 3, 2, and 1"
    lgpAssert (groupData[1][9] == groupData[1][9] and groupData[1][9] != groupData[2][9]) "B Same-count different Geometry has different strict hashes"
    lgpAssert (findString groupData[1][7] "SAME COUNT / DIFFERENT GEOMETRY" != undefined and findString groupData[2][7] "SAME COUNT / DIFFERENT GEOMETRY" != undefined) "B Same-count different Geometry is reported"
    lgpAssert (groupData[1][4] == 3) "C position, rotation, and scale do not split identical Geometry"
    local analyzePreserved = true
    for itemIndex = 1 to sourceNodes.count while analyzePreserved do
        if not lgpNodeStateEqual sourceNodes[itemIndex] sourceStates[itemIndex] do analyzePreserved = false
    lgpAssert analyzePreserved "Analyze changes no source state, including Selection-independent node properties"

    -- Acceptance E: explicit Select Group is the only analyze-table selection mutation.
    select helperA
    lgpAssert (LunarGeometryPreprocessorRollout.selectGroupByIndex 2 frameValue:false) "E Select Group command succeeds"
    lgpAssert (selection.count == 2 and (findItem (selection as array) houseB2) > 0 and (findItem (selection as array) houseB5) > 0) "E Select Group selects only its strict Group members"

    -- Suggested duplicate names block apply until the user supplies unique semantic names.
    lgpAssert (not LunarGeometryPreprocessorRollout.renameAnalyzed updateUI:false) "Suggested duplicate Group Names block Rename"
    LunarGeometryPreprocessorRollout.setGroupName 1 "HouseA" refresh:false
    LunarGeometryPreprocessorRollout.setGroupName 2 "HouseB" refresh:false
    LunarGeometryPreprocessorRollout.setGroupName 3 "HouseC" refresh:false

    -- Acceptance I/D: Rename Only changes names, preserving Base Objects and every protected state.
    renameStates = for nodeValue in #(houseA1,houseA3,houseA6,houseB2,houseB5,houseC4) collect lgpNodeState nodeValue
    lgpAssert (LunarGeometryPreprocessorRollout.renameAnalyzed updateUI:false) "D/I Rename Groups succeeds"
    lgpAssert (houseA1.name == "HouseA_001" and houseA3.name == "HouseA_002" and houseA6.name == "HouseA_003") "D Group A receives deterministic 001-003 names"
    lgpAssert (houseB2.name == "HouseB_001" and houseB5.name == "HouseB_002" and houseC4.name == "HouseC_001") "D Groups B/C renumber independently"
    local renamePreserved = true
    renameNodes = #(houseA1,houseA3,houseA6,houseB2,houseB5,houseC4)
    for itemIndex = 1 to renameNodes.count while renamePreserved do
        if not lgpNodeStateEqual renameNodes[itemIndex] renameStates[itemIndex] includeName:false includeBase:true do renamePreserved = false
    lgpAssert renamePreserved "I Rename Only preserves Base Objects and all protected node state"
    groupData = LunarGeometryPreprocessorRollout.getGroupData()
    lgpAssert (groupData[1][5] == "HouseA_001" and groupData[2][5] == "HouseB_001") "Rename refreshes Representative names"

    -- Acceptance F: strict copies become instances while transform/pivot/material remain per node.
    instanceStates = for nodeValue in renameNodes collect lgpNodeState nodeValue
    lgpAssert (LunarGeometryPreprocessorRollout.makeInstancesAnalyzed updateUI:false) "F Instance Normalize completes without failure"
    lgpAssert (houseA1.baseObject == houseA3.baseObject and houseA1.baseObject == houseA6.baseObject) "F Group A shares one Base Object"
    lgpAssert (houseB2.baseObject == houseB5.baseObject) "F Group B shares one Base Object"
    local instancePreserved = true
    for itemIndex = 1 to renameNodes.count while instancePreserved do
        if not lgpNodeStateEqual renameNodes[itemIndex] instanceStates[itemIndex] includeName:true includeBase:false do instancePreserved = false
    lgpAssert instancePreserved "F Transform, pivot, parent, layer, material, visibility, and wire color survive Instance Normalize"

    -- Name Collision: analyzed names may rotate safely, but an external node blocks a final name.
    resetMaxFile #noPrompt
    collisionA = box name:"Raw_001"
    collisionB = lgpIndependentCopy collisionA "Raw_002"
    externalCollision = point name:"Family_001"
    LunarGeometryPreprocessorRollout.analyzeNodes #(collisionA,collisionB) updateUI:false
    LunarGeometryPreprocessorRollout.setGroupName 1 "Family" refresh:false
    lgpAssert (not LunarGeometryPreprocessorRollout.renameAnalyzed updateUI:false and collisionA.name == "Raw_001" and collisionB.name == "Raw_002") "External final Name Collision blocks Rename without changes"

    -- Analyze snapshot survives Selection changes and blocks a deleted source Node.
    resetMaxFile #noPrompt
    deletedA = box name:"Deleted_001"
    deletedB = lgpIndependentCopy deletedA "Deleted_002"
    LunarGeometryPreprocessorRollout.analyzeNodes #(deletedA,deletedB) updateUI:false
    select (point name:"Unrelated_Helper")
    delete deletedB
    LunarGeometryPreprocessorRollout.setGroupName 1 "DeletedFamily" refresh:false
    lgpAssert (not LunarGeometryPreprocessorRollout.renameAnalyzed updateUI:false and deletedA.name == "Deleted_001") "Analyze handle snapshot survives Selection change and deleted Node blocks Rename"
    groupData = LunarGeometryPreprocessorRollout.getGroupData()
    lgpAssert (findString groupData[1][7] "DELETED NODE" != undefined) "Deleted analyzed source is reported as DELETED NODE"

    -- Acceptance G: dominant existing instance set is retained; only two copies convert.
    resetMaxFile #noPrompt
    instancedNodes = #()
    sharedOne = box name:"Tree_001" length:11 width:13 height:17
    append instancedNodes sharedOne
    for itemIndex = 2 to 8 do
    (
        local nodeValue = instance sharedOne
        nodeValue.name = "Tree_" + formattedPrint itemIndex format:"03d"
        nodeValue.position = [itemIndex * 20,0,0]
        append instancedNodes nodeValue
    )
    copyNine = lgpIndependentCopy sharedOne "Tree_009"
    copyTen = lgpIndependentCopy sharedOne "Tree_010"
    append instancedNodes copyNine
    append instancedNodes copyTen
    LunarGeometryPreprocessorRollout.analyzeNodes instancedNodes updateUI:false
    groupData = LunarGeometryPreprocessorRollout.getGroupData()
    lgpAssert (groupData.count == 1 and groupData[1][10] == 8 and groupData[1][11] == 2) "G Analyze reports 8 Shared / 2 Copies"
    lgpAssert (LunarGeometryPreprocessorRollout.makeInstancesAnalyzed updateUI:false) "G Partial Instance normalization succeeds"
    instanceSummary = LunarGeometryPreprocessorRollout.getLastSummary()
    lgpAssert (instanceSummary[4] == 8 and instanceSummary[5] == 2) "G Existing eight instances are retained and only two copies convert"
    local allShared = true
    for nodeValue in instancedNodes while allShared do if nodeValue.baseObject != sharedOne.baseObject do allShared = false
    lgpAssert allShared "G All ten nodes share the original dominant Base Object"

    -- Apply All performs Rename then strict revalidation then Instance in one Undo unit.
    resetMaxFile #noPrompt
    applyA = box name:"Apply_001" length:9 width:14 height:21
    applyB = lgpIndependentCopy applyA "Apply_002"
    applyB.position = [120,30,5]
    oldApplyBaseA = applyA.baseObject
    oldApplyBaseB = applyB.baseObject
    LunarGeometryPreprocessorRollout.analyzeNodes #(applyA,applyB) updateUI:false
    LunarGeometryPreprocessorRollout.setGroupName 1 "ApplyFamily" refresh:false
    lgpAssert (LunarGeometryPreprocessorRollout.applyAllAnalyzed makeInstancesValue:true updateUI:false) "Apply All completes Rename and Instance Normalize"
    lgpAssert (applyA.name == "ApplyFamily_001" and applyB.name == "ApplyFamily_002" and applyA.baseObject == applyB.baseObject) "Apply All order produces final names and shared Base Object"
    max undo
    lgpAssert (applyA.name == "Apply_001" and applyB.name == "Apply_002" and applyA.baseObject == oldApplyBaseA and applyB.baseObject == oldApplyBaseB) "One Undo restores both Apply All Rename and Base Object relationships"

    -- Acceptance J: a modifier stack is classified but conservatively skipped for Instance Normalize.
    resetMaxFile #noPrompt
    unsafeA = box name:"Unsafe_001" length:10 width:20 height:30
    unsafeB = lgpIndependentCopy unsafeA "Unsafe_002"
    addModifier unsafeA (Bend angle:0)
    addModifier unsafeB (Bend angle:0)
    oldUnsafeBaseA = unsafeA.baseObject
    oldUnsafeBaseB = unsafeB.baseObject
    LunarGeometryPreprocessorRollout.analyzeNodes #(unsafeA,unsafeB) updateUI:false
    groupData = LunarGeometryPreprocessorRollout.getGroupData()
    lgpAssert (groupData.count == 1 and findString groupData[1][7] "STACK UNSAFE" != undefined) "J Modifier stack is reported STACK UNSAFE"
    lgpAssert (LunarGeometryPreprocessorRollout.makeInstancesAnalyzed updateUI:false and unsafeA.baseObject == oldUnsafeBaseA and unsafeB.baseObject == oldUnsafeBaseB) "J Unsafe Instance is skipped while source Base Objects remain unchanged"

    -- Large test: 520 nodes, 40 strict Groups, repeated Base Objects use the cache.
    resetMaxFile #noPrompt
    bulkNodes = #()
    for groupIndex = 1 to 40 do
    (
        local familyValue = "Bulk" + formattedPrint groupIndex format:"02d"
        local sourceValue = box name:(familyValue + "_001") length:(10.0 + groupIndex) width:(20.0 + groupIndex * 0.37) height:(30.0 + groupIndex * 0.19)
        append bulkNodes sourceValue
        for itemIndex = 2 to 13 do
        (
            local nodeValue = instance sourceValue
            nodeValue.name = familyValue + "_" + formattedPrint itemIndex format:"03d"
            nodeValue.position = [groupIndex * 300, itemIndex * 35, groupIndex * 2]
            nodeValue.rotation = eulerAngles 0 0 ((groupIndex * 11 + itemIndex * 7) as float)
            append bulkNodes nodeValue
        )
    )
    local bulkStart = timeStamp()
    lgpAssert (LunarGeometryPreprocessorRollout.analyzeNodes bulkNodes updateUI:false) "Large Analyze succeeds for 520 Nodes"
    local bulkElapsed = timeStamp() - bulkStart
    groupData = LunarGeometryPreprocessorRollout.getGroupData()
    lgpAssert (groupData.count == 40) "Large Analyze creates exactly 40 strict Geometry Groups"
    local bulkCountsValid = true
    for groupValue in groupData while bulkCountsValid do if groupValue[4] != 13 do bulkCountsValid = false
    lgpAssert bulkCountsValid "Large Analyze retains 13 Nodes in every Group"
    lgpTestWrite ("INFO: Large Analyze 520 Nodes / 40 Groups elapsed ticks: " + bulkElapsed as string)
)
catch
(
    LGP_TEST_FAILED += 1
    lgpTestWrite ("FATAL: " + getCurrentException() as string)
)

lgpTestWrite ("Passed: " + LGP_TEST_PASSED as string)
lgpTestWrite ("Failed: " + LGP_TEST_FAILED as string)
quitMax #noPrompt
