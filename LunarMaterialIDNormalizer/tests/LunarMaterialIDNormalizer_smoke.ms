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

fn lmnMakeMultiFromRefs materialRefs materialIDs =
(
    local result = multimaterial numsubs:materialRefs.count
    for indexValue = 1 to materialRefs.count do
    (
        result.materialList[indexValue] = materialRefs[indexValue]
        result.materialIDList[indexValue] = materialIDs[indexValue]
        result.names[indexValue] = materialRefs[indexValue].name
        result.mapEnabled[indexValue] = true
    )
    result
)

fn lmnMakeUSD materialName diffuseValue =
(
    local result = execute "MaxUsdPreviewSurface()"
    result.name = materialName
    result.diffuseColor = diffuseValue
    result
)

fn lmnMakeVRay materialName =
(
    local result = execute "VRayMtl()"
    result.name = materialName
    result
)

fn lmnMakePhysical materialName =
(
    local result = execute "PhysicalMaterial()"
    result.name = materialName
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

fn lmnColorsEqual leftColor rightColor =
(
    leftColor != undefined and rightColor != undefined and
    (abs (leftColor.r - rightColor.r)) <= 0.01 and
    (abs (leftColor.g - rightColor.g)) <= 0.01 and
    (abs (leftColor.b - rightColor.b)) <= 0.01
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

    -- USD Test G: constant diffuse conversion and Analyze is non-mutating.
    usdRedG = lmnMakeUSD "Red" (color 200 20 20)
    masterUsdMatG = lmnMakeMultiFromRefs #(usdRedG) #(1)
    targetUsdMatG = lmnMakeMultiFromRefs #(usdRedG) #(7)
    masterUsdG = lmnMakePoly "USD_Master_G" masterUsdMatG #(1,1,1,1,1,1)
    targetUsdG = lmnMakePoly "USD_Target_G" targetUsdMatG #(7,7,7,7,7,7)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true false 0.8 false (color 255 255 255)
    lmnPrepare masterUsdG #(targetUsdG)
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "USD G Analyze succeeds"
    lmnAssert (masterUsdMatG.materialList[1] == usdRedG and targetUsdMatG.materialList[1] == usdRedG) "USD G Analyze creates no VRayMtl and replaces no reference"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD G Apply succeeds"
    convertedRedG = masterUsdMatG.materialList[1]
    lmnAssert ((classOf convertedRedG as string) == "VRayMtl" and convertedRedG.name == "Red") "USD G creates VRayMtl and preserves name"
    lmnAssert (lmnColorsEqual convertedRedG.Diffuse (color 200 20 20)) "USD G preserves constant diffuse color"
    lmnAssert ((LunarMaterialIDNormalizerRollout.getLastApplyStats())[1] == 1) "USD G conversion count is one unique USD reference"

    -- USD Test H: Glossiness override affects converted materials only.
    usdGlossH = lmnMakeUSD "USD_Gloss_H" (color 100 110 120)
    existingVRayH = lmnMakeVRay "Existing_VRay_H"
    existingVRayH.reflection_glossiness = 0.37
    existingVRayH.brdf_useRoughness = true
    masterUsdMatH = lmnMakeMultiFromRefs #(usdGlossH, existingVRayH) #(1, 2)
    targetUsdMatH = lmnMakeMultiFromRefs #(usdGlossH, existingVRayH) #(7, 8)
    masterUsdH = lmnMakePoly "USD_Master_H" masterUsdMatH #(1,1,1,2,2,2)
    targetUsdH = lmnMakePoly "USD_Target_H" targetUsdMatH #(7,7,7,8,8,8)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true true 0.65 false (color 255 255 255)
    lmnPrepare masterUsdH #(targetUsdH)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD H Apply succeeds"
    convertedGlossH = masterUsdMatH.materialList[1]
    lmnAssert ((abs (convertedGlossH.reflection_glossiness - 0.65)) <= 0.0001 and convertedGlossH.brdf_useRoughness == false) "USD H applies 0.65 in V-Ray Glossiness mode"
    lmnAssert (masterUsdMatH.materialList[2] == existingVRayH and (abs (existingVRayH.reflection_glossiness - 0.37)) <= 0.0001 and existingVRayH.brdf_useRoughness == true) "USD H keeps existing VRayMtl exactly"

    -- USD Test I: Reflection override affects converted materials only.
    usdReflectionI = lmnMakeUSD "USD_Reflection_I" (color 30 40 50)
    existingVRayI = lmnMakeVRay "Existing_VRay_I"
    existingVRayI.Reflection = color 11 22 33
    masterUsdMatI = lmnMakeMultiFromRefs #(usdReflectionI, existingVRayI) #(1, 2)
    targetUsdMatI = lmnMakeMultiFromRefs #(usdReflectionI, existingVRayI) #(4, 5)
    masterUsdI = lmnMakePoly "USD_Master_I" masterUsdMatI #(1,1,1,2,2,2)
    targetUsdI = lmnMakePoly "USD_Target_I" targetUsdMatI #(4,4,4,5,5,5)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true false 0.8 true (color 180 180 180)
    lmnPrepare masterUsdI #(targetUsdI)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD I Apply succeeds"
    lmnAssert (lmnColorsEqual masterUsdMatI.materialList[1].Reflection (color 180 180 180)) "USD I applies Reflection RGB 180,180,180"
    lmnAssert (masterUsdMatI.materialList[2] == existingVRayI and lmnColorsEqual existingVRayI.Reflection (color 11 22 33)) "USD I does not change existing VRayMtl Reflection"

    -- USD Test J: Overrides OFF preserve V-Ray defaults and do not derive from roughness/metallic.
    defaultVRayJ = execute "VRayMtl()"
    defaultGlossJ = defaultVRayJ.reflection_glossiness
    defaultReflectionJ = copy defaultVRayJ.Reflection
    defaultRoughnessModeJ = defaultVRayJ.brdf_useRoughness
    usdDefaultJ = lmnMakeUSD "USD_Default_J" (color 75 85 95)
    usdDefaultJ.roughness = 0.13
    usdDefaultJ.metallic = 0.91
    masterUsdMatJ = lmnMakeMultiFromRefs #(usdDefaultJ) #(1)
    targetUsdMatJ = lmnMakeMultiFromRefs #(usdDefaultJ) #(9)
    masterUsdJ = lmnMakePoly "USD_Master_J" masterUsdMatJ #(1,1,1,1,1,1)
    targetUsdJ = lmnMakePoly "USD_Target_J" targetUsdMatJ #(9,9,9,9,9,9)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true false 0.25 false (color 180 180 180)
    lmnPrepare masterUsdJ #(targetUsdJ)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD J Apply succeeds with overrides OFF"
    convertedDefaultJ = masterUsdMatJ.materialList[1]
    lmnAssert ((abs (convertedDefaultJ.reflection_glossiness - defaultGlossJ)) <= 0.0001 and lmnColorsEqual convertedDefaultJ.Reflection defaultReflectionJ and convertedDefaultJ.brdf_useRoughness == defaultRoughnessModeJ) "USD J preserves VRayMtl Glossiness, Reflection, and mode defaults"
    lmnAssert (lmnColorsEqual convertedDefaultJ.Diffuse (color 75 85 95)) "USD J still copies constant diffuse only"

    -- USD Test K: shared USD instance creates one shared converted instance.
    sharedUsdK = lmnMakeUSD "Shared_USD_K" (color 10 120 210)
    masterSharedMatK = lmnMakeMultiFromRefs #(sharedUsdK) #(1)
    masterSharedK = lmnMakePoly "USD_Master_K" masterSharedMatK #(1,1,1,1,1,1)
    sharedTargetsK = #()
    for objectIndex = 1 to 10 do
    (
        targetSharedMatK = lmnMakeMultiFromRefs #(sharedUsdK) #(7)
        append sharedTargetsK (lmnMakePoly ("USD_Target_K_" + (objectIndex as string)) targetSharedMatK #(7,7,7,7,7,7))
    )
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true false 0.8 false (color 255 255 255)
    lmnPrepare masterSharedK sharedTargetsK
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD K Apply succeeds for ten shared Targets"
    sharedConvertedK = masterSharedMatK.materialList[1]
    allSharedK = true
    for nodeValue in sharedTargetsK while allSharedK do
        if nodeValue.material != masterSharedK.material do allSharedK = false
    lmnAssert ((LunarMaterialIDNormalizerRollout.getLastApplyStats())[1] == 1 and (classOf sharedConvertedK as string) == "VRayMtl") "USD K creates exactly one VRayMtl for one original USD reference"
    lmnAssert allSharedK "USD K all Targets share the Master container and converted material"

    -- USD Test L: Multi/Sub container and IDs stay intact; only USD slots are replaced.
    usdAL = lmnMakeUSD "USD_A_L" (color 20 30 40)
    usdBL = lmnMakeUSD "USD_B_L" (color 50 60 70)
    existingVRayL = lmnMakeVRay "Existing_VRay_L"
    masterMultiL = lmnMakeMultiFromRefs #(usdAL, usdBL, existingVRayL) #(1, 4, 8)
    targetMultiL = lmnMakeMultiFromRefs #(usdBL, existingVRayL, usdAL) #(2, 5, 9)
    masterContainerL = masterMultiL
    targetContainerL = targetMultiL
    masterUsdL = lmnMakePoly "USD_Master_L" masterMultiL #(1,1,4,4,8,8)
    targetUsdL = lmnMakePoly "USD_Target_L" targetMultiL #(2,2,5,5,9,9)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true false 0.8 false (color 255 255 255)
    lmnPrepare masterUsdL #(targetUsdL)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD L Multi/Sub Apply succeeds"
    lmnAssert (masterUsdL.material == masterContainerL and masterContainerL.materialIDList[1] == 1 and masterContainerL.materialIDList[2] == 4 and masterContainerL.materialIDList[3] == 8) "USD L preserves Master Multi/Sub container and IDs"
    lmnAssert ((classOf masterContainerL.materialList[1] as string) == "VRayMtl" and (classOf masterContainerL.materialList[2] as string) == "VRayMtl" and masterContainerL.materialList[3] == existingVRayL) "USD L replaces only USD sub-material references"
    lmnAssert (targetUsdL.material == masterContainerL and lmnArrayEquals (lmnFaceIDs targetUsdL) #(4,4,8,8,1,1)) "USD L normalizes Target IDs and assigns shared Master container"

    -- USD Test M: same exact name with different diffuse colors blocks Apply without scene changes.
    usdConcreteMasterM = lmnMakeUSD "Concrete" (color 150 150 150)
    usdConcreteTargetM = lmnMakeUSD "Concrete" (color 80 80 80)
    masterConflictMatM = lmnMakeMultiFromRefs #(usdConcreteMasterM) #(1)
    targetConflictMatM = lmnMakeMultiFromRefs #(usdConcreteTargetM) #(7)
    masterConflictM = lmnMakePoly "USD_Master_M" masterConflictMatM #(1,1,1,1,1,1)
    targetConflictM = lmnMakePoly "USD_Target_M" targetConflictMatM #(7,7,7,7,7,7)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true true 0.8 true (color 255 255 255)
    lmnPrepare masterConflictM #(targetConflictM)
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "USD M Analyze detects same-name different-diffuse conflict"
    lmnAssert (not LunarMaterialIDNormalizerRollout.applyNormalization()) "USD M conflict blocks Apply"
    lmnAssert (masterConflictMatM.materialList[1] == usdConcreteMasterM and targetConflictMatM.materialList[1] == usdConcreteTargetM and targetConflictM.material == targetConflictMatM) "USD M blocked Apply changes no material reference"

    -- Convert OFF keeps USD materials and still runs the original Material ID normalizer.
    usdKeepN = lmnMakeUSD "USD_Keep_N" (color 90 100 110)
    masterKeepMatN = lmnMakeMultiFromRefs #(usdKeepN) #(3)
    targetKeepMatN = lmnMakeMultiFromRefs #(usdKeepN) #(7)
    masterKeepN = lmnMakePoly "USD_Master_N" masterKeepMatN #(3,3,3,3,3,3)
    targetKeepN = lmnMakePoly "USD_Target_N" targetKeepMatN #(7,7,7,7,7,7)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions false true 0.2 true (color 1 2 3)
    lmnPrepare masterKeepN #(targetKeepN)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD N Convert OFF still normalizes IDs"
    lmnAssert (masterKeepMatN.materialList[1] == usdKeepN and targetKeepN.material == masterKeepMatN and lmnArrayEquals (lmnFaceIDs targetKeepN) #(3,3,3,3,3,3)) "USD N Convert OFF keeps USD reference and assigns Master IDs"

    -- Texture-driven diffuse uses only the constant fallback and creates no VRay texture network.
    usdTextureO = lmnMakeUSD "USD_Texture_O" (color 33 66 99)
    usdTextureO.diffuseColor_map = execute "Noise()"
    masterTextureMatO = lmnMakeMultiFromRefs #(usdTextureO) #(1)
    targetTextureMatO = lmnMakeMultiFromRefs #(usdTextureO) #(6)
    masterTextureO = lmnMakePoly "USD_Master_O" masterTextureMatO #(1,1,1,1,1,1)
    targetTextureO = lmnMakePoly "USD_Target_O" targetTextureMatO #(6,6,6,6,6,6)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true false 0.8 false (color 255 255 255)
    lmnPrepare masterTextureO #(targetTextureO)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD O texture-driven diffuse Apply succeeds"
    convertedTextureO = masterTextureMatO.materialList[1]
    lmnAssert (lmnColorsEqual convertedTextureO.Diffuse (color 33 66 99) and convertedTextureO.texmap_diffuse == undefined) "USD O uses fallback color and ignores texture network"

    -- USD Test P: one Undo reverses conversion, append, remap, and assignment together.
    usdMasterP = lmnMakeUSD "USD_Master_P" (color 15 25 35)
    usdTargetP = lmnMakeUSD "USD_Target_P" (color 45 55 65)
    masterUsdMatP = lmnMakeMultiFromRefs #(usdMasterP) #(1)
    targetUsdMatP = lmnMakeMultiFromRefs #(usdTargetP) #(7)
    masterUsdP = lmnMakePoly "USD_Master_P_Node" masterUsdMatP #(1,1,1,1,1,1)
    targetUsdP = lmnMakePoly "USD_Target_P_Node" targetUsdMatP #(7,7,7,7,7,7)
    oldTargetMatP = targetUsdP.material
    oldFacesP = lmnFaceIDs targetUsdP
    oldMasterCountP = masterUsdMatP.materialList.count
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true true 0.72 true (color 140 150 160)
    lmnPrepare masterUsdP #(targetUsdP)
    clearUndoBuffer()
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "USD P Apply succeeds before Undo"
    max undo
    lmnAssert (masterUsdMatP.materialList.count == oldMasterCountP and masterUsdMatP.materialList[1] == usdMasterP) "USD P One Undo restores Master USD reference and removes append"
    lmnAssert (targetUsdP.material == oldTargetMatP and oldTargetMatP.materialList[1] == usdTargetP and lmnArrayEquals (lmnFaceIDs targetUsdP) oldFacesP) "USD P One Undo restores Target USD reference, container, and face IDs"

    -- Effective class validation: USD becomes VRayMtl when conversion is enabled.
    masterVRayQ = lmnMakeVRay "Body_01"
    masterVRayQ.Diffuse = color 120 80 40
    targetUsdQ = lmnMakeUSD "Body_01" (color 120 80 40)
    masterClassMatQ = lmnMakeMultiFromRefs #(masterVRayQ) #(1)
    targetClassMatQ = lmnMakeMultiFromRefs #(targetUsdQ) #(7)
    masterClassQ = lmnMakePoly "Class_Master_Q" masterClassMatQ #(1,1,1,1,1,1)
    targetClassQ = lmnMakePoly "Class_Target_Q" targetClassMatQ #(7,7,7,7,7,7)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true false 0.8 false (color 255 255 255)
    LunarMaterialIDNormalizerRollout.setExtendedOptions true false
    lmnPrepare masterClassQ #(targetClassQ)
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "Class Q USD and VRay with the same effective class do not conflict"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "Class Q compatible effective classes normalize successfully"

    -- Same name with an unsupported effective class is a class conflict.
    masterVRayR = lmnMakeVRay "Body_Class_Conflict"
    targetPhysicalR = lmnMakePhysical "Body_Class_Conflict"
    masterClassMatR = lmnMakeMultiFromRefs #(masterVRayR) #(1)
    targetClassMatR = lmnMakeMultiFromRefs #(targetPhysicalR) #(7)
    masterClassR = lmnMakePoly "Class_Master_R" masterClassMatR #(1,1,1,1,1,1)
    targetClassR = lmnMakePoly "Class_Target_R" targetClassMatR #(7,7,7,7,7,7)
    lmnPrepare masterClassR #(targetClassR)
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "Class R same name with different effective classes blocks Analyze readiness"
    lmnAssert (not LunarMaterialIDNormalizerRollout.applyNormalization()) "Class R class conflict blocks Normalize Apply"
    lmnAssert (targetClassR.material == targetClassMatR and targetClassMatR.materialList[1] == targetPhysicalR) "Class R blocked operation leaves unsupported material unchanged"

    -- Convert Materials Only changes material references and slot labels, but no IDs or assignments.
    usdMasterS = lmnMakeUSD "변환_마스터" (color 70 80 90)
    usdTargetS = lmnMakeUSD "変換_ターゲット" (color 20 30 40)
    masterConvertMatS = lmnMakeMultiFromRefs #(usdMasterS) #(1)
    targetConvertMatS = lmnMakeMultiFromRefs #(usdTargetS) #(13)
    masterConvertMatS.names[1] = "(1)"
    targetConvertMatS.names[1] = "(13)"
    masterConvertS = lmnMakePoly "ConvertOnly_Master_S" masterConvertMatS #(1,1,1,1,1,1)
    targetConvertS = lmnMakePoly "ConvertOnly_Target_S" targetConvertMatS #(13,13,13,13,13,13)
    oldFacesS = lmnFaceIDs targetConvertS
    oldMasterCountS = masterConvertMatS.materialList.count
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true true 0.44 true (color 150 160 170)
    LunarMaterialIDNormalizerRollout.setExtendedOptions true false
    lmnPrepare masterConvertS #(targetConvertS)
    clearUndoBuffer()
    lmnAssert (LunarMaterialIDNormalizerRollout.convertMaterialsOnly()) "Convert Only S succeeds"
    lmnAssert ((classOf masterConvertMatS.materialList[1] as string) == "VRayMtl" and (classOf targetConvertMatS.materialList[1] as string) == "VRayMtl") "Convert Only S converts registered USD materials"
    lmnAssert (masterConvertMatS.materialList.count == oldMasterCountS and targetConvertS.material == targetConvertMatS) "Convert Only S performs no append or Master assignment"
    lmnAssert (lmnArrayEquals (lmnFaceIDs targetConvertS) oldFacesS) "Convert Only S leaves face Material IDs unchanged"
    lmnAssert (masterConvertMatS.names[1] == "변환_마스터" and targetConvertMatS.names[1] == "変換_ターゲット") "Convert Only S synchronizes slot labels by slot index"
    convertStatsS = LunarMaterialIDNormalizerRollout.getLastOperationStats()
    lmnAssert (convertStatsS[1] == #convertOnly and convertStatsS[2] == 2 and convertStatsS[3] == 0) "Convert Only S reports conversion with zero appended materials"
    max undo
    lmnAssert (masterConvertMatS.materialList[1] == usdMasterS and targetConvertMatS.materialList[1] == usdTargetS and masterConvertMatS.names[1] == "(1)" and targetConvertMatS.names[1] == "(13)") "Convert Only S one Undo restores USD references and slot labels"

    -- Normalize syncs existing and newly appended Master slots.
    masterSyncMatT = lmnMakeMulti #("Sync_A") #(1)
    targetSyncMatT = lmnMakeMulti #("Sync_D") #(9)
    masterSyncMatT.names[1] = "(1)"
    targetSyncMatT.names[1] = "(9)"
    masterSyncT = lmnMakePoly "Sync_Master_T" masterSyncMatT #(1,1,1,1,1,1)
    targetSyncT = lmnMakePoly "Sync_Target_T" targetSyncMatT #(9,9,9,9,9,9)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions false false 0.8 false (color 255 255 255)
    LunarMaterialIDNormalizerRollout.setExtendedOptions true false
    lmnPrepare masterSyncT #(targetSyncT)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "Slot Sync T Normalize Apply succeeds"
    syncDSlotT = lmnFindMaterialSlot masterSyncMatT "Sync_D"
    lmnAssert (masterSyncMatT.names[1] == "Sync_A" and syncDSlotT > 0 and masterSyncMatT.names[syncDSlotT] == "Sync_D") "Slot Sync T updates existing and appended Master slot names"

    -- UTF-8 report exports predicted raw/effective class data and non-ASCII names.
    reportPathU = "C:\\tmp\\lmn-unicode-material-report.txt"
    try (deleteFile reportPathU) catch()
    masterReportVRayU = lmnMakeVRay "벽_한국어_材質"
    masterReportVRayU.Diffuse = color 12 34 56
    targetReportUsdU = lmnMakeUSD "벽_한국어_材質" (color 12 34 56)
    masterReportMatU = lmnMakeMultiFromRefs #(masterReportVRayU) #(1)
    targetReportMatU = lmnMakeMultiFromRefs #(targetReportUsdU) #(7)
    masterReportU = lmnMakePoly "마스터_오브젝트" masterReportMatU #(1,1,1,1,1,1)
    targetReportU = lmnMakePoly "ターゲット_오브젝트" targetReportMatU #(7,7,7,7,7,7)
    LunarMaterialIDNormalizerRollout.setPreprocessOptions true true 0.4 true (color 100 110 120)
    LunarMaterialIDNormalizerRollout.setExtendedOptions true false
    lmnPrepare masterReportU #(targetReportU)
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false recordOperation:true) "Report U Analyze succeeds"
    lmnAssert (LunarMaterialIDNormalizerRollout.exportReportToPath reportPathU) "Report U UTF-8 export succeeds"
    reportTextU = (dotNetClass "System.IO.File").ReadAllText reportPathU
    lmnAssert ((findString reportTextU "Last Operation: ANALYZE") != undefined and (findString reportTextU "MaxUsdPreviewSurface") != undefined and (findString reportTextU "VRayMtl") != undefined) "Report U contains operation and raw/effective classes"
    lmnAssert ((findString reportTextU "벽_한국어_材質") != undefined and (findString reportTextU "ターゲット_오브젝트") != undefined) "Report U preserves Korean and Japanese names"
    try (deleteFile reportPathU) catch()

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
