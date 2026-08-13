/* Automated smoke/acceptance tests for Lunar Material ID Normalizer. */

global LMN_TEST_PASSED = 0
global LMN_TEST_FAILED = 0
global LMN_TEST_REPORT = "C:\\tmp\\lmn-smoke-report.txt"
global LunarMaterialIDNormalizerRollout

fn lmnTestWrite textValue =
(
    local stream = openFile LMN_TEST_REPORT mode:"a"
    format "%\n" textValue to:stream
    close stream
)

fn lmnAssert condition label =
(
    if condition then
    (
        LMN_TEST_PASSED += 1
        lmnTestWrite ("PASS: " + label)
    )
    else
    (
        LMN_TEST_FAILED += 1
        lmnTestWrite ("FAIL: " + label)
    )
)

fn lmnMakeMulti materialNames materialIDs =
(
    local result = multimaterial numsubs:materialNames.count
    for indexValue = 1 to materialNames.count do
    (
        local subMaterial = standardMaterial name:materialNames[indexValue]
        result.materialList[indexValue] = subMaterial
        result.materialIDList[indexValue] = materialIDs[indexValue]
        result.names[indexValue] = materialNames[indexValue]
        result.mapEnabled[indexValue] = true
    )
    result
)

fn lmnMakePoly nodeName materialValue faceIDs =
(
    local nodeValue = box name:nodeName
    convertToPoly nodeValue
    nodeValue.material = materialValue
    for faceIndex = 1 to (amin faceIDs.count (polyop.getNumFaces nodeValue)) do
        polyop.setFaceMatID nodeValue #{faceIndex} faceIDs[faceIndex]
    nodeValue
)

fn lmnFaceIDs nodeValue =
(
    for faceIndex = 1 to polyop.getNumFaces nodeValue collect polyop.getFaceMatID nodeValue faceIndex
)

fn lmnFindMaterialSlot materialValue materialName =
(
    local foundIndex = 0
    for indexValue = 1 to materialValue.materialList.count while foundIndex == 0 do
    (
        local subMaterial = materialValue.materialList[indexValue]
        if subMaterial != undefined and subMaterial.name == materialName do foundIndex = indexValue
    )
    foundIndex
)

fn lmnArrayEquals leftValues rightValues =
(
    local equalValues = leftValues.count == rightValues.count
    if equalValues do
    (
        for indexValue = 1 to leftValues.count while equalValues do
            if leftValues[indexValue] != rightValues[indexValue] do equalValues = false
    )
    equalValues
)

fn lmnPointArraysEqual leftValues rightValues =
(
    local equalValues = leftValues.count == rightValues.count
    if equalValues do
    (
        for indexValue = 1 to leftValues.count while equalValues do
            if distance leftValues[indexValue] rightValues[indexValue] > 0.0001 do equalValues = false
    )
    equalValues
)

fn lmnPrepare masterValue targetValues =
(
    LunarMaterialIDNormalizerRollout.clearTargetNodes()
    LunarMaterialIDNormalizerRollout.setMasterNode masterValue
    LunarMaterialIDNormalizerRollout.addTargetNodes targetValues
)

try (deleteFile LMN_TEST_REPORT) catch()
lmnTestWrite "Lunar Material ID Normalizer smoke test"

