/* Automated smoke/acceptance tests for Lunar -> tyFlow Placement MK1. */

global LTP_TEST_PASSED = 0
global LTP_TEST_FAILED = 0
global LTP_TEST_REPORT = "C:\\tmp\\LunarTyFlowPlacement-smoke.txt"
global LunarTyFlowPlacementRollout

fn ltpTestWrite textValue =
(
    local streamValue = openFile LTP_TEST_REPORT mode:"a"
    format "%\n" textValue to:streamValue
    close streamValue
)

fn ltpAssert conditionValue labelValue =
(
    if conditionValue then
    (
        LTP_TEST_PASSED += 1
        ltpTestWrite ("PASS: " + labelValue)
    )
    else
    (
        LTP_TEST_FAILED += 1
        ltpTestWrite ("FAIL: " + labelValue)
    )
)

fn ltpFindFamily familyData familyNameValue =
(
    local resultValue = undefined
    for rowValue in familyData while resultValue == undefined do
        if rowValue[1] == familyNameValue do resultValue = rowValue
    resultValue
)

fn ltpFindEvent flowValue eventNameValue =
(
    local resultValue = undefined
    try (resultValue = getProperty flowValue (eventNameValue as name)) catch (resultValue = undefined)
    if resultValue != undefined and (classOf resultValue as string) != "tyEvent" do resultValue = undefined
    resultValue
)

