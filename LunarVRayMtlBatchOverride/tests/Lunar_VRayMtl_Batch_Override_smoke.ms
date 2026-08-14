/* Automated smoke/acceptance tests for Lunar VRayMtl Batch Override. */

global LVMBO_TEST_PASSED = 0
global LVMBO_TEST_FAILED = 0
global LVMBO_TEST_REPORT = "C:\\tmp\\lvmbo-smoke-report.txt"
global LunarVRayMtlBatchOverrideRollout
global LunarVRayMtlBatchOverrideCore

fn lvmboTestWrite textValue =
(
    local stream = openFile LVMBO_TEST_REPORT mode:"a"
    format "%\n" textValue to:stream
    close stream
)

fn lvmboAssert condition label =
(
    if condition then
    (
        LVMBO_TEST_PASSED += 1
        lvmboTestWrite ("PASS: " + label)
    )
    else
    (
        LVMBO_TEST_FAILED += 1
        lvmboTestWrite ("FAIL: " + label)
    )
)

fn lvmboColorsEqual leftColor rightColor =
(
    leftColor != undefined and rightColor != undefined and
    (abs (leftColor.r - rightColor.r)) <= 0.01 and
    (abs (leftColor.g - rightColor.g)) <= 0.01 and
    (abs (leftColor.b - rightColor.b)) <= 0.01
)

fn lvmboFloatEqual leftValue rightValue =
(
    (abs (leftValue - rightValue)) <= 0.0001
)

fn lvmboMakeVRay materialName =
(
    local materialValue = execute "VRayMtl()"
    materialValue.name = materialName
    materialValue
)

try (deleteFile LVMBO_TEST_REPORT) catch()
lvmboTestWrite "Lunar VRayMtl Batch Override smoke test"