try
(
    resetMaxFile #noPrompt
    fileIn "C:\\Users\\user\\Documents\\MAXSCRIPT\\LunarMaterialIDNormalizer\\src\\LunarMaterialIDNormalizer.ms"
    lmnAssert (LunarMaterialIDNormalizerRollout != undefined) "Script loads and rollout exists"

    -- Test A: same materials, different order.
    masterMatA = lmnMakeMulti #("A", "B", "C") #(1, 2, 3)
    targetMatA = lmnMakeMulti #("C", "A", "B") #(1, 2, 3)
    masterA = lmnMakePoly "Master_A" masterMatA #(1,1,2,2,3,3)
    targetA = lmnMakePoly "Target_A" targetMatA #(1,1,2,2,3,3)
    oldTargetAMaterial = targetA.material
    oldTargetAFaces = lmnFaceIDs targetA
    lmnPrepare masterA #(targetA)
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "A Analyze succeeds"
    lmnAssert (targetA.material == oldTargetAMaterial and lmnArrayEquals (lmnFaceIDs targetA) oldTargetAFaces) "A Analyze does not change scene"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "A Apply succeeds"
    lmnAssert (targetA.material == masterA.material) "A Target shares Master material"
    lmnAssert (lmnArrayEquals (lmnFaceIDs targetA) #(3,3,1,1,2,2)) "A Face IDs remap by exact material name"

    -- Test B: one new material appends using the actual Target reference.
    masterMatB = lmnMakeMulti #("A", "B", "C") #(1, 2, 3)
    targetMatB = lmnMakeMulti #("A", "D", "C") #(1, 2, 3)
    sourceDRefB = targetMatB.materialList[2]
    masterB = lmnMakePoly "Master_B" masterMatB #(1,1,2,2,3,3)
    targetB = lmnMakePoly "Target_B" targetMatB #(1,2,2,3,3,1)
    lmnPrepare masterB #(targetB)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "B Apply succeeds"
    slotDB = lmnFindMaterialSlot masterB.material "D"
    lmnAssert (slotDB > 0 and masterB.material.materialIDList[slotDB] == 4) "B D appends as ID 4"
    lmnAssert (masterB.material.materialList[slotDB] == sourceDRefB) "B Appended material preserves Target reference"
    lmnAssert (lmnArrayEquals (lmnFaceIDs targetB) #(1,4,4,3,3,1)) "B D faces remap to ID 4"

    -- Test C: repeated new name across Targets appends once.
    masterMatC = lmnMakeMulti #("A", "B", "C") #(1, 2, 3)
    targetMatC1 = lmnMakeMulti #("D") #(7)
    targetMatC2 = lmnMakeMulti #("D") #(2)
    firstDRefC = targetMatC1.materialList[1]
    masterC = lmnMakePoly "Master_C" masterMatC #(1,1,2,2,3,3)
    targetC1 = lmnMakePoly "Target_C1" targetMatC1 #(7,7,7,7,7,7)
    targetC2 = lmnMakePoly "Target_C2" targetMatC2 #(2,2,2,2,2,2)
    lmnPrepare masterC #(targetC1, targetC2)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "C Apply succeeds"
    dNameCountC = 0
    for subMaterial in masterC.material.materialList where subMaterial != undefined and subMaterial.name == "D" do dNameCountC += 1
    slotDC = lmnFindMaterialSlot masterC.material "D"
    lmnAssert (dNameCountC == 1) "C D appends once"
    lmnAssert (masterC.material.materialList[slotDC] == firstDRefC) "C First D reference becomes canonical"
    lmnAssert (lmnArrayEquals (lmnFaceIDs targetC1) #(4,4,4,4,4,4) and lmnArrayEquals (lmnFaceIDs targetC2) #(4,4,4,4,4,4)) "C Both Targets use the same D ID"

    -- Test D: sparse Master IDs remain unchanged; new material uses max + 1.
    masterMatD = lmnMakeMulti #("A", "B", "C") #(1, 4, 8)
    targetMatD = lmnMakeMulti #("D") #(2)
    masterD = lmnMakePoly "Master_D" masterMatD #(1,1,4,4,8,8)
    targetD = lmnMakePoly "Target_D" targetMatD #(2,2,2,2,2,2)
    lmnPrepare masterD #(targetD)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "D Apply succeeds"
    slotDD = lmnFindMaterialSlot masterD.material "D"
    lmnAssert (masterD.material.materialIDList[1] == 1 and masterD.material.materialIDList[2] == 4 and masterD.material.materialIDList[3] == 8) "D Existing sparse IDs stay unchanged"
    lmnAssert (masterD.material.materialIDList[slotDD] == 9 and lmnArrayEquals (lmnFaceIDs targetD) #(9,9,9,9,9,9)) "D New ID is max plus one"

    -- Test E: duplicate Master material name blocks Apply.
    masterMatE = lmnMakeMulti #("A", "A") #(1, 5)
    targetMatE = lmnMakeMulti #("A") #(2)
    masterE = lmnMakePoly "Master_E" masterMatE #(1,1,5,5,1,5)
    targetE = lmnMakePoly "Target_E" targetMatE #(2,2,2,2,2,2)
    oldFacesE = lmnFaceIDs targetE
    oldMaterialE = targetE.material
    lmnPrepare masterE #(targetE)
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "E Duplicate Master name blocks Analyze readiness"
    lmnAssert (not LunarMaterialIDNormalizerRollout.applyNormalization()) "E Duplicate Master name blocks Apply"
    lmnAssert (targetE.material == oldMaterialE and lmnArrayEquals (lmnFaceIDs targetE) oldFacesE) "E Blocked Apply leaves Target unchanged"

    -- Test F: no-material Target skips while another Target succeeds.
    masterMatF = lmnMakeMulti #("A", "B") #(1, 2)
    validMatF = lmnMakeMulti #("B", "A") #(1, 2)
    masterF = lmnMakePoly "Master_F" masterMatF #(1,1,1,2,2,2)
    noMaterialF = lmnMakePoly "No_Material_F" undefined #(1,1,1,1,1,1)
    validF = lmnMakePoly "Valid_F" validMatF #(1,1,1,2,2,2)
    lmnPrepare masterF #(noMaterialF, validF)
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "F Analyze permits skipped no-material Target"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "F Valid Target applies while no-material Target skips"
    lmnAssert (noMaterialF.material == undefined) "F No-material Target remains unchanged"
    lmnAssert (validF.material == masterF.material and lmnArrayEquals (lmnFaceIDs validF) #(2,2,2,1,1,1)) "F Remaining Target normalizes"

    -- Single material Target support.
    masterMatG = lmnMakeMulti #("Concrete") #(5)
    singleMatG = standardMaterial name:"Concrete"
    masterG = lmnMakePoly "Master_G" masterMatG #(5,5,5,5,5,5)
    targetG = lmnMakePoly "Target_G" singleMatG #(1,2,3,4,5,6)
    lmnPrepare masterG #(targetG)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "G Single-material Target applies"
    lmnAssert (targetG.material == masterG.material and lmnArrayEquals (lmnFaceIDs targetG) #(5,5,5,5,5,5)) "G All single-material Target faces use Master ID"

    -- Exact matching is case-sensitive.
    masterMatH = lmnMakeMulti #("Concrete") #(1)
    targetMatH = lmnMakeMulti #("concrete") #(7)
    lowerConcreteRefH = targetMatH.materialList[1]
    masterH = lmnMakePoly "Master_H" masterMatH #(1,1,1,1,1,1)
    targetH = lmnMakePoly "Target_H" targetMatH #(7,7,7,7,7,7)
    lmnPrepare masterH #(targetH)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "H Case-sensitive Apply succeeds"
    slotLowerH = lmnFindMaterialSlot masterH.material "concrete"
    lmnAssert (slotLowerH > 0 and masterH.material.materialIDList[slotLowerH] == 2 and masterH.material.materialList[slotLowerH] == lowerConcreteRefH) "H Different case appends as a distinct material"

    -- Repeated Target name on different old IDs is allowed and merged.
    masterMatI = lmnMakeMulti #("A") #(10)
    targetMatI = lmnMakeMulti #("A", "A") #(2, 7)
    masterI = lmnMakePoly "Master_I" masterMatI #(10,10,10,10,10,10)
    targetI = lmnMakePoly "Target_I" targetMatI #(2,2,2,7,7,7)
    lmnPrepare masterI #(targetI)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "I Repeated Target name Apply succeeds"
    lmnAssert (lmnArrayEquals (lmnFaceIDs targetI) #(10,10,10,10,10,10)) "I Different old IDs with the same Target name merge to one Master ID"

    -- Modifier stack, transform, pivot, topology, name, and base-object vertex positions stay intact.
    masterMatJ = lmnMakeMulti #("A", "B") #(1, 2)
    targetMatJ = lmnMakeMulti #("B", "A") #(1, 2)
    masterJ = lmnMakePoly "Master_J" masterMatJ #(1,1,1,2,2,2)
    targetJ = lmnMakePoly "Target_J" targetMatJ #(1,1,1,2,2,2)
    targetJ.position = [12,34,56]
    targetJ.rotation = eulerAngles 10 20 30
    targetJ.pivot = [1,2,3]
    bendJ = Bend angle:15
    addModifier targetJ bendJ
    oldTransformJ = copy targetJ.transform
    oldPivotJ = copy targetJ.pivot
    oldNameJ = targetJ.name
    oldBaseJ = targetJ.baseObject
    oldModifierJ = targetJ.modifiers[1]
    oldFaceCountJ = polyop.getNumFaces targetJ.baseObject
    oldVertCountJ = polyop.getNumVerts targetJ.baseObject
    oldVertsJ = for vertIndex = 1 to oldVertCountJ collect polyop.getVert targetJ.baseObject vertIndex
    lmnPrepare masterJ #(targetJ)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "J Apply succeeds with a modifier stack"
    lmnAssert (targetJ.name == oldNameJ and targetJ.baseObject == oldBaseJ and targetJ.modifiers.count == 1 and targetJ.modifiers[1] == oldModifierJ) "J Name, base object, and modifier stack stay intact"
    lmnAssert (targetJ.transform == oldTransformJ and targetJ.pivot == oldPivotJ) "J Transform and pivot stay intact"
    currentVertsJ = for vertIndex = 1 to (polyop.getNumVerts targetJ.baseObject) collect polyop.getVert targetJ.baseObject vertIndex
    lmnAssert (polyop.getNumFaces targetJ.baseObject == oldFaceCountJ and polyop.getNumVerts targetJ.baseObject == oldVertCountJ and lmnPointArraysEqual currentVertsJ oldVertsJ) "J Topology and vertex positions stay intact"

    -- One Undo reverses append, face remap, and Target material assignment together.
    masterMatK = lmnMakeMulti #("A") #(1)
    targetMatK = lmnMakeMulti #("D") #(7)
    masterK = lmnMakePoly "Master_K" masterMatK #(1,1,1,1,1,1)
    targetK = lmnMakePoly "Target_K" targetMatK #(7,7,7,7,7,7)
    oldTargetMatK = targetK.material
    oldFacesK = lmnFaceIDs targetK
    oldMasterCountK = masterK.material.materialList.count
    lmnPrepare masterK #(targetK)
    clearUndoBuffer()
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "K Apply succeeds before Undo"
    max undo
    lmnAssert (masterK.material.materialList.count == oldMasterCountK) "K One Undo removes Master append"
    lmnAssert (targetK.material == oldTargetMatK and lmnArrayEquals (lmnFaceIDs targetK) oldFacesK) "K One Undo restores Target material and face IDs"
)
catch
(
    LMN_TEST_FAILED += 1
    lmnTestWrite ("FATAL: " + (getCurrentException() as string))
)

lmnTestWrite ("Passed: " + (LMN_TEST_PASSED as string))
lmnTestWrite ("Failed: " + (LMN_TEST_FAILED as string))
format "[LMN TEST] Passed: %, Failed: %\n" LMN_TEST_PASSED LMN_TEST_FAILED
quitMAX #noPrompt