fn ltpFindOperator eventValue requiredProperty =
(
    local resultValue = undefined
    local indexValue = 1
    local continueValue = true
    while continueValue and indexValue <= 128 do
    (
        local operatorValue = undefined
        try
        (
            local subAnimValue = eventValue[indexValue]
            if subAnimValue != undefined do operatorValue = subAnimValue.object
        )
        catch (operatorValue = undefined)

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

fn ltpNodeArrayEquals leftValues rightValues =
(
    local equalValue = leftValues.count == rightValues.count
    if equalValue do
    (
        for indexValue = 1 to leftValues.count while equalValue do
            if leftValues[indexValue] != rightValues[indexValue] do equalValue = false
    )
    equalValue
)

fn ltpSourceState nodeValue =
(
    #(
        nodeValue.transform,
        nodeValue.position,
        nodeValue.rotation,
        nodeValue.scale,
        nodeValue.objectOffsetPos,
        nodeValue.objectOffsetRot,
        nodeValue.objectOffsetScale,
        nodeValue.isHidden,
        nodeValue.isFrozen,
        nodeValue.visibility,
        nodeValue.baseObject,
        nodeValue.parent
    )
)

fn ltpSourceStateEqual nodeValue stateValue =
(
    nodeValue.transform == stateValue[1] and
    nodeValue.position == stateValue[2] and
    nodeValue.rotation == stateValue[3] and
    nodeValue.scale == stateValue[4] and
    nodeValue.objectOffsetPos == stateValue[5] and
    nodeValue.objectOffsetRot == stateValue[6] and
    nodeValue.objectOffsetScale == stateValue[7] and
    nodeValue.isHidden == stateValue[8] and
    nodeValue.isFrozen == stateValue[9] and
    nodeValue.visibility == stateValue[10] and
    nodeValue.baseObject == stateValue[11] and
    nodeValue.parent == stateValue[12]
)

fn ltpPointNear leftValue rightValue toleranceValue =
(
    distance leftValue rightValue <= toleranceValue
)

fn ltpMatrixNear leftValue rightValue toleranceValue =
(
    ltpPointNear leftValue.row1 rightValue.row1 toleranceValue and
    ltpPointNear leftValue.row2 rightValue.row2 toleranceValue and
    ltpPointNear leftValue.row3 rightValue.row3 toleranceValue and
    ltpPointNear leftValue.row4 rightValue.row4 toleranceValue
)

try (deleteFile LTP_TEST_REPORT) catch()
ltpTestWrite "Lunar -> tyFlow Placement MK1 smoke test"

try
(
    resetMaxFile #noPrompt
    fileIn "C:\\Users\\user\\Documents\\MAXSCRIPT\\LunarTyFlowPlacement\\src\\LunarTyFlowPlacement_MK1.ms"
    ltpAssert (LunarTyFlowPlacementRollout != undefined) "Script loads and rollout exists"

    -- Acceptance A / C / E: one name Family, instance relationship ignored, source state preserved.
    targetA = tyFlow name:"TYC_A"
    manualEventA = targetA.addEvent()
    manualEventA.setName "Simulation"
    manualOpA = manualEventA.addOperator "Birth Objects" -1
    manualOpA.objectsInheritGeometry = true

    cupA1 = box name:"Cup_001" length:11 width:13 height:17
    cupA2 = copy cupA1
    cupA2.name = "Cup_002"
    cupA3 = sphere name:"Cup_003" radius:9 segments:12
    cupA4 = box name:"Cup_004" length:7 width:8 height:9
    cupA1.transform = (matrix3 [1.2,0,0] [0,0.9,0] [0,0,1.4] [11,22,33])
    cupA2.pos = [-15,7,91]
    cupA3.rotation = (angleaxis 37 [0,0,1])
    scale cupA4 [1.1,1.3,0.7]
    cupAStates = for nodeValue in #(cupA1,cupA2,cupA3,cupA4) collect ltpSourceState nodeValue

    LunarTyFlowPlacementRollout.setTargetNode targetA
    LunarTyFlowPlacementRollout.setIgnoreInstanceRelationship true refresh:false
    LunarTyFlowPlacementRollout.setUpdateExisting true refresh:false
    ltpAssert (LunarTyFlowPlacementRollout.analyzeNodes #(cupA1,cupA2,cupA3,cupA4,targetA) updateUI:false) "A Analyze succeeds with target mixed into input"
    familyDataA = LunarTyFlowPlacementRollout.getFamilyData()
    cupFamilyA = ltpFindFamily familyDataA "Cup"
    ltpAssert (familyDataA.count == 1 and cupFamilyA != undefined and cupFamilyA[2] == 4) "A Cup family count is 4"
    ltpAssert (cupFamilyA[3] == "Cup_001" and findString cupFamilyA[4] "INSTANCE IGNORED" != undefined) "A Shape Source is first Node and instance validation is ignored"
    ltpAssert (LunarTyFlowPlacementRollout.buildAnalyzed updateUI:false) "A Build succeeds"

    eventCupA = ltpFindEvent targetA "LUNAR_Cup"
    birthCupA = ltpFindOperator eventCupA #objectList
    shapeCupA = ltpFindOperator eventCupA #instancedGeo_tab
    meshCupA = ltpFindOperator eventCupA #meshType
    displayCupA = ltpFindOperator eventCupA #displayMode
    ltpAssert (eventCupA != undefined and birthCupA != undefined and shapeCupA != undefined and meshCupA != undefined and displayCupA != undefined) "A LUNAR_Cup contains Birth Objects Shape Mesh and Display"
    ltpAssert (eventCupA[1].object == birthCupA and eventCupA[2].object == shapeCupA and eventCupA[3].object == meshCupA and eventCupA[4].object == displayCupA) "A Operators are ordered Birth Objects Shape Mesh Display"
    ltpAssert (ltpNodeArrayEquals birthCupA.objectList #(cupA1,cupA2,cupA3,cupA4)) "A Birth Objects source list is exact and ordered"
    ltpAssert (birthCupA.objectsInheritGeometry == false and birthCupA.objectsCenterPivots == false) "A Geometry inheritance and Center All Pivots are OFF"
    ltpAssert (birthCupA.inheritPosition and birthCupA.inheritRotation and birthCupA.inheritScale) "A Position Rotation Scale inheritance is ON"
    ltpAssert (shapeCupA.shapeMode == 2 and shapeCupA.referenceNode == cupA1) "A Shape uses Cup_001 Reference Object"
    ltpAssert (shapeCupA.meshCenterPivots_tab.count == 1 and shapeCupA.meshCenterPivots_tab[1] == false) "A Shape Center Pivot is OFF"
    ltpAssert (shapeCupA.scale_tab.count == 1 and shapeCupA.scale_tab[1] == false) "A Shape scale override is OFF"
    ltpAssert (meshCupA.meshType == 0 and meshCupA.renderOnly == true) "A Mesh is TriMesh Render Only"
    ltpAssert (displayCupA.displayMode == 4) "A Display is Geometry"

    targetA.reset_simulation()
    targetA.updateParticles 0
    particleTMsA = targetA.getAllParticleTMs()
    particlePositionsA = targetA.getAllParticlePositions()
    particleScalesA = targetA.getAllParticleScales()
    particleMeshesA = targetA.getAllParticleShapeMeshes()
    sourceNodesA = #(cupA1,cupA2,cupA3,cupA4)
    particleTransformsMatchA = particleTMsA.count == 4 and particlePositionsA.count == 4 and particleScalesA.count == 4
    if particleTransformsMatchA do
    (
        for indexValue = 1 to 4 while particleTransformsMatchA do
        (
            if not ltpMatrixNear particleTMsA[indexValue] sourceNodesA[indexValue].transform 0.001 do particleTransformsMatchA = false
            if not ltpPointNear particlePositionsA[indexValue] sourceNodesA[indexValue].position 0.001 do particleTransformsMatchA = false
            if not ltpPointNear particleScalesA[indexValue] sourceNodesA[indexValue].scale 0.001 do particleTransformsMatchA = false
        )
    )
    ltpAssert particleTransformsMatchA "A Runtime particles reproduce Source Position Rotation Scale"

    sourceShapeMeshA = snapshotAsMesh cupA1
    particleShapesMatchA = particleMeshesA.count == 4
    if particleShapesMatchA do
    (
        for meshValue in particleMeshesA while particleShapesMatchA do
            if meshValue == undefined or getNumVerts meshValue != getNumVerts sourceShapeMeshA or getNumFaces meshValue != getNumFaces sourceShapeMeshA do particleShapesMatchA = false
    )
    ltpAssert particleShapesMatchA "A Runtime particles all use the Family Shape Source geometry"

    sourcesAUnchanged = true
    for indexValue = 1 to 4 while sourcesAUnchanged do
        if not ltpSourceStateEqual #(cupA1,cupA2,cupA3,cupA4)[indexValue] cupAStates[indexValue] do sourcesAUnchanged = false
    ltpAssert sourcesAUnchanged "E Source transforms pivots visibility base objects and parents are unchanged"
    ltpAssert (ltpFindEvent targetA "Simulation" == manualEventA and manualOpA.objectsInheritGeometry == true) "F Existing non-LUNAR Event and Operator are untouched"

    -- Acceptance G: update one existing Event, then skip it when Update is OFF.
    meshCupA.meshType = 1
    meshCupA.renderOnly = false
    displayCupA.displayMode = 0
    cupA5 = cone name:"Cup_005" radius1:5 radius2:2 height:12
    LunarTyFlowPlacementRollout.analyzeNodes #(cupA1,cupA2,cupA3,cupA4,cupA5) updateUI:false
    ltpAssert (LunarTyFlowPlacementRollout.buildAnalyzed updateUI:false) "G Update build succeeds"
    eventCupAAfterUpdate = ltpFindEvent targetA "LUNAR_Cup"
    birthCupAAfterUpdate = ltpFindOperator eventCupAAfterUpdate #objectList
    meshCupAAfterUpdate = ltpFindOperator eventCupAAfterUpdate #meshType
    displayCupAAfterUpdate = ltpFindOperator eventCupAAfterUpdate #displayMode
    summaryUpdateA = LunarTyFlowPlacementRollout.getLastBuildSummary()
    ltpAssert (eventCupAAfterUpdate == eventCupA and birthCupAAfterUpdate.objectList.count == 5) "G Re-run updates the same LUNAR_Cup Event"
    ltpAssert (meshCupAAfterUpdate == meshCupA and meshCupAAfterUpdate.meshType == 0 and meshCupAAfterUpdate.renderOnly == true and displayCupAAfterUpdate == displayCupA and displayCupAAfterUpdate.displayMode == 4) "G Update restores Mesh TriMesh Render and Display Geometry"
    ltpAssert (summaryUpdateA[1] == 0 and summaryUpdateA[2] == 1) "G Update summary reports one updated Event"

    LunarTyFlowPlacementRollout.setUpdateExisting false refresh:false
    LunarTyFlowPlacementRollout.analyzeNodes #(cupA1,cupA2,cupA3,cupA4,cupA5) updateUI:false
    ltpAssert (findString (ltpFindFamily (LunarTyFlowPlacementRollout.getFamilyData()) "Cup")[4] "ALREADY EXISTS" != undefined) "G Update OFF marks ALREADY EXISTS"
    ltpAssert (LunarTyFlowPlacementRollout.buildAnalyzed updateUI:false) "G Update OFF completes safely"
    summarySkipA = LunarTyFlowPlacementRollout.getLastBuildSummary()
    ltpAssert (summarySkipA[1] == 0 and summarySkipA[2] == 0 and summarySkipA[3] == 1) "G Update OFF skips without duplication"

    -- Acceptance B: multiple Families create separate Events.
    resetMaxFile #noPrompt
    targetB = tyFlow name:"TYC_B"
    cupB1 = box name:"Cup_001"
    cupB2 = copy cupB1
    cupB2.name = "Cup_002"
    jarB1 = cylinder name:"Jar_001"
    jarB2 = copy jarB1
    jarB2.name = "Jar_002"
    jarB3 = copy jarB1
    jarB3.name = "Jar_003"
    petB1 = sphere name:"PetBottle_001"
    petB2 = copy petB1
    petB2.name = "PetBottle_002"
    petB3 = copy petB1
    petB3.name = "PetBottle_003"
    petB4 = copy petB1
    petB4.name = "PetBottle_004"
    LunarTyFlowPlacementRollout.setTargetNode targetB
    LunarTyFlowPlacementRollout.setIgnoreInstanceRelationship true refresh:false
    LunarTyFlowPlacementRollout.setUpdateExisting true refresh:false
    multiNodesB = #(cupB1,cupB2,jarB1,jarB2,jarB3,petB1,petB2,petB3,petB4)
    LunarTyFlowPlacementRollout.analyzeNodes multiNodesB updateUI:false
    ltpAssert ((LunarTyFlowPlacementRollout.getFamilyData()).count == 3) "B Analyze finds three Families"
    ltpAssert (LunarTyFlowPlacementRollout.buildAnalyzed updateUI:false) "B Multi Family Build succeeds"
    summaryB = LunarTyFlowPlacementRollout.getLastBuildSummary()
    ltpAssert (summaryB[1] == 3 and ltpFindEvent targetB "LUNAR_Cup" != undefined and ltpFindEvent targetB "LUNAR_Jar" != undefined and ltpFindEvent targetB "LUNAR_PetBottle" != undefined) "B Three LUNAR Events are created"

    -- Naming convention: remove only the final _digits suffix.
    resetMaxFile #noPrompt
    targetN = tyFlow name:"TYC_Naming"
    smallN = box name:"Small_Pot_002"
    kettleN = box name:"Kettle001"
    pointN = box name:"Point001"
    b52N = box name:"B52"
    LunarTyFlowPlacementRollout.setTargetNode targetN
    LunarTyFlowPlacementRollout.setIgnoreInstanceRelationship true refresh:false
    LunarTyFlowPlacementRollout.analyzeNodes #(smallN,kettleN,pointN,b52N) updateUI:false
    familyDataN = LunarTyFlowPlacementRollout.getFamilyData()
    ltpAssert (ltpFindFamily familyDataN "Small_Pot" != undefined) "Naming keeps intermediate underscores"
    ltpAssert (ltpFindFamily familyDataN "Kettle001" != undefined and ltpFindFamily familyDataN "Point001" != undefined and ltpFindFamily familyDataN "B52" != undefined) "Naming does not guess suffixes without underscore digits"
    ltpAssert ((ltpFindFamily familyDataN "Kettle001")[6] == false and findString (ltpFindFamily familyDataN "Kettle001")[4] "NONSTANDARD NAME" != undefined) "Nonstandard name is an independent warning Family"

    -- Acceptance D: shared Base Object validation skips mismatched Family only.
    resetMaxFile #noPrompt
    targetD = tyFlow name:"TYC_D"
    cupD1 = box name:"Cup_001"
    cupD2 = instance cupD1
    cupD2.name = "Cup_002"
    cupD3 = sphere name:"Cup_003"
    jarD1 = cylinder name:"Jar_001"
    jarD2 = instance jarD1
    jarD2.name = "Jar_002"
    LunarTyFlowPlacementRollout.setTargetNode targetD
    LunarTyFlowPlacementRollout.setIgnoreInstanceRelationship false refresh:false
    LunarTyFlowPlacementRollout.setUpdateExisting true refresh:false
    LunarTyFlowPlacementRollout.analyzeNodes #(cupD1,cupD2,cupD3,jarD1,jarD2) updateUI:false
    familyDataD = LunarTyFlowPlacementRollout.getFamilyData()
    cupFamilyD = ltpFindFamily familyDataD "Cup"
    jarFamilyD = ltpFindFamily familyDataD "Jar"
    ltpAssert (findString cupFamilyD[4] "INSTANCE / GEOMETRY MISMATCH" != undefined and cupFamilyD[5] == false) "D Mismatched Cup Family is a non-buildable conflict"
    ltpAssert (findString jarFamilyD[4] "SHARED BASE OBJECT" != undefined and jarFamilyD[5] == true) "D Shared-base Jar Family is ready"
    ltpAssert (LunarTyFlowPlacementRollout.buildAnalyzed updateUI:false) "D Build continues for other valid Families"
    summaryD = LunarTyFlowPlacementRollout.getLastBuildSummary()
    ltpAssert (summaryD[1] == 1 and summaryD[3] == 1 and ltpFindEvent targetD "LUNAR_Cup" == undefined and ltpFindEvent targetD "LUNAR_Jar" != undefined) "D Cup is skipped while Jar is created"

    -- Deleted Shape Source is skipped, and missing Target blocks Build.
    resetMaxFile #noPrompt
    targetX = tyFlow name:"TYC_X"
    delX1 = box name:"Deleted_001"
    delX2 = box name:"Deleted_002"
    LunarTyFlowPlacementRollout.setTargetNode targetX
    LunarTyFlowPlacementRollout.setIgnoreInstanceRelationship true refresh:false
    LunarTyFlowPlacementRollout.analyzeNodes #(delX1,delX2) updateUI:false
    delete delX1
    ltpAssert (LunarTyFlowPlacementRollout.buildAnalyzed updateUI:false) "Deleted Shape Source is skipped without a script failure"
    deletedSummaryX = LunarTyFlowPlacementRollout.getLastBuildSummary()
    ltpAssert (deletedSummaryX[3] == 1 and ltpFindEvent targetX "LUNAR_Deleted" == undefined) "Deleted Shape Source creates no Event"
    LunarTyFlowPlacementRollout.clearTargetNode()
    ltpAssert (not LunarTyFlowPlacementRollout.buildAnalyzed updateUI:false) "Missing Target tyFlow blocks Build"
)
catch
(
    LTP_TEST_FAILED += 1
    ltpTestWrite ("FATAL: " + getCurrentException() as string)
)

ltpTestWrite ("Passed: " + LTP_TEST_PASSED as string)
ltpTestWrite ("Failed: " + LTP_TEST_FAILED as string)
quitMax #noPrompt