try
(
    resetMaxFile #noPrompt
    fileIn "C:\\Users\\user\\Documents\\MAXSCRIPT\\LunarVRayMtlBatchOverride\\src\\Lunar_VRayMtl_Batch_Override.ms"

    lvmboAssert (LunarVRayMtlBatchOverrideCore != undefined) "Script loads and core exists"
    lvmboAssert (LunarVRayMtlBatchOverrideRollout != undefined) "Rollout exists"
    lvmboAssert (LunarVRayMtlBatchOverrideCore.vrayClassIsAvailable()) "VRayMtl class is available"

    propertyProbe = lvmboMakeVRay "Property_Probe"
    verifiedProperties = #(
        #Diffuse, #Reflection, #reflection_glossiness, #brdf_useRoughness,
        #reflection_metalness, #Refraction, #refraction_glossiness,
        #texmap_diffuse, #texmap_diffuse_on,
        #texmap_reflection, #texmap_reflection_on,
        #texmap_reflectionGlossiness, #texmap_reflectionGlossiness_on,
        #texmap_metalness, #texmap_metalness_on,
        #texmap_refraction, #texmap_refraction_on,
        #texmap_refractionGlossiness, #texmap_refractionGlossiness_on
    )
    allVerifiedPropertiesExist = true
    for propertyName in verifiedProperties while allVerifiedPropertiesExist do
        if not isProperty propertyProbe propertyName do allVerifiedPropertiesExist = false
    lvmboAssert allVerifiedPropertiesExist "Installed VRayMtl exposes every supported value/map property"
    lvmboAssert (LunarVRayMtlBatchOverrideCore.resolveProperty propertyProbe "Diffuse" == #Diffuse) "String candidate normalizes to a supported Name property"
    lvmboAssert (LunarVRayMtlBatchOverrideCore.resolveProperty propertyProbe #Diffuse == #Diffuse) "Name candidate resolves through isProperty"

    directOldDiffuse = getProperty propertyProbe #Diffuse
    setProperty propertyProbe #Diffuse (color 123 45 67)
    directNewDiffuse = getProperty propertyProbe #Diffuse
    setProperty propertyProbe #Diffuse directOldDiffuse
    lvmboAssert (lvmboColorsEqual directNewDiffuse (color 123 45 67) and lvmboColorsEqual (getProperty propertyProbe #Diffuse) directOldDiffuse) "Direct Diffuse set/get succeeds and restores the old value"

    defaultSettings = LunarVRayMtlBatchOverrideCore.newSettings()
    lvmboAssert (not LunarVRayMtlBatchOverrideCore.hasAnyOverride defaultSettings) "All overrides are OFF by default"
    lvmboAssert (defaultSettings.mapMode == #keep) "Keep Existing Maps is the default"
    lvmboAssert (LunarVRayMtlBatchOverrideCore.validateSettings defaultSettings == "") "Default settings validate"

    -- Acceptance I: duplicate SME references are reduced to one target instance.
    materialI = lvmboMakeVRay "Acceptance_I_Shared"
    uniqueResultI = LunarVRayMtlBatchOverrideCore.collectUniqueVRayMaterials #(materialI, materialI, materialI)
    lvmboAssert (uniqueResultI.selectedNodeCount == 3 and uniqueResultI.materials.count == 1 and uniqueResultI.duplicateNodeCount == 2) "I three shared-reference nodes produce one unique VRayMtl target"

    -- Acceptance B: only Reflection Surface changes.
    materialB = lvmboMakeVRay "Acceptance_B"
    materialB.Diffuse = color 11 22 33
    materialB.Reflection = color 44 55 66
    materialB.reflection_metalness = 0.37
    materialB.Refraction = color 77 88 99
    materialB.refraction_glossiness = 0.29
    settingsB = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsB.surfaceEnabled = true
    settingsB.surfaceMode = #glossiness
    settingsB.surfaceValue = 0.65
    resultB = LunarVRayMtlBatchOverrideCore.applyOverrides #(materialB) settingsB
    lvmboAssert (lvmboFloatEqual materialB.reflection_glossiness 0.65 and materialB.brdf_useRoughness == false) "B applies Glossiness 0.65 with glossiness mode"
    lvmboAssert (lvmboColorsEqual materialB.Diffuse (color 11 22 33) and lvmboColorsEqual materialB.Reflection (color 44 55 66)) "B preserves unchecked diffuse and reflection color"
    lvmboAssert (lvmboFloatEqual materialB.reflection_metalness 0.37 and lvmboColorsEqual materialB.Refraction (color 77 88 99) and lvmboFloatEqual materialB.refraction_glossiness 0.29) "B preserves unchecked metalness and refraction parameters"
    lvmboAssert ((LunarVRayMtlBatchOverrideCore.findResultRow resultB.rows #surface)[2] == 1) "B reports one Surface success"

    -- Acceptance C: exactly three enabled parameters change.
    materialC1 = lvmboMakeVRay "Acceptance_C1"
    materialC2 = lvmboMakeVRay "Acceptance_C2"
    materialC1.Reflection = color 12 13 14
    materialC2.Reflection = color 15 16 17
    materialC1.Refraction = color 18 19 20
    materialC2.Refraction = color 21 22 23
    settingsC = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsC.baseColorEnabled = true
    settingsC.baseColor = color 160 160 160
    settingsC.surfaceEnabled = true
    settingsC.surfaceMode = #glossiness
    settingsC.surfaceValue = 0.75
    settingsC.metalnessEnabled = true
    settingsC.metalnessValue = 0.2
    resultC = LunarVRayMtlBatchOverrideCore.applyOverrides #(materialC1, materialC2) settingsC
    lvmboAssert (lvmboColorsEqual materialC1.Diffuse (color 160 160 160) and lvmboColorsEqual materialC2.Diffuse (color 160 160 160)) "C applies Base Color to both materials"
    lvmboAssert (lvmboFloatEqual materialC1.reflection_glossiness 0.75 and lvmboFloatEqual materialC2.reflection_glossiness 0.75) "C applies Reflection Glossiness to both materials"
    lvmboAssert (lvmboFloatEqual materialC1.reflection_metalness 0.2 and lvmboFloatEqual materialC2.reflection_metalness 0.2) "C applies Metalness to both materials"
    lvmboAssert (lvmboColorsEqual materialC1.Reflection (color 12 13 14) and lvmboColorsEqual materialC2.Reflection (color 15 16 17) and lvmboColorsEqual materialC1.Refraction (color 18 19 20) and lvmboColorsEqual materialC2.Refraction (color 21 22 23)) "C preserves unchecked reflection and refraction colors"

    -- Acceptance D: direct roughness semantics, no arbitrary inversion.
    materialD = lvmboMakeVRay "Acceptance_D"
    settingsD = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsD.surfaceEnabled = true
    settingsD.surfaceMode = #roughness
    settingsD.surfaceValue = 0.4
    LunarVRayMtlBatchOverrideCore.applyOverrides #(materialD) settingsD
    lvmboAssert (materialD.brdf_useRoughness == true and lvmboFloatEqual materialD.reflection_glossiness 0.4) "D stores Roughness 0.40 directly with V-Ray roughness mode enabled"

    -- Acceptance E: Keep leaves reference and enable state untouched.
    materialE = lvmboMakeVRay "Acceptance_E"
    mapE = checker name:"Surface_Map_E"
    materialE.texmap_reflectionGlossiness = mapE
    materialE.texmap_reflectionGlossiness_on = true
    settingsE = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsE.surfaceEnabled = true
    settingsE.surfaceMode = #glossiness
    settingsE.surfaceValue = 0.5
    settingsE.mapMode = #keep
    LunarVRayMtlBatchOverrideCore.applyOverrides #(materialE) settingsE
    lvmboAssert (materialE.texmap_reflectionGlossiness == mapE and materialE.texmap_reflectionGlossiness_on == true) "E Keep preserves affected map reference and enable state"

    -- Acceptance F: Disable affects only the checked parameter's map.
    materialF = lvmboMakeVRay "Acceptance_F"
    surfaceMapF = checker name:"Surface_Map_F"
    diffuseMapF = checker name:"Diffuse_Map_F"
    materialF.texmap_reflectionGlossiness = surfaceMapF
    materialF.texmap_reflectionGlossiness_on = true
    materialF.texmap_diffuse = diffuseMapF
    materialF.texmap_diffuse_on = true
    settingsF = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsF.surfaceEnabled = true
    settingsF.surfaceMode = #glossiness
    settingsF.surfaceValue = 0.55
    settingsF.mapMode = #disable
    resultF = LunarVRayMtlBatchOverrideCore.applyOverrides #(materialF) settingsF
    lvmboAssert (materialF.texmap_reflectionGlossiness == surfaceMapF and materialF.texmap_reflectionGlossiness_on == false) "F Disable preserves affected map reference and disables it"
    lvmboAssert (materialF.texmap_diffuse == diffuseMapF and materialF.texmap_diffuse_on == true) "F Disable leaves unchecked diffuse map untouched"
    lvmboAssert ((LunarVRayMtlBatchOverrideCore.findResultRow resultF.rows #surface)[5] == 1) "F reports one disabled map"

    -- Acceptance G: Remove affects only the checked parameter's map.
    materialG = lvmboMakeVRay "Acceptance_G"
    surfaceMapG = checker name:"Surface_Map_G"
    diffuseMapG = checker name:"Diffuse_Map_G"
    materialG.texmap_reflectionGlossiness = surfaceMapG
    materialG.texmap_diffuse = diffuseMapG
    settingsG = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsG.surfaceEnabled = true
    settingsG.surfaceMode = #glossiness
    settingsG.surfaceValue = 0.6
    settingsG.mapMode = #remove
    resultG = LunarVRayMtlBatchOverrideCore.applyOverrides #(materialG) settingsG
    lvmboAssert (materialG.texmap_reflectionGlossiness == undefined) "G Remove clears the affected map reference"
    lvmboAssert (materialG.texmap_diffuse == diffuseMapG) "G Remove leaves unchecked diffuse map reference untouched"
    lvmboAssert ((LunarVRayMtlBatchOverrideCore.findResultRow resultG.rows #surface)[6] == 1) "G reports one removed map"

    -- Refraction Glossiness stores the explicit user value and preserves mode.
    materialRefGloss = lvmboMakeVRay "Refraction_Glossiness_Semantics"
    materialRefGloss.brdf_useRoughness = true
    settingsRefGloss = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsRefGloss.refractionGlossinessEnabled = true
    settingsRefGloss.refractionGlossinessValue = 0.7
    LunarVRayMtlBatchOverrideCore.applyOverrides #(materialRefGloss) settingsRefGloss
    lvmboAssert (materialRefGloss.brdf_useRoughness == true and lvmboFloatEqual materialRefGloss.refraction_glossiness 0.7) "Refraction Glossiness 0.70 is stored directly while the existing mode remains unchanged"

    -- Acceptance J: no override means no value or map change.
    materialJ = lvmboMakeVRay "Acceptance_J"
    mapJ = checker name:"No_Override_Map_J"
    materialJ.Diffuse = color 91 92 93
    materialJ.reflection_glossiness = 0.46
    materialJ.texmap_diffuse = mapJ
    defaultApplyResult = LunarVRayMtlBatchOverrideCore.applyOverrides #(materialJ) defaultSettings
    lvmboAssert (lvmboColorsEqual materialJ.Diffuse (color 91 92 93) and lvmboFloatEqual materialJ.reflection_glossiness 0.46 and materialJ.texmap_diffuse == mapJ) "J all overrides OFF leaves values and maps unchanged"
    lvmboAssert ((LunarVRayMtlBatchOverrideCore.findResultRow defaultApplyResult.rows #baseColor)[2] == 0) "J all overrides OFF reports no parameter success"

    -- Acceptance K: non-VRay inputs are protected even if they reach the reusable core directly.
    physicalProtected = execute "PhysicalMaterial()"
    physicalOldColor = physicalProtected.base_color
    standardProtected = standardMaterial name:"Protected_Standard"
    standardOldDiffuse = standardProtected.diffuse
    mapProtected = checker name:"Protected_Map"
    settingsProtected = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsProtected.baseColorEnabled = true
    settingsProtected.baseColor = color 1 2 3
    resultProtected = LunarVRayMtlBatchOverrideCore.applyOverrides #(physicalProtected, standardProtected, mapProtected) settingsProtected
    lvmboAssert (lvmboColorsEqual physicalProtected.base_color physicalOldColor and lvmboColorsEqual standardProtected.diffuse standardOldDiffuse and resultProtected.skippedMaterials == 3) "K Physical, Standard, and Map inputs are skipped and unchanged"

    -- Acceptance H: one undo restores a 50-material batch and a removed map.
    materialsH = #()
    originalColorsH = #()
    for materialIndexH = 1 to 50 do
    (
        materialH = lvmboMakeVRay ("Acceptance_H_" + (materialIndexH as string))
        originalColorH = color materialIndexH (materialIndexH * 2) (materialIndexH * 3)
        materialH.Diffuse = originalColorH
        append materialsH materialH
        append originalColorsH originalColorH
    )
    mapH = checker name:"Undo_Map_H"
    materialsH[1].texmap_diffuse = mapH
    settingsH = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsH.baseColorEnabled = true
    settingsH.baseColor = color 200 200 200
    settingsH.mapMode = #remove
    undo "VRayMtl Batch Override Test" on
    (
        LunarVRayMtlBatchOverrideCore.applyOverrides materialsH settingsH
    )
    changedBeforeUndoH = materialsH[1].texmap_diffuse == undefined
    for materialH in materialsH while changedBeforeUndoH do
        if not lvmboColorsEqual materialH.Diffuse (color 200 200 200) do changedBeforeUndoH = false
    max undo
    restoredAfterUndoH = materialsH[1].texmap_diffuse == mapH
    for materialIndexH = 1 to materialsH.count while restoredAfterUndoH do
        if not lvmboColorsEqual materialsH[materialIndexH].Diffuse originalColorsH[materialIndexH] do restoredAfterUndoH = false
    lvmboAssert changedBeforeUndoH "H all 50 materials changed before Undo"
    lvmboAssert restoredAfterUndoH "H one Undo restores all 50 materials and the removed map"

    -- Official SME API selection test in a disposable view.
    smeTestSucceeded = false
    smeTestViewIndex = 0
    try
    (
        sme.Open()
        smeTestViewIndex = sme.CreateView "LVMBO_Automated_Selection_Test"
        sme.activeView = smeTestViewIndex
        smeTestView = sme.GetView smeTestViewIndex
        smeVRayA = lvmboMakeVRay "SME_VRay_A"
        smeVRayB = lvmboMakeVRay "SME_VRay_B"
        smePhysical = execute "PhysicalMaterial()"
        smeMap = checker name:"SME_Map"
        smePosition = [0,0]
        smeTestView.CreateNode smeVRayA smePosition
        smePosition = [220,0]
        smeTestView.CreateNode smePhysical smePosition
        smePosition = [440,0]
        smeTestView.CreateNode smeMap smePosition
        smePosition = [660,0]
        smeTestView.CreateNode smeVRayB smePosition
        smeTestView.SetSelectedNodes #(smeVRayA, smePhysical, smeMap, smeVRayB)
        smeSelectionResult = LunarVRayMtlBatchOverrideCore.getSMESelection()
        smeTestSucceeded = smeSelectionResult.ok and smeSelectionResult.selectedNodeCount == 4 and smeSelectionResult.materials.count == 2 and smeSelectionResult.skippedNodeCount == 2
    )
    catch (smeTestSucceeded = false)
    if smeTestViewIndex > 0 do try (sme.DeleteView smeTestViewIndex false) catch()
    try (sme.Close()) catch()
    lvmboAssert smeTestSucceeded "A official SME active-view selection returns 4 nodes, 2 VRayMtl, and 2 skipped"

    -- UI safety defaults and control linkage at load.
    lvmboAssert (not LunarVRayMtlBatchOverrideRollout.chkBaseColor.checked and not LunarVRayMtlBatchOverrideRollout.chkSurface.checked and not LunarVRayMtlBatchOverrideRollout.chkMetalness.checked) "UI override checkboxes load OFF"
    lvmboAssert (LunarVRayMtlBatchOverrideRollout.rbMapMode.state == 1) "UI Map Handling loads as Keep"
    lvmboAssert (not LunarVRayMtlBatchOverrideRollout.cpBaseColor.enabled and not LunarVRayMtlBatchOverrideRollout.rbSurfaceMode.enabled and not LunarVRayMtlBatchOverrideRollout.spnMetalness.enabled) "UI value controls load disabled while overrides are OFF"
)
catch
(
    LVMBO_TEST_FAILED += 1
    lvmboTestWrite ("FATAL: " + (getCurrentException() as string))
)

lvmboTestWrite ("Passed: " + (LVMBO_TEST_PASSED as string))
lvmboTestWrite ("Failed: " + (LVMBO_TEST_FAILED as string))

try (destroyDialog LunarVRayMtlBatchOverrideRollout) catch()
quitMAX #noPrompt
