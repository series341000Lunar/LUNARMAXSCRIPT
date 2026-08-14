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

fn lmnFaceMaterialRefs nodeValue =
(
    local result = #()
    local topMaterial = nodeValue.material
    for faceIndex = 1 to polyop.getNumFaces nodeValue do
    (
        local faceID = polyop.getFaceMatID nodeValue faceIndex
        local materialReference = undefined
        if topMaterial != undefined and classOf topMaterial == Multimaterial do
        (
            for slotIndex = 1 to topMaterial.materialList.count while materialReference == undefined do
                if topMaterial.materialIDList[slotIndex] == faceID do materialReference = topMaterial.materialList[slotIndex]
        )
        append result materialReference
    )
    result
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

fn lmnPairValue pairs keyValue =
(
    local result = ""
    for pairValue in pairs while result == "" do
        if pairValue.count >= 2 and pairValue[1] == keyValue do result = pairValue[2]
    result
)

fn lmnAZRegistryID previewValues materialName =
(
    local result = 0
    for rowValue in previewValues[3] while result == 0 do
        if rowValue[2] == materialName do result = rowValue[1]
    result
)

fn lmnHasAZConflict previewValues conflictType =
(
    local found = false
    for rowValue in previewValues[5] while not found do
        if rowValue[1] == conflictType do found = true
    found
)

fn lmnSelectionContains nodeValue =
(
    local found = false
    if nodeValue != undefined and isValidNode nodeValue do
    (
        for selectedNode in selection while not found do
            if selectedNode == nodeValue do found = true
    )
    found
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
    LunarMaterialIDNormalizerRollout.clearMasterNode()
    LunarMaterialIDNormalizerRollout.clearTargetNodes()
    select #(masterConvertS, targetConvertS)
    clearUndoBuffer()
    lmnAssert (LunarMaterialIDNormalizerRollout.convertMaterialsOnly()) "Convert Only S succeeds without Master or Targets"
    lmnAssert ((classOf masterConvertMatS.materialList[1] as string) == "VRayMtl" and (classOf targetConvertMatS.materialList[1] as string) == "VRayMtl") "Convert Only S converts all selected USD materials"
    lmnAssert (masterConvertMatS.materialList.count == oldMasterCountS and targetConvertS.material == targetConvertMatS) "Convert Only S performs no append or Master assignment"
    lmnAssert (lmnArrayEquals (lmnFaceIDs targetConvertS) oldFacesS) "Convert Only S leaves face Material IDs unchanged"
    lmnAssert (masterConvertMatS.names[1] == "변환_마스터" and targetConvertMatS.names[1] == "変換_ターゲット") "Convert Only S synchronizes slot labels by slot index"
    convertStatsS = LunarMaterialIDNormalizerRollout.getLastOperationStats()
    lmnAssert (convertStatsS[1] == #convertOnly and convertStatsS[2] == 2 and convertStatsS[3] == 0) "Convert Only S reports conversion with zero appended materials"
    max undo
    lmnAssert (masterConvertMatS.materialList[1] == usdMasterS and targetConvertMatS.materialList[1] == usdTargetS and masterConvertMatS.names[1] == "(1)" and targetConvertMatS.names[1] == "(13)") "Convert Only S one Undo restores USD references and slot labels"

    -- An existing Master does not control selection-based Convert Only; existing VRayMtl is untouched.
    registeredUsdV = lmnMakeUSD "Registered_Master_Keep" (color 5 15 25)
    registeredMatV = lmnMakeMultiFromRefs #(registeredUsdV) #(1)
    registeredMasterV = lmnMakePoly "Registered_Master_V" registeredMatV #(1,1,1,1,1,1)
    selectedUsdV = lmnMakeUSD "Selected_USD_V" (color 35 45 55)
    selectedVRayV = lmnMakeVRay "Selected_Existing_VRay_V"
    selectedVRayV.Diffuse = color 65 75 85
    selectedMatV = lmnMakeMultiFromRefs #(selectedUsdV, selectedVRayV) #(4, 21)
    selectedMatV.names[1] = "(4)"
    selectedMatV.names[2] = "(21)"
    selectedNodeV = lmnMakePoly "Selected_Unrelated_V" selectedMatV #(4,4,4,21,21,21)
    oldFacesV = lmnFaceIDs selectedNodeV
    LunarMaterialIDNormalizerRollout.clearTargetNodes()
    LunarMaterialIDNormalizerRollout.setMasterNode registeredMasterV
    select selectedNodeV
    lmnAssert (LunarMaterialIDNormalizerRollout.convertMaterialsOnly()) "Convert Only V uses current selection while a different Master is registered"
    lmnAssert (registeredMatV.materialList[1] == registeredUsdV and (classOf registeredUsdV as string) == "MaxUsdPreviewSurface") "Convert Only V does not use or modify registered Master scope"
    lmnAssert ((classOf selectedMatV.materialList[1] as string) == "VRayMtl" and selectedMatV.materialList[2] == selectedVRayV and lmnColorsEqual selectedVRayV.Diffuse (color 65 75 85)) "Convert Only V converts selected USD and keeps existing VRayMtl untouched"
    lmnAssert (lmnArrayEquals (lmnFaceIDs selectedNodeV) oldFacesV and selectedMatV.names[1] == "Selected_USD_V" and selectedMatV.names[2] == "Selected_Existing_VRay_V") "Convert Only V preserves IDs and synchronizes selected Multi/Sub slot names"

    -- No selection returns a friendly error and makes no material change.
    selectedMaterialBeforeNoSelectionV = selectedNodeV.material
    selectedFirstBeforeNoSelectionV = selectedMatV.materialList[1]
    clearSelection()
    lmnAssert (not LunarMaterialIDNormalizerRollout.convertMaterialsOnly()) "Convert Only no-selection request is rejected"
    lmnAssert (selectedNodeV.material == selectedMaterialBeforeNoSelectionV and selectedMatV.materialList[1] == selectedFirstBeforeNoSelectionV) "Convert Only no-selection request changes no scene material"

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
    defaultReportPathU = LunarMaterialIDNormalizerRollout.reportDefaultPath()
    lmnAssert (classOf defaultReportPathU == String and LunarMaterialIDNormalizerRollout.isValidReportSeedPath defaultReportPathU) "Report U default Save-dialog seed is a valid String in an existing directory"
    lmnAssert (LunarMaterialIDNormalizerRollout.exportReportToPath reportPathU) "Report U UTF-8 export succeeds"
    reportTextU = (dotNetClass "System.IO.File").ReadAllText reportPathU
    lmnAssert ((findString reportTextU "Last Operation: ANALYZE") != undefined and (findString reportTextU "MaxUsdPreviewSurface") != undefined and (findString reportTextU "VRayMtl") != undefined) "Report U contains operation and raw/effective classes"
    lmnAssert ((findString reportTextU "벽_한국어_材質") != undefined and (findString reportTextU "ターゲット_오브젝트") != undefined) "Report U preserves Korean and Japanese names"
    lmnAssert ((findString reportTextU "Report Format Version: 1") != undefined) "Report U declares report format version 1"

    -- Report loader parses exported, LF-only, legacy, malformed, and unrelated inputs without scene coupling.
    reportTargetMaterialBeforeLoadU = targetReportU.material
    reportTargetFacesBeforeLoadU = lmnFaceIDs targetReportU
    reportSelectionBeforeLoadU = for nodeValue in selection collect nodeValue
    lmnAssert (LunarMaterialIDNormalizerRollout.loadReportFromPath reportPathU showViewer:false showErrors:false) "Load Report U loads the exported UTF-8 report"
    loadedSnapshotU = LunarMaterialIDNormalizerRollout.getLoadedReportSnapshot()
    lmnAssert (loadedSnapshotU != undefined and loadedSnapshotU[1] == "1" and lmnPairValue loadedSnapshotU[2] "Tool Version" == "MK2") "Load Report U preserves version metadata"
    lmnAssert (loadedSnapshotU[7].count > 0 and loadedSnapshotU[7][1][2] == "벽_한국어_材質" and loadedSnapshotU[8].count == 1 and loadedSnapshotU[8][1][1] == "ターゲット_오브젝트") "Load Report U preserves Unicode canonical and target values"
    lmnAssert (targetReportU.material == reportTargetMaterialBeforeLoadU and lmnArrayEquals (lmnFaceIDs targetReportU) reportTargetFacesBeforeLoadU and lmnArrayEquals (for nodeValue in selection collect nodeValue) reportSelectionBeforeLoadU) "Load Report U changes no scene material, face ID, or selection"

    loadedConvertUsdU = lmnMakeUSD "Loaded_Convert_Only_U" (color 31 41 51)
    loadedConvertMatU = lmnMakeMultiFromRefs #(loadedConvertUsdU) #(17)
    loadedConvertNodeU = lmnMakePoly "Loaded_Convert_Node_U" loadedConvertMatU #(17,17,17,17,17,17)
    loadedConvertFacesU = lmnFaceIDs loadedConvertNodeU
    select loadedConvertNodeU
    lmnAssert (LunarMaterialIDNormalizerRollout.convertMaterialsOnly()) "Load Report U does not block selection-based Convert Materials Only"
    lmnAssert ((classOf loadedConvertMatU.materialList[1] as string) == "VRayMtl" and lmnArrayEquals (lmnFaceIDs loadedConvertNodeU) loadedConvertFacesU) "Load Report U Convert Only converts selection without normalizing its face IDs"
    loadedSnapshotAfterConvertU = LunarMaterialIDNormalizerRollout.getLoadedReportSnapshot()
    lmnAssert (loadedSnapshotAfterConvertU[14] == reportPathU and masterReportU.material == masterReportMatU and targetReportU.material == reportTargetMaterialBeforeLoadU) "Load Report U Convert Only preserves the loaded snapshot and registered normalization scope"

    lfOnlyResultU = LunarMaterialIDNormalizerRollout.parseReportText (substituteString reportTextU "\r\n" "\n")
    lmnAssert (lfOnlyResultU[1] and lfOnlyResultU[3][7].count == loadedSnapshotU[7].count) "Load Report U accepts LF-only section and table formatting"

    legacyReportTextU = substituteString reportTextU "Report Format Version: 1\r\n" ""
    legacyResultU = LunarMaterialIDNormalizerRollout.parseReportText legacyReportTextU
    lmnAssert (legacyResultU[1] and legacyResultU[3][1] == "1" and legacyResultU[3][12].count > 0) "Load Report U accepts a recognizable legacy report as format 1"

    unrelatedResultU = LunarMaterialIDNormalizerRollout.parseReportText "Unrelated material notes\n[SUMMARY]\nNothing: here"
    emptyResultU = LunarMaterialIDNormalizerRollout.parseReportText " \r\n\t"
    lmnAssert (not unrelatedResultU[1] and not emptyResultU[1]) "Load Report U rejects unrelated and empty text cleanly"

    headerOnlyResultU = LunarMaterialIDNormalizerRollout.parseReportText "Lunar Material ID Normalizer Report\nTool Version: MK1\n"
    unsupportedResultU = LunarMaterialIDNormalizerRollout.parseReportText "Lunar Material ID Normalizer Report\nReport Format Version: 9\n[SUMMARY]\nMaterial Count: 0\n"
    lmnAssert (not headerOnlyResultU[1] and not unsupportedResultU[1]) "Load Report U rejects unrecognizable truncation and unsupported versions"

    malformedReportTextU = "\nLunar Material ID Normalizer Report\nTool Version: MK1\nReport Format Version: 1\n[SUMMARY]\nMaterial Count: not-an-integer\n[CANONICAL MATERIAL TABLE]\nID\tMaterial Name\tRaw Class\tEffective / Final Class\tSource / Status\nabc\t재질_오류\tVRayMtl\n[APPENDED MATERIALS]\nnot-id\t追加_材質\n"
    malformedResultU = LunarMaterialIDNormalizerRollout.parseReportText malformedReportTextU
    lmnAssert (malformedResultU[1] and malformedResultU[3][7].count == 1 and malformedResultU[3][7][1][2] == "재질_오류") "Load Report U keeps a malformed Unicode row as a read-only value"
    lmnAssert (malformedResultU[3][12].count >= 3) "Load Report U records malformed columns and invalid integers as parser warnings"

    truncatedOptionalResultU = LunarMaterialIDNormalizerRollout.parseReportText "Lunar Material ID Normalizer Report\nTool Version: MK1\n[SUMMARY]\nMaterial Count: 2\n[CONFLICTS / WARNINGS]\n"
    lmnAssert (truncatedOptionalResultU[1] and truncatedOptionalResultU[3][7].count == 0 and truncatedOptionalResultU[3][9].count == 0) "Load Report U tolerates missing optional sections"

    invalidReportPathU = "C:\\tmp\\lmn-unrelated-report.txt"
    try (deleteFile invalidReportPathU) catch()
    (dotNetClass "System.IO.File").WriteAllText invalidReportPathU "Not an LMN report" (dotNetObject "System.Text.UTF8Encoding" false)
    loadedPathBeforeInvalidU = loadedSnapshotU[14]
    lmnAssert (not LunarMaterialIDNormalizerRollout.loadReportFromPath invalidReportPathU showViewer:false showErrors:false) "Load Report U path loader rejects an unrelated file without throwing"
    loadedSnapshotAfterInvalidU = LunarMaterialIDNormalizerRollout.getLoadedReportSnapshot()
    lmnAssert (loadedSnapshotAfterInvalidU[14] == loadedPathBeforeInvalidU) "Load Report U failed load preserves the prior read-only snapshot"
    try (deleteFile invalidReportPathU) catch()

    -- Loading is independent from live Analyze and Normalize state.
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false recordOperation:true) "Load Report U does not disturb registered Master and Targets for Analyze"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyNormalization()) "Load Report U does not disturb Normalize Apply"
    lmnAssert (targetReportU.material == masterReportU.material and lmnArrayEquals (lmnFaceIDs targetReportU) #(1,1,1,1,1,1)) "Load Report U has no effect on the expected Normalize result"
    loadedSnapshotAfterNormalizeU = LunarMaterialIDNormalizerRollout.getLoadedReportSnapshot()
    lmnAssert (loadedSnapshotAfterNormalizeU[14] == reportPathU) "Live Analyze and Normalize do not replace the loaded read-only snapshot"
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

    /* MK2 GLOBAL A-Z REINDEX acceptance tests. */

    -- A: Basic global alphabetical IDs, slot order, face appearance, and read-only Analyze.
    azMatA = lmnMakeMulti #("Steel_AZ_A", "Concrete_AZ_A", "Wood_AZ_A", "Glass_AZ_A") #(7,2,9,4)
    azNodeA = lmnMakePoly "AZ_Basic_A" azMatA #(7,2,9,4,7,2)
    azOldFacesA = lmnFaceIDs azNodeA
    azOldAppearanceA = lmnFaceMaterialRefs azNodeA
    LunarMaterialIDNormalizerRollout.clearMasterNode()
    LunarMaterialIDNormalizerRollout.clearTargetNodes()
    select azNodeA
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false recordOperation:true) "AZ A Basic Analyze succeeds without Master or Targets"
    azPreviewA = LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()
    lmnAssert (lmnAZRegistryID azPreviewA "Concrete_AZ_A" == 1 and lmnAZRegistryID azPreviewA "Glass_AZ_A" == 2 and lmnAZRegistryID azPreviewA "Steel_AZ_A" == 3 and lmnAZRegistryID azPreviewA "Wood_AZ_A" == 4) "AZ A builds one deterministic alphabetical registry"
    lmnAssert (lmnArrayEquals (lmnFaceIDs azNodeA) azOldFacesA and lmnArrayEquals (lmnFaceMaterialRefs azNodeA) azOldAppearanceA) "AZ A Analyze is read-only"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ A Apply succeeds"
    lmnAssert (azMatA.materialList[1].name == "Concrete_AZ_A" and azMatA.materialIDList[1] == 1 and azMatA.materialList[4].name == "Wood_AZ_A" and azMatA.materialIDList[4] == 4) "AZ A reorders existing slots and assigns Global IDs"
    lmnAssert (lmnArrayEquals (lmnFaceMaterialRefs azNodeA) azOldAppearanceA) "AZ A preserves per-face material appearance"

    -- B: Case-insensitive ordering preserves original capitalization and is deterministic.
    azMatB = lmnMakeMulti #("wood_AZ_B", "Concrete_AZ_B", "METAL_AZ_B", "glass_AZ_B") #(11,12,13,14)
    azNodeB = lmnMakePoly "AZ_Case_B" azMatB #(11,12,13,14,11,12)
    select azNodeB
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false) "AZ B Case-insensitive Analyze succeeds"
    azPreviewB1 = LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()
    lmnAssert (lmnAZRegistryID azPreviewB1 "Concrete_AZ_B" == 1 and lmnAZRegistryID azPreviewB1 "glass_AZ_B" == 2 and lmnAZRegistryID azPreviewB1 "METAL_AZ_B" == 3 and lmnAZRegistryID azPreviewB1 "wood_AZ_B" == 4) "AZ B ignores case while sorting"
    LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false
    azPreviewB2 = LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()
    lmnAssert (azPreviewB1[3][1][2] == azPreviewB2[3][1][2] and azPreviewB1[3][4][2] == azPreviewB2[3][4][2]) "AZ B repeated Analyze is deterministic"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex() and azMatB.materialList[2].name == "glass_AZ_B" and azMatB.materialList[3].name == "METAL_AZ_B") "AZ B preserves original capitalization"

    -- C: Different old IDs across different containers receive the same Global IDs.
    azSteelC1 = standardMaterial name:"Steel_AZ_C" diffuse:(color 90 90 90)
    azConcreteC1 = standardMaterial name:"Concrete_AZ_C" diffuse:(color 120 120 120)
    azSteelC2 = standardMaterial name:"steel_AZ_C" diffuse:(color 90 90 90)
    azConcreteC2 = standardMaterial name:"concrete_AZ_C" diffuse:(color 120 120 120)
    azMatC1 = lmnMakeMultiFromRefs #(azSteelC1, azConcreteC1) #(2,8)
    azMatC2 = lmnMakeMultiFromRefs #(azSteelC2, azConcreteC2) #(19,1)
    azNodeC1 = lmnMakePoly "AZ_DifferentIDs_C1" azMatC1 #(2,8,2,8,2,8)
    azNodeC2 = lmnMakePoly "AZ_DifferentIDs_C2" azMatC2 #(19,1,19,1,19,1)
    select #(azNodeC1, azNodeC2)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ C Apply supports different old IDs across objects"
    lmnAssert (azMatC1.materialIDList[lmnFindMaterialSlot azMatC1 "Steel_AZ_C"] == azMatC2.materialIDList[lmnFindMaterialSlot azMatC2 "steel_AZ_C"] and azMatC1.materialIDList[lmnFindMaterialSlot azMatC1 "Concrete_AZ_C"] == azMatC2.materialIDList[lmnFindMaterialSlot azMatC2 "concrete_AZ_C"]) "AZ C assigns the same IDs to case-insensitive names"

    -- D: Material subsets keep sparse Global IDs without creating missing slots.
    azMatD1 = lmnMakeMulti #("A_AZ_D", "D_AZ_D") #(7,9)
    azMatD2 = lmnMakeMulti #("B_AZ_D", "C_AZ_D") #(3,5)
    azNodeD1 = lmnMakePoly "AZ_Subset_D1" azMatD1 #(7,9,7,9,7,9)
    azNodeD2 = lmnMakePoly "AZ_Subset_D2" azMatD2 #(3,5,3,5,3,5)
    select #(azNodeD1, azNodeD2)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ D Apply supports material subsets"
    lmnAssert (azMatD1.materialList.count == 2 and azMatD1.materialIDList[1] == 1 and azMatD1.materialIDList[2] == 4 and azMatD2.materialList.count == 2 and azMatD2.materialIDList[1] == 2 and azMatD2.materialIDList[2] == 3) "AZ D keeps sparse Global IDs and creates no missing slots"

    -- E: Original face BitArray snapshots protect an ID swap.
    azMatE = lmnMakeMulti #("B_AZ_E", "A_AZ_E") #(1,2)
    azNodeE = lmnMakePoly "AZ_Swap_E" azMatE #(1,2,1,2,1,2)
    azAppearanceE = lmnFaceMaterialRefs azNodeE
    select azNodeE
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ E ID-swap Apply succeeds"
    lmnAssert (azMatE.materialList[1].name == "A_AZ_E" and azMatE.materialIDList[1] == 1 and azMatE.materialList[2].name == "B_AZ_E" and azMatE.materialIDList[2] == 2 and lmnArrayEquals (lmnFaceMaterialRefs azNodeE) azAppearanceE) "AZ E remaps from original face snapshots without double-changing swapped IDs"

    -- F/G: Shared Multi/Sub succeeds only when every user can be remapped.
    azSharedMatF = lmnMakeMulti #("B_AZ_F", "A_AZ_F") #(8,3)
    azSharedF1 = lmnMakePoly "AZ_Shared_F1" azSharedMatF #(8,3,8,3,8,3)
    azSharedF2 = lmnMakePoly "AZ_Shared_F2" azSharedMatF #(3,8,3,8,3,8)
    azSharedF3 = lmnMakePoly "AZ_Shared_F3" azSharedMatF #(8,8,3,3,8,3)
    azAppearanceF1 = lmnFaceMaterialRefs azSharedF1
    azAppearanceF2 = lmnFaceMaterialRefs azSharedF2
    azAppearanceF3 = lmnFaceMaterialRefs azSharedF3
    select #(azSharedF1, azSharedF2, azSharedF3)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ F shared Multi/Sub Apply succeeds when all users are selected"
    lmnAssert (azSharedF1.material == azSharedMatF and azSharedF2.material == azSharedMatF and azSharedF3.material == azSharedMatF and azSharedMatF.materialList[1].name == "A_AZ_F") "AZ F preserves one shared Multi/Sub reference and reorders it once"
    lmnAssert (lmnArrayEquals (lmnFaceMaterialRefs azSharedF1) azAppearanceF1 and lmnArrayEquals (lmnFaceMaterialRefs azSharedF2) azAppearanceF2 and lmnArrayEquals (lmnFaceMaterialRefs azSharedF3) azAppearanceF3) "AZ F remaps every shared user's faces without appearance change"

    azSharedMatG = lmnMakeMulti #("B_AZ_G", "A_AZ_G") #(8,3)
    azSharedG1 = lmnMakePoly "AZ_Shared_G1" azSharedMatG #(8,3,8,3,8,3)
    azSharedG2 = lmnMakePoly "AZ_Shared_G2" azSharedMatG #(3,8,3,8,3,8)
    azSharedG3 = lmnMakePoly "AZ_Shared_G3_EXTERNAL" azSharedMatG #(8,8,3,3,8,3)
    azOldIDsG = for value in azSharedMatG.materialIDList collect value
    azOldFacesG = lmnFaceIDs azSharedG1
    azAppearanceG1 = lmnFaceMaterialRefs azSharedG1
    azAppearanceG2 = lmnFaceMaterialRefs azSharedG2
    azAppearanceG3 = lmnFaceMaterialRefs azSharedG3
    select #(azSharedG1, azSharedG2)
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false) "AZ G Analyze blocks an unselected shared Multi/Sub user"
    azPreviewG = LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()
    azRequiredG = LunarMaterialIDNormalizerRollout.getGlobalAZRequiredUserValues()
    lmnAssert (lmnHasAZConflict azPreviewG "REQUIRED / NOT SELECTED" and (findString azPreviewG[5][1][3] "AZ_Shared_G3_EXTERNAL") != undefined) "AZ G identifies the required unselected user by name"
    lmnAssert (azRequiredG[1].count == 1 and azRequiredG[1][1] == azSharedG3) "AZ G stores the exact required Scene Node reference"
    lmnAssert (not LunarMaterialIDNormalizerRollout.applyGlobalAZReindex() and lmnArrayEquals (for value in azSharedMatG.materialIDList collect value) azOldIDsG and lmnArrayEquals (lmnFaceIDs azSharedG1) azOldFacesG) "AZ G blocked Apply makes no scene change"
    azSelectResultG = LunarMaterialIDNormalizerRollout.selectGlobalAZRequiredObjects()
    lmnAssert (azSelectResultG[1] == 1 and azSelectResultG[4] and lmnSelectionContains azSharedG1 and lmnSelectionContains azSharedG2 and lmnSelectionContains azSharedG3) "AZ G adds the required user while preserving existing selection and automatically re-analyzes"
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ G Apply succeeds after every shared user is selected"
    lmnAssert (lmnArrayEquals (lmnFaceMaterialRefs azSharedG1) azAppearanceG1 and lmnArrayEquals (lmnFaceMaterialRefs azSharedG2) azAppearanceG2 and lmnArrayEquals (lmnFaceMaterialRefs azSharedG3) azAppearanceG3) "AZ G required-user workflow preserves shared-user appearance"

    -- Shared-user selection UX: hidden, multiple, unsupported, and invalid users.
    azSharedMatHidden = lmnMakeMulti #("B_AZ_HIDDEN", "A_AZ_HIDDEN") #(9,4)
    azHiddenScope = lmnMakePoly "AZ_Hidden_Scope" azSharedMatHidden #(9,4,9,4,9,4)
    azHiddenRequired = lmnMakePoly "AZ_Hidden_Required" azSharedMatHidden #(4,9,4,9,4,9)
    azHiddenOldIDs = for value in azSharedMatHidden.materialIDList collect value
    azHiddenOldFaces = lmnFaceIDs azHiddenRequired
    azHiddenAppearanceScope = lmnFaceMaterialRefs azHiddenScope
    azHiddenAppearanceRequired = lmnFaceMaterialRefs azHiddenRequired
    hide azHiddenRequired
    select azHiddenScope
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "REQUIRED / NOT SELECTED") "AZ Required Hidden Analyze identifies a hidden unselected user"
    azHiddenSelectResult = LunarMaterialIDNormalizerRollout.selectGlobalAZRequiredObjects()
    lmnAssert (azHiddenSelectResult[1] == 1 and azHiddenSelectResult[2] == 1 and azHiddenSelectResult[4] and lmnSelectionContains azHiddenScope and lmnSelectionContains azHiddenRequired) "AZ Required Hidden adds the hidden node and preserves the existing selection"
    lmnAssert azHiddenRequired.isHidden "AZ Required Hidden preserves hidden state"
    clearUndoBuffer()
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ Required Hidden shared users apply successfully"
    lmnAssert (azHiddenRequired.isHidden and lmnArrayEquals (lmnFaceMaterialRefs azHiddenScope) azHiddenAppearanceScope and lmnArrayEquals (lmnFaceMaterialRefs azHiddenRequired) azHiddenAppearanceRequired) "AZ Required Hidden Apply preserves visibility and appearance"
    max undo
    lmnAssert (azHiddenRequired.isHidden and lmnArrayEquals (for value in azSharedMatHidden.materialIDList collect value) azHiddenOldIDs and lmnArrayEquals (lmnFaceIDs azHiddenRequired) azHiddenOldFaces) "AZ Required Hidden one Undo restores IDs while preserving hidden state"

    azSharedMatFrozen = lmnMakeMulti #("B_AZ_FROZEN", "A_AZ_FROZEN") #(11,6)
    azFrozenScope = lmnMakePoly "AZ_Frozen_Scope" azSharedMatFrozen #(11,6,11,6,11,6)
    azFrozenRequired = lmnMakePoly "AZ_Frozen_Required" azSharedMatFrozen #(6,11,6,11,6,11)
    freeze azFrozenRequired
    select azFrozenScope
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "REQUIRED / NOT SELECTED") "AZ Required Frozen Analyze identifies a frozen unselected user"
    azFrozenSelectResult = LunarMaterialIDNormalizerRollout.selectGlobalAZRequiredObjects()
    lmnAssert (azFrozenSelectResult[1] == 1 and azFrozenSelectResult[4] and lmnSelectionContains azFrozenScope and lmnSelectionContains azFrozenRequired) "AZ Required Frozen adds the frozen node without replacing selection"
    lmnAssert azFrozenRequired.isFrozen "AZ Required Frozen preserves frozen state"

    azSharedMatMultiple = lmnMakeMulti #("B_AZ_MULTI_REQUIRED", "A_AZ_MULTI_REQUIRED") #(7,2)
    azMultiScope = lmnMakePoly "AZ_MultiRequired_Scope" azSharedMatMultiple #(7,2,7,2,7,2)
    azMultiRequired1 = lmnMakePoly "AZ_MultiRequired_1" azSharedMatMultiple #(2,7,2,7,2,7)
    azMultiRequired2 = lmnMakePoly "AZ_MultiRequired_2" azSharedMatMultiple #(7,7,2,2,7,2)
    azMultiRequired3 = lmnMakePoly "AZ_MultiRequired_3" azSharedMatMultiple #(2,2,7,7,2,7)
    select azMultiScope
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and (LunarMaterialIDNormalizerRollout.getGlobalAZRequiredUserValues())[1].count == 3) "AZ Required Multiple Analyze stores every external user"
    azMultiSelectResult = LunarMaterialIDNormalizerRollout.selectGlobalAZRequiredObjects()
    lmnAssert (azMultiSelectResult[1] == 3 and azMultiSelectResult[4] and selection.count == 4 and lmnSelectionContains azMultiScope and lmnSelectionContains azMultiRequired1 and lmnSelectionContains azMultiRequired2 and lmnSelectionContains azMultiRequired3) "AZ Required Multiple adds all users in one action without replacing selection"

    azSharedMatUnsupported = lmnMakeMulti #("B_AZ_UNSUPPORTED_REQUIRED", "A_AZ_UNSUPPORTED_REQUIRED") #(6,3)
    azUnsupportedScope = lmnMakePoly "AZ_Unsupported_Scope" azSharedMatUnsupported #(6,3,6,3,6,3)
    azSupportedRequired = lmnMakePoly "AZ_Supported_Required" azSharedMatUnsupported #(3,6,3,6,3,6)
    azUnsupportedRequired = box name:"AZ_Unsupported_Required"
    azUnsupportedRequired.material = azSharedMatUnsupported
    select azUnsupportedScope
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "REQUIRED / UNSUPPORTED GEOMETRY") "AZ Required Unsupported distinguishes unsupported shared geometry"
    azUnsupportedSelectResult = LunarMaterialIDNormalizerRollout.selectGlobalAZRequiredObjects()
    azUnsupportedPreview = LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()
    lmnAssert (azUnsupportedSelectResult[1] == 2 and not azUnsupportedSelectResult[4] and lmnSelectionContains azUnsupportedScope and lmnSelectionContains azSupportedRequired and lmnSelectionContains azUnsupportedRequired) "AZ Required Unsupported adds supported and unsupported external users additively"
    lmnAssert (lmnHasAZConflict azUnsupportedPreview "REQUIRED / UNSUPPORTED GEOMETRY" and not lmnHasAZConflict azUnsupportedPreview "REQUIRED / NOT SELECTED" and (LunarMaterialIDNormalizerRollout.getGlobalAZRequiredUserValues())[1].count == 0) "AZ Required Unsupported remains blocked after automatic re-analysis"
    lmnAssert (not LunarMaterialIDNormalizerRollout.applyGlobalAZReindex() and classOf azUnsupportedRequired.baseObject == Box and azUnsupportedRequired.material == azSharedMatUnsupported) "AZ Required Unsupported cannot bypass fresh Apply safety or modify geometry"

    azSharedMatInvalid = lmnMakeMulti #("B_AZ_INVALID_REQUIRED", "A_AZ_INVALID_REQUIRED") #(10,5)
    azInvalidScope = lmnMakePoly "AZ_Invalid_Scope" azSharedMatInvalid #(10,5,10,5,10,5)
    azInvalidRequired = lmnMakePoly "AZ_Invalid_Required" azSharedMatInvalid #(5,10,5,10,5,10)
    select azInvalidScope
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and (LunarMaterialIDNormalizerRollout.getGlobalAZRequiredUserValues())[1][1] == azInvalidRequired) "AZ Required Invalid Analyze caches the exact required node"
    delete azInvalidRequired
    azInvalidSelectResult = LunarMaterialIDNormalizerRollout.selectGlobalAZRequiredObjects()
    lmnAssert (azInvalidSelectResult[1] == 0 and azInvalidSelectResult[3] == 1 and azInvalidSelectResult[4] and selection.count == 1 and selection[1] == azInvalidScope) "AZ Required Invalid skips a deleted node and completes fresh Analyze safely"

    -- H/I: Different containers are updated independently; single materials are skipped.
    azMatH1 = lmnMakeMulti #("Steel_AZ_H", "Concrete_AZ_H") #(7,2)
    azMatH2 = lmnMakeMulti #("Wood_AZ_H", "Glass_AZ_H") #(12,4)
    azNodeH1 = lmnMakePoly "AZ_Containers_H1" azMatH1 #(7,2,7,2,7,2)
    azNodeH2 = lmnMakePoly "AZ_Containers_H2" azMatH2 #(12,4,12,4,12,4)
    select #(azNodeH1, azNodeH2)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ H Apply supports different Multi/Sub containers"
    lmnAssert (azNodeH1.material == azMatH1 and azNodeH2.material == azMatH2 and azMatH1 != azMatH2 and azMatH1.materialList.count == 2 and azMatH2.materialList.count == 2) "AZ H preserves existing containers and creates no Multi/Sub"

    azMatI = lmnMakeMulti #("B_AZ_I", "A_AZ_I") #(5,6)
    azNodeI = lmnMakePoly "AZ_Multi_I" azMatI #(5,6,5,6,5,6)
    azSingleMaterialI = standardMaterial name:"Single_AZ_I"
    azSingleNodeI = lmnMakePoly "AZ_Single_I" azSingleMaterialI #(1,1,1,1,1,1)
    select #(azNodeI, azSingleNodeI)
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ I Apply skips a single-material object while processing Multi/Sub"
    lmnAssert (azSingleNodeI.material == azSingleMaterialI and classOf azSingleNodeI.material != Multimaterial) "AZ I creates no Multi/Sub for a single-material object"

    -- J/K/L/M: Safety conflicts block without guessing or merging.
    azMatJ = lmnMakeMulti #("A_AZ_J", "B_AZ_J") #(6,6)
    azNodeJ = lmnMakePoly "AZ_DuplicateID_J" azMatJ #(6,6,6,6,6,6)
    select azNodeJ
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "DUPLICATE MATERIAL ID") "AZ J duplicate Material ID blocks Analyze"
    lmnAssert (not LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ J duplicate Material ID blocks Apply"

    azMatK2 = lmnMakeMulti #("A_AZ_K") #(1)
    azNodeK2 = lmnMakePoly "AZ_UndefinedFace_K" azMatK2 #(5,5,5,5,5,5)
    select azNodeK2
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "UNDEFINED FACE MATERIAL ID") "AZ K undefined face Material ID blocks safely"

    azMatL = lmnMakeMulti #("Metal_AZ_L", "metal_AZ_L") #(1,2)
    azNodeL = lmnMakePoly "AZ_DuplicateName_L" azMatL #(1,2,1,2,1,2)
    select azNodeL
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "DUPLICATE MATERIAL NAME IN MULTISUB") "AZ L duplicate case-insensitive name in one Multi/Sub blocks"

    azVRayM = lmnMakeVRay "Conflict_AZ_M"
    azPhysicalM = lmnMakePhysical "conflict_AZ_M"
    azMatM1 = lmnMakeMultiFromRefs #(azVRayM) #(1)
    azMatM2 = lmnMakeMultiFromRefs #(azPhysicalM) #(2)
    azNodeM1 = lmnMakePoly "AZ_ClassConflict_M1" azMatM1 #(1,1,1,1,1,1)
    azNodeM2 = lmnMakePoly "AZ_ClassConflict_M2" azMatM2 #(2,2,2,2,2,2)
    select #(azNodeM1, azNodeM2)
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "CLASS CONFLICT") "AZ M incompatible classes with one case-insensitive name block"

    azColorM1 = standardMaterial name:"Color_AZ_M2" diffuse:(color 20 30 40)
    azColorM2 = standardMaterial name:"color_AZ_M2" diffuse:(color 180 190 200)
    azColorMatM1 = lmnMakeMultiFromRefs #(azColorM1) #(4)
    azColorMatM2 = lmnMakeMultiFromRefs #(azColorM2) #(8)
    azColorNodeM1 = lmnMakePoly "AZ_ColorConflict_M1" azColorMatM1 #(4,4,4,4,4,4)
    azColorNodeM2 = lmnMakePoly "AZ_ColorConflict_M2" azColorMatM2 #(8,8,8,8,8,8)
    select #(azColorNodeM1, azColorNodeM2)
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "COLOR CONFLICT") "AZ M2 incompatible diffuse colors with one case-insensitive name block"

    -- Distinct suffixes are never fuzzy-merged.
    azMatFuzzy = lmnMakeMulti #("Concrete_AZ_Fuzzy", "Concrete_AZ_Fuzzy.001", "Concrete_AZ_Fuzzy_01") #(9,3,7)
    azNodeFuzzy = lmnMakePoly "AZ_NoFuzzy" azMatFuzzy #(9,3,7,9,3,7)
    select azNodeFuzzy
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues())[3].count == 3) "AZ exact key keeps .001 and _01 suffix names distinct"

    -- Empty slots are preserved when safe and block when a face relies on one.
    azMatEmpty = multimaterial numsubs:3
    azEmptyB = standardMaterial name:"B_AZ_Empty"
    azEmptyA = standardMaterial name:"A_AZ_Empty"
    azMatEmpty.materialList[1] = azEmptyB
    azMatEmpty.materialIDList[1] = 7
    azMatEmpty.names[1] = "B_AZ_Empty"
    azMatEmpty.materialList[2] = undefined
    azMatEmpty.materialIDList[2] = 99
    azMatEmpty.names[2] = "EMPTY_KEEP"
    azMatEmpty.materialList[3] = azEmptyA
    azMatEmpty.materialIDList[3] = 2
    azMatEmpty.names[3] = "A_AZ_Empty"
    azNodeEmpty = lmnMakePoly "AZ_EmptySafe" azMatEmpty #(7,2,7,2,7,2)
    select azNodeEmpty
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ safe empty-slot Multi/Sub reindexes"
    lmnAssert (azMatEmpty.materialList.count == 3 and azMatEmpty.materialList[1] == azEmptyA and azMatEmpty.materialList[2] == azEmptyB and azMatEmpty.materialList[3] == undefined and azMatEmpty.materialIDList[3] == 99 and azMatEmpty.names[3] == "EMPTY_KEEP") "AZ preserves a safe empty slot after sorted non-empty slots"

    azMatEmptyFace = multimaterial numsubs:2
    azMatEmptyFace.materialList[1] = standardMaterial name:"A_AZ_EmptyFace"
    azMatEmptyFace.materialIDList[1] = 1
    azMatEmptyFace.materialList[2] = undefined
    azMatEmptyFace.materialIDList[2] = 99
    azNodeEmptyFace = lmnMakePoly "AZ_EmptyFaceBlocked" azMatEmptyFace #(99,99,99,99,99,99)
    select azNodeEmptyFace
    lmnAssert (not LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false and lmnHasAZConflict (LunarMaterialIDNormalizerRollout.getGlobalAZPreviewValues()) "UNDEFINED FACE MATERIAL ID") "AZ blocks a face that uses an empty slot ID"

    -- Distinct mixed material classes are supported without conversion.
    azMixedVRay = lmnMakeVRay "A_AZ_Mixed"
    azMixedPhysical = lmnMakePhysical "B_AZ_Mixed"
    azMixedStandard = standardMaterial name:"C_AZ_Mixed"
    azMixedMat = lmnMakeMultiFromRefs #(azMixedStandard, azMixedVRay, azMixedPhysical) #(7,9,3)
    azMixedNode = lmnMakePoly "AZ_MixedClasses" azMixedMat #(7,9,3,7,9,3)
    select azMixedNode
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ supports distinct VRay, Physical, and Standard sub-material classes"
    lmnAssert (azMixedMat.materialList[1] == azMixedVRay and azMixedMat.materialList[2] == azMixedPhysical and azMixedMat.materialList[3] == azMixedStandard) "AZ mixed-class operation preserves every material reference"

    -- Apply must distrust a stale successful preview and validate live face IDs again.
    azFreshMat = lmnMakeMulti #("B_AZ_Fresh", "A_AZ_Fresh") #(7,2)
    azFreshNode = lmnMakePoly "AZ_FreshValidate" azFreshMat #(7,2,7,2,7,2)
    select azFreshNode
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false) "AZ fresh-validation setup Analyze succeeds"
    polyop.setFaceMatID azFreshNode #{1} 99
    azFreshIDsBefore = for value in azFreshMat.materialIDList collect value
    lmnAssert (not LunarMaterialIDNormalizerRollout.applyGlobalAZReindex() and lmnArrayEquals (for value in azFreshMat.materialIDList collect value) azFreshIDsBefore and polyop.getFaceMatID azFreshNode 1 == 99) "AZ Apply performs fresh Analyze and blocks stale invalid face state without changes"

    -- N/O: A-Z requires no Master/Targets and preserves an existing unrelated scope.
    LunarMaterialIDNormalizerRollout.clearMasterNode()
    LunarMaterialIDNormalizerRollout.clearTargetNodes()
    azMatN = lmnMakeMulti #("B_AZ_N", "A_AZ_N") #(9,4)
    azNodeN = lmnMakePoly "AZ_NoScope_N" azMatN #(9,4,9,4,9,4)
    select azNodeN
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ N works with Master and Targets empty"

    azRegisteredMasterMatO = lmnMakeMulti #("Registered_AZ_O") #(1)
    azRegisteredTargetMatO = lmnMakeMulti #("Registered_AZ_O") #(7)
    azRegisteredMasterO = lmnMakePoly "AZ_Registered_Master_O" azRegisteredMasterMatO #(1,1,1,1,1,1)
    azRegisteredTargetO = lmnMakePoly "AZ_Registered_Target_O" azRegisteredTargetMatO #(7,7,7,7,7,7)
    lmnPrepare azRegisteredMasterO #(azRegisteredTargetO)
    azUnrelatedMatO = lmnMakeMulti #("Z_AZ_O", "Y_AZ_O") #(20,10)
    azUnrelatedO = lmnMakePoly "AZ_Unrelated_O" azUnrelatedMatO #(20,10,20,10,20,10)
    select azUnrelatedO
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ O applies only to current selection while Master/Targets exist"
    lmnAssert (azRegisteredMasterO.material == azRegisteredMasterMatO and azRegisteredTargetO.material == azRegisteredTargetMatO and LunarMaterialIDNormalizerRollout.analyzeAll updateUI:false) "AZ O preserves registered Master/Target state"

    -- P: One Undo restores slots, IDs, names, and face appearance.
    azMatP = lmnMakeMulti #("C_AZ_P", "A_AZ_P", "B_AZ_P") #(9,3,7)
    azMatP.names[1] = "(9)"
    azMatP.names[2] = "(3)"
    azMatP.names[3] = "(7)"
    azNodeP = lmnMakePoly "AZ_Undo_P" azMatP #(9,3,7,9,3,7)
    azOldMaterialsP = for value in azMatP.materialList collect value
    azOldIDsP = for value in azMatP.materialIDList collect value
    azOldNamesP = for value in azMatP.names collect value
    azOldFacesP = lmnFaceIDs azNodeP
    azOldAppearanceP = lmnFaceMaterialRefs azNodeP
    select azNodeP
    clearUndoBuffer()
    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ P Apply succeeds before Undo"
    max undo
    lmnAssert (lmnArrayEquals (for value in azMatP.materialList collect value) azOldMaterialsP and lmnArrayEquals (for value in azMatP.materialIDList collect value) azOldIDsP and lmnArrayEquals (for value in azMatP.names collect value) azOldNamesP) "AZ P One Undo restores Multi/Sub order, IDs, and names"
    lmnAssert (lmnArrayEquals (lmnFaceIDs azNodeP) azOldFacesP and lmnArrayEquals (lmnFaceMaterialRefs azNodeP) azOldAppearanceP) "AZ P One Undo restores face IDs and appearance"

    -- MK2 report sections are optional, UTF-8, loadable, and face dumps remain absent.
    azReportPath = "C:\\tmp\\lmn-mk2-az-report.txt"
    try (deleteFile azReportPath) catch()
    select azNodeA
    lmnAssert (LunarMaterialIDNormalizerRollout.analyzeGlobalAZ updateUI:false recordOperation:true) "AZ Report Analyze succeeds"
    lmnAssert (LunarMaterialIDNormalizerRollout.exportReportToPath azReportPath) "AZ Report UTF-8 export succeeds"
    azReportText = (dotNetClass "System.IO.File").ReadAllText azReportPath
    lmnAssert ((findString azReportText "Last Operation: GLOBAL A-Z ANALYZE") != undefined and (findString azReportText "[GLOBAL A-Z REINDEX]") != undefined and (findString azReportText "[PER OBJECT A-Z REMAP]") != undefined) "AZ Report contains operation and optional MK2 sections"
    azParsedReport = LunarMaterialIDNormalizerRollout.parseReportText azReportText
    lmnAssert (azParsedReport[1] and azParsedReport[3][15][3].count == 4 and azParsedReport[3][16].count == 1) "AZ Report loader parses optional Global and per-object sections"

    lmnAssert (LunarMaterialIDNormalizerRollout.applyGlobalAZReindex()) "AZ Report Apply produces a reindex operation snapshot"
    lmnAssert (LunarMaterialIDNormalizerRollout.exportReportToPath azReportPath) "AZ Reindex Report export succeeds"
    azReindexReportText = (dotNetClass "System.IO.File").ReadAllText azReportPath
    lmnAssert ((findString azReindexReportText "Last Operation: GLOBAL A-Z REINDEX") != undefined and (findString azReindexReportText "REINDEXED") != undefined) "AZ Reindex Report records operation and REINDEXED status"
    try (deleteFile azReportPath) catch()
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
