/*
    Lunar Material ID Normalizer
    Autodesk 3ds Max 2026 / MAXScript

    Purpose:
    - Normalize Editable Poly face Material IDs to one Master Multi/Sub-Object material.
    - Match sub-materials by exact, case-sensitive material name.
    - Preserve existing Master IDs and append missing material references after max ID.
    - Analyze without scene changes; Apply in one undo block.
    - MK2 adds an independent, selection-scoped Global A-Z Multi/Sub and face-ID reindex workflow.
*/

global LunarMaterialIDNormalizerRollout

if LunarMaterialIDNormalizerRollout != undefined do
(
    try (destroyDialog LunarMaterialIDNormalizerRollout) catch()
)

rollout LunarMaterialIDNormalizerRollout "Lunar Material ID Normalizer MK2" width:760 height:1040
(
    groupBox gbPreprocess "PREPROCESS" pos:[8,8] width:744 height:166
    checkbox chkConvertUSD "Convert USD Preview Surface to VRayMtl" pos:[20,30] width:330 height:20 checked:true
    checkbox chkOverrideGlossiness "Override Glossiness" pos:[20,62] width:180 height:20 checked:true
    spinner spnGlossiness "Glossiness:" pos:[210,60] width:150 height:20 range:[0.0,1.0,0.8] type:#float scale:0.01 fieldwidth:60
    checkbox chkOverrideReflection "Override Reflection" pos:[390,62] width:170 height:20 checked:true
    colorPicker cpReflection "Reflection:" pos:[570,58] width:166 height:24 color:(color 255 255 255)
    checkbox chkSyncSlotNames "Sync Multi/Sub Slot Names" pos:[20,92] width:250 height:20 checked:true
    button btnConvertOnly "Convert Materials Only" pos:[520,88] width:216 height:30
    label lblPreprocessHint "Constant diffuse only. Texture networks, roughness, metallic, opacity, emission, normal and displacement are ignored." pos:[20,132] width:710 height:18

    groupBox gbMaster "MASTER" pos:[8,182] width:744 height:68
    label lblMaster "Master Object: Not set" pos:[20,204] width:450 height:18
    button btnSetMaster "Set Master" pos:[520,200] width:104 height:28
    button btnClearMaster "Clear Master" pos:[632,200] width:104 height:28

    groupBox gbTargets "TARGETS" pos:[8,256] width:278 height:300
    multiListBox lbTargets "" pos:[18,278] width:258 height:12
    button btnAddTargets "Add Selected Targets" pos:[18,502] width:124 height:28
    button btnRemoveTargets "Remove Selected" pos:[148,502] width:128 height:28
    button btnClearTargets "Clear Targets" pos:[18,536] width:258 height:24

    groupBox gbCanonical "CANONICAL MATERIAL TABLE" pos:[294,256] width:458 height:300
    dotNetControl lvCanonical "System.Windows.Forms.ListView" pos:[304,278] width:438 height:268

    groupBox gbPreview "TARGET REMAP PREVIEW" pos:[8,564] width:744 height:294
    label lblPreviewTarget "Target: Select one target from the list" pos:[20,586] width:710 height:18
    dotNetControl lvRemap "System.Windows.Forms.ListView" pos:[18,608] width:724 height:240

    button btnAnalyze "Analyze" pos:[8,868] width:240 height:36
    button btnApply "Normalize / Apply" pos:[260,868] width:240 height:36
    button btnExportReport "Export Report..." pos:[512,868] width:240 height:36
    checkbox chkAutoExport "Auto Export After Operation" pos:[10,912] width:250 height:20 checked:false
    button btnOpenGlobalAZ "Global A-Z Reindex..." pos:[270,912] width:230 height:30
    button btnLoadReport "Load Report..." pos:[512,912] width:240 height:30

    label lblSummary "MASTER: None | Targets: 0 | Materials: 0 | Matched: 0 | Pending Append: 0" pos:[10,950] width:740 height:18
    label lblConversionSummary "USD: 0 | Existing VRay: 0 | Unsupported: 0 | Texture Ignored: 0 | Conflicts: 0" pos:[10,972] width:740 height:18
    label lblStatus "Status: Ready" pos:[10,994] width:740 height:28

    local DEBUG_MODE = false
    local masterNode = undefined
    local targetNodes = #()
    local canonicalRows = #()
    local targetAnalyses = #()
    local analysisReady = false
    local analysisHasConflict = false
    local matchedCount = 0
    local pendingCount = 0
    local scopedMaterials = #()
    local conversionPlan = #()
    local conversionCache = #()
    local diffuseConflictNames = #()
    local classConflictNames = #()
    local usdMaterialCount = 0
    local existingVRayCount = 0
    local unsupportedMaterialCount = 0
    local textureIgnoredCount = 0
    local preprocessConflictCount = 0
    local classConflictCount = 0
    local preprocessErrorText = ""
    local lastApplyConvertedCount = 0
    local lastApplyAppendedCount = 0
    local lastSkippedCount = 0
    local lastSyncedSlotCount = 0
    local lastOperation = #none
    local lastConversionRows = #()
    local lastAppendedRows = #()
    local lastTextureIgnoredNames = #()
    local lastReportPath = ""
    local lastConvertOnlyNodeNames = #()
    local lastConvertOnlyMaterialCount = 0
    local lastConvertOnlyUSDCount = 0
    local lastConvertOnlyExistingVRayCount = 0
    local lastConvertOnlyUnsupportedCount = 0
    local lastConvertOnlySkippedCount = 0
    local lastConvertOnlyUnsupportedRows = #()
    local loadedReport = undefined
    local loadedReportForm = undefined
    local loadedReportTargetList = undefined
    local loadedReportAZTargetList = undefined
    local globalAZForm = undefined
    local globalAZControls = undefined
    local globalAZSelectionNodes = #()
    local globalAZRegistryRows = #()
    local globalAZMaterialAnalyses = #()
    local globalAZObjectAnalyses = #()
    local globalAZConflictRows = #()
    local globalAZSkippedRows = #()
    local globalAZAnalysisReady = false
    local lastGlobalAZSelectedNames = #()
    local lastGlobalAZRegistryRows = #()
    local lastGlobalAZObjectRows = #()
    local lastGlobalAZConflictRows = #()

    /*
        Canonical row:
        #(materialID, materialName, materialReference, sourceText, state, sourceNode, slotIndex,
          rawClass, effectiveClass, diffuseInfo)

        Target analysis:
        #(node, overallStatus, detailText, remapRows, isApplicable)

        Remap row:
        #(oldID, materialName, newID, state, materialReference, rawClass, effectiveClass, diffuseInfo)
    */

    fn lmnLog level message =
    (
        if level != "DEBUG" or DEBUG_MODE do
            format "[LMN][%] %\n" level message
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

    fn isValidStoredNode nodeValue =
    (
        nodeValue != undefined and isValidNode nodeValue
    )

    fn isMultiMaterial materialValue =
    (
        materialValue != undefined and classOf materialValue == Multimaterial
    )

    fn isEditablePolyNode nodeValue =
    (
        local supported = false
        if isValidStoredNode nodeValue do
        (
            try (supported = classOf nodeValue.baseObject == Editable_Poly) catch (supported = false)
        )
        supported
    )

    fn exactNameEquals leftName rightName =
    (
        leftName != undefined and rightName != undefined and (leftName as string) == (rightName as string)
    )

    fn safeMaterialName materialValue =
    (
        if materialValue == undefined then "" else materialValue.name as string
    )

    /* USD Preview Surface -> VRayMtl preprocess layer.
       Property names below were verified in the installed 3ds Max 2026 / USD / V-Ray build. */

    fn materialClassText materialValue =
    (
        if materialValue == undefined then "Undefined" else classOf materialValue as string
    )

    fn effectiveMaterialClassText materialValue =
    (
        if materialValue != undefined and materialClassText materialValue == "MaxUsdPreviewSurface" and chkConvertUSD.checked then
            "VRayMtl"
        else
            materialClassText materialValue
    )

    fn isUSDPreviewMaterial materialValue =
    (
        materialValue != undefined and materialClassText materialValue == "MaxUsdPreviewSurface"
    )

    fn isVRayMaterial materialValue =
    (
        materialValue != undefined and materialClassText materialValue == "VRayMtl"
    )

    fn materialHasTextureDrivenDiffuse materialValue =
    (
        isUSDPreviewMaterial materialValue and
            isProperty materialValue #diffuseColor_map and
            getProperty materialValue #diffuseColor_map != undefined
    )

    fn readComparableDiffuse materialValue =
    (
        if isUSDPreviewMaterial materialValue and isProperty materialValue #diffuseColor then
            #(true, getProperty materialValue #diffuseColor)
        else if isVRayMaterial materialValue and isProperty materialValue #Diffuse then
            #(true, getProperty materialValue #Diffuse)
        else if materialValue != undefined and isProperty materialValue #diffuse then
            #(true, getProperty materialValue #diffuse)
        else
            #(false, undefined)
    )

    fn diffuseColorsEqual leftColor rightColor =
    (
        leftColor != undefined and rightColor != undefined and
        (abs (leftColor.r - rightColor.r)) <= 0.01 and
        (abs (leftColor.g - rightColor.g)) <= 0.01 and
        (abs (leftColor.b - rightColor.b)) <= 0.01
    )

    fn appendUniqueMaterial materialArray materialValue =
    (
        if materialValue != undefined and (findItem materialArray materialValue) == 0 do
            append materialArray materialValue
        materialArray
    )

    fn collectFromTopMaterial topMaterial =
    (
        if topMaterial != undefined do
        (
            if isMultiMaterial topMaterial then
            (
                for subMaterial in topMaterial.materialList where subMaterial != undefined do
                    appendUniqueMaterial scopedMaterials subMaterial
            )
            else
                appendUniqueMaterial scopedMaterials topMaterial
        )
    )

    fn collectScopedMaterials =
    (
        scopedMaterials = #()
        if isValidStoredNode masterNode do collectFromTopMaterial masterNode.material
        for nodeValue in targetNodes where isValidStoredNode nodeValue do
            collectFromTopMaterial nodeValue.material
        scopedMaterials
    )

    fn collectMaterialsFromNodes nodeValues =
    (
        scopedMaterials = #()
        for nodeValue in nodeValues where isValidStoredNode nodeValue do
            collectFromTopMaterial nodeValue.material
        scopedMaterials
    )

    fn vrayClassIsAvailable =
    (
        local available = false
        for classValue in material.classes while not available do
        (
            if (classValue as string) == "VRayMtl" do available = true
        )
        available
    )

    fn isDiffuseConflictName materialName =
    (
        local found = false
        for conflictName in diffuseConflictNames while not found do
            if exactNameEquals conflictName materialName do found = true
        found
    )

    fn isClassConflictName materialName =
    (
        local found = false
        for conflictName in classConflictNames while not found do
            if exactNameEquals conflictName materialName do found = true
        found
    )

    fn analyzePreprocess scopeNodes:undefined =
    (
        conversionPlan = #()
        diffuseConflictNames = #()
        classConflictNames = #()
        usdMaterialCount = 0
        existingVRayCount = 0
        unsupportedMaterialCount = 0
        textureIgnoredCount = 0
        preprocessConflictCount = 0
        classConflictCount = 0
        preprocessErrorText = ""
        if scopeNodes == undefined then
            collectScopedMaterials()
        else
            collectMaterialsFromNodes scopeNodes

        for materialValue in scopedMaterials do
        (
            if isUSDPreviewMaterial materialValue then
            (
                usdMaterialCount += 1
                if chkConvertUSD.checked do append conversionPlan materialValue
                if materialHasTextureDrivenDiffuse materialValue do textureIgnoredCount += 1
            )
            else if isVRayMaterial materialValue then
                existingVRayCount += 1
            else
                unsupportedMaterialCount += 1
        )

        if scopedMaterials.count > 1 do
        (
            for leftIndex = 1 to (scopedMaterials.count - 1) do
            (
                local leftMaterial = scopedMaterials[leftIndex]
                local leftName = safeMaterialName leftMaterial
                local leftDiffuse = readComparableDiffuse leftMaterial
                local leftEffectiveClass = effectiveMaterialClassText leftMaterial

                for rightIndex = (leftIndex + 1) to scopedMaterials.count do
                (
                    local rightMaterial = scopedMaterials[rightIndex]
                    if exactNameEquals leftName (safeMaterialName rightMaterial) do
                    (
                        local rightEffectiveClass = effectiveMaterialClassText rightMaterial
                        if leftEffectiveClass != rightEffectiveClass then
                        (
                            if not isClassConflictName leftName do append classConflictNames leftName
                        )
                        else
                        (
                            local rightDiffuse = readComparableDiffuse rightMaterial
                            if leftDiffuse[1] and rightDiffuse[1] and not diffuseColorsEqual leftDiffuse[2] rightDiffuse[2] do
                            (
                                if not isDiffuseConflictName leftName do append diffuseConflictNames leftName
                            )
                        )
                    )
                )
            )
        )

        preprocessConflictCount = diffuseConflictNames.count
        classConflictCount = classConflictNames.count

        if chkConvertUSD.checked and usdMaterialCount > 0 and not vrayClassIsAvailable() then
        (
            preprocessErrorText = "ERROR: VRayMtl class is not available. USD conversion cancelled. Scene was not changed."
            setStatus preprocessErrorText
            false
        )
        else if classConflictCount > 0 then
        (
            setStatus ("CLASS CONFLICT: " + (classConflictCount as string) + " material name(s) have different effective classes.")
            false
        )
        else if preprocessConflictCount > 0 then
        (
            setStatus ("CONFLICT: " + (preprocessConflictCount as string) + " material name(s) have different diffuse colors.")
            false
        )
        else true
    )

    fn preprocessMaterialTypeText materialValue =
    (
        if isUSDPreviewMaterial materialValue then
        (
            if chkConvertUSD.checked then "USD -> VRAY" else "USD / KEEP"
        )
        else if isVRayMaterial materialValue then
            "VRAY"
        else
            "UNSUPPORTED"
    )

    fn canonicalStatusText rowValue =
    (
        local result = rowValue[4]
        local materialValue = rowValue[3]
        if isClassConflictName rowValue[2] then
            result = "CLASS CONFLICT : SAME NAME / DIFFERENT EFFECTIVE CLASS"
        else if isDiffuseConflictName rowValue[2] then
            result = "COLOR CONFLICT : SAME NAME / DIFFERENT DIFFUSE"
        else if materialHasTextureDrivenDiffuse materialValue then
            result += " / TEXTURE IGNORED"
        else if isVRayMaterial materialValue then
            result += " / KEEP"
        else if materialValue != undefined and not isUSDPreviewMaterial materialValue then
            result += " / KEEP"
        result
    )

    fn remapStatusText remapRow =
    (
        local materialValue = remapRow[5]
        local prefix = preprocessMaterialTypeText materialValue
        local result = prefix + " / " + remapRow[4]
        if materialHasTextureDrivenDiffuse materialValue do result += " / TEXTURE IGNORED"
        if isClassConflictName remapRow[2] then
            result = "CLASS CONFLICT"
        else if isDiffuseConflictName remapRow[2] do
            result = "COLOR CONFLICT"
        result
    )

    fn validatePreprocessOptions =
    (
        if spnGlossiness.value < 0.0 or spnGlossiness.value > 1.0 then
            #(false, "Glossiness must be between 0.0 and 1.0.")
        else if chkConvertUSD.checked and usdMaterialCount > 0 and not vrayClassIsAvailable() then
            #(false, "ERROR: VRayMtl class is not available. USD conversion cancelled.")
        else
        (
            local probeMaterial = undefined
            if chkConvertUSD.checked and usdMaterialCount > 0 do
            (
                try (probeMaterial = execute "VRayMtl()") catch()
            )

            if chkConvertUSD.checked and usdMaterialCount > 0 and probeMaterial == undefined then
                #(false, "ERROR: VRayMtl could not be created. USD conversion cancelled.")
            else if probeMaterial != undefined and not isProperty probeMaterial #Diffuse then
                #(false, "ERROR: VRayMtl.Diffuse is unavailable in this V-Ray build.")
            else if probeMaterial != undefined and chkOverrideGlossiness.checked and
                (not isProperty probeMaterial #reflection_glossiness or not isProperty probeMaterial #brdf_useRoughness) then
                #(false, "ERROR: Safe Glossiness override properties are unavailable in this V-Ray build.")
            else if probeMaterial != undefined and chkOverrideReflection.checked and not isProperty probeMaterial #Reflection then
                #(false, "ERROR: VRayMtl.Reflection is unavailable in this V-Ray build.")
            else
                #(true, "")
        )
    )

    fn findConvertedMaterial originalMaterial =
    (
        local converted = undefined
        for cacheRow in conversionCache while converted == undefined do
            if cacheRow[1] == originalMaterial do converted = cacheRow[2]
        converted
    )

    fn createConvertedVRay originalMaterial =
    (
        local convertedMaterial = execute "VRayMtl()"
        convertedMaterial.name = originalMaterial.name
        setProperty convertedMaterial #Diffuse (copy (getProperty originalMaterial #diffuseColor))

        if chkOverrideGlossiness.checked do
        (
            setProperty convertedMaterial #brdf_useRoughness false
            setProperty convertedMaterial #reflection_glossiness spnGlossiness.value
        )

        if chkOverrideReflection.checked do
            setProperty convertedMaterial #Reflection (copy cpReflection.color)

        convertedMaterial
    )

    fn buildConversionCache =
    (
        conversionCache = #()
        for originalMaterial in conversionPlan do
        (
            local convertedMaterial = createConvertedVRay originalMaterial
            append conversionCache #(originalMaterial, convertedMaterial)
        )
        conversionCache.count
    )

    fn replaceUSDReferencesInTopMaterial nodeValue =
    (
        local replacedCount = 0
        local topMaterial = nodeValue.material
        if topMaterial != undefined do
        (
            if isMultiMaterial topMaterial then
            (
                for slotIndex = 1 to topMaterial.materialList.count do
                (
                    local originalMaterial = topMaterial.materialList[slotIndex]
                    local convertedMaterial = findConvertedMaterial originalMaterial
                    if convertedMaterial != undefined do
                    (
                        topMaterial.materialList[slotIndex] = convertedMaterial
                        replacedCount += 1
                    )
                )
            )
            else
            (
                local convertedMaterial = findConvertedMaterial topMaterial
                if convertedMaterial != undefined do
                (
                    nodeValue.material = convertedMaterial
                    replacedCount += 1
                )
            )
        )
        replacedCount
    )

    fn applyUSDConversions =
    (
        if not chkConvertUSD.checked or conversionPlan.count == 0 then
            0
        else
        (
            local convertedCount = buildConversionCache()
            replaceUSDReferencesInTopMaterial masterNode
            for nodeValue in targetNodes where isValidStoredNode nodeValue do
                replaceUSDReferencesInTopMaterial nodeValue
            convertedCount
        )
    )

    fn applyUSDConversionsToNodes nodeValues =
    (
        if not chkConvertUSD.checked or conversionPlan.count == 0 then
            0
        else
        (
            local convertedCount = buildConversionCache()
            for nodeValue in nodeValues where isValidStoredNode nodeValue do
                replaceUSDReferencesInTopMaterial nodeValue
            convertedCount
        )
    )

    fn captureConversionRowsFromCache =
    (
        local rows = #()
        for cacheRow in conversionCache do
        (
            local sourceMaterial = cacheRow[1]
            local convertedMaterial = cacheRow[2]
            append rows #(
                safeMaterialName sourceMaterial,
                materialClassText sourceMaterial,
                safeMaterialName convertedMaterial,
                materialClassText convertedMaterial,
                readComparableDiffuse convertedMaterial,
                (if chkOverrideGlossiness.checked then formattedPrint spnGlossiness.value format:".2f" else "OFF"),
                (if chkOverrideReflection.checked then
                    ((cpReflection.color.r as integer) as string) + "," +
                    ((cpReflection.color.g as integer) as string) + "," +
                    ((cpReflection.color.b as integer) as string)
                 else "OFF")
            )
        )
        rows
    )

    fn syncMultiSlotNames materialValue =
    (
        local changedCount = 0
        if isMultiMaterial materialValue do
        (
            if materialValue.names.count < materialValue.materialList.count do
                materialValue.names.count = materialValue.materialList.count

            for slotIndex = 1 to materialValue.materialList.count do
            (
                local subMaterial = materialValue.materialList[slotIndex]
                if subMaterial != undefined do
                (
                    local desiredName = safeMaterialName subMaterial
                    if materialValue.names[slotIndex] != desiredName do
                    (
                        materialValue.names[slotIndex] = desiredName
                        changedCount += 1
                    )
                )
            )
        )
        changedCount
    )

    fn syncRegisteredMultiSlotNames =
    (
        if not chkSyncSlotNames.checked then
            0
        else
        (
            local multiMaterials = #()
            if isValidStoredNode masterNode and isMultiMaterial masterNode.material do
                appendUniqueMaterial multiMaterials masterNode.material
            for nodeValue in targetNodes where isValidStoredNode nodeValue and isMultiMaterial nodeValue.material do
                appendUniqueMaterial multiMaterials nodeValue.material

            local changedCount = 0
            for materialValue in multiMaterials do changedCount += syncMultiSlotNames materialValue
            changedCount
        )
    )

    fn syncMultiSlotNamesForNodes nodeValues =
    (
        if not chkSyncSlotNames.checked then
            0
        else
        (
            local multiMaterials = #()
            for nodeValue in nodeValues where isValidStoredNode nodeValue and isMultiMaterial nodeValue.material do
                appendUniqueMaterial multiMaterials nodeValue.material

            local changedCount = 0
            for materialValue in multiMaterials do changedCount += syncMultiSlotNames materialValue
            changedCount
        )
    )

    fn updatePreprocessControlStates =
    (
        chkOverrideGlossiness.enabled = chkConvertUSD.checked
        chkOverrideReflection.enabled = chkConvertUSD.checked
        spnGlossiness.enabled = chkConvertUSD.checked and chkOverrideGlossiness.checked
        cpReflection.enabled = chkConvertUSD.checked and chkOverrideReflection.checked
    )

    fn setPreprocessOptions convertEnabled glossinessEnabled glossinessValue reflectionEnabled reflectionColor =
    (
        local clampedGlossiness = glossinessValue
        if clampedGlossiness < 0.0 then clampedGlossiness = 0.0
        if clampedGlossiness > 1.0 then clampedGlossiness = 1.0

        chkConvertUSD.checked = convertEnabled
        chkOverrideGlossiness.checked = glossinessEnabled
        spnGlossiness.value = clampedGlossiness
        chkOverrideReflection.checked = reflectionEnabled
        cpReflection.color = reflectionColor
        updatePreprocessControlStates()
        canonicalRows = #()
        targetAnalyses = #()
        analysisReady = false
        btnApply.enabled = false
        true
    )

    fn getLastApplyStats =
    (
        #(lastApplyConvertedCount, lastApplyAppendedCount)
    )

    fn setExtendedOptions syncSlotNames autoExport =
    (
        chkSyncSlotNames.checked = syncSlotNames
        chkAutoExport.checked = autoExport
        canonicalRows = #()
        targetAnalyses = #()
        analysisReady = false
        btnApply.enabled = false
        true
    )

    fn getLastOperationStats =
    (
        #(lastOperation, lastApplyConvertedCount, lastApplyAppendedCount, lastSyncedSlotCount, lastReportPath)
    )

    fn cleanStoredNodes =
    (
        if masterNode != undefined and not isValidStoredNode masterNode do
        (
            lmnLog "WARN" "The stored Master was deleted or became invalid."
            masterNode = undefined
            analysisReady = false
        )

        local cleanTargets = #()
        for nodeValue in targetNodes do
        (
            if isValidStoredNode nodeValue and nodeValue != masterNode and (findItem cleanTargets nodeValue) == 0 then
                append cleanTargets nodeValue
            else if nodeValue != undefined and not isValidStoredNode nodeValue do
                lmnLog "WARN" "A deleted or invalid Target was removed."
        )
        targetNodes = cleanTargets
    )

    fn clearListView viewControl =
    (
        viewControl.beginUpdate()
        viewControl.items.clear()
        viewControl.endUpdate()
    )

    fn addListViewRow viewControl values =
    (
        local item = dotNetObject "System.Windows.Forms.ListViewItem" (values[1] as string)
        for indexValue = 2 to values.count do item.subItems.add (values[indexValue] as string)
        viewControl.items.add item
        item
    )

    fn configureListView viewControl columnSpecs =
    (
        local viewEnum = dotNetClass "System.Windows.Forms.View"
        viewControl.view = viewEnum.details
        viewControl.fullRowSelect = true
        viewControl.gridLines = true
        viewControl.hideSelection = false
        viewControl.multiSelect = false
        viewControl.headerStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").nonclickable
        viewControl.columns.clear()
        for columnSpec in columnSpecs do viewControl.columns.add columnSpec[1] columnSpec[2]
    )

    /* GLOBAL A-Z REINDEX is a selection-scoped MK2 workflow.
       It never reads or mutates Master/Targets and never performs material conversion.

       Registry row:
       #(newID, displayName, representativeMaterial, materialClass, oldIDs,
         usedNodes, statusText, materialReferences)

       Multi analysis:
       #(multiMaterial, statusText, detailText, definedRows)

       Object analysis:
       #(node, statusText, detailText, remapRows, isApplicable, multiMaterial)

       A-Z remap row:
       #(oldID, materialName, newID, statusText, materialReference, slotIndex)
    */

    fn globalAZNamesEqual leftName rightName =
    (
        if leftName == undefined or rightName == undefined then
            false
        else
            (dotNetClass "System.StringComparer").OrdinalIgnoreCase.Equals (leftName as string) (rightName as string)
    )

    fn compareGlobalAZNames leftName rightName =
    (
        local ignoreCaseResult = (dotNetClass "System.StringComparer").OrdinalIgnoreCase.Compare (leftName as string) (rightName as string)
        if ignoreCaseResult != 0 then
            ignoreCaseResult
        else
            (dotNetClass "System.StringComparer").Ordinal.Compare (leftName as string) (rightName as string)
    )

    fn joinGlobalAZText values separator =
    (
        local result = ""
        for valueIndex = 1 to values.count do
        (
            if valueIndex > 1 do result += separator
            result += values[valueIndex] as string
        )
        result
    )

    fn appendUniqueNode nodeArray nodeValue =
    (
        if isValidStoredNode nodeValue and (findItem nodeArray nodeValue) == 0 do append nodeArray nodeValue
        nodeArray
    )

    fn appendUniqueInteger integerArray integerValue =
    (
        if (findItem integerArray integerValue) == 0 do append integerArray integerValue
        integerArray
    )

    fn findGlobalAZRegistryRow materialName =
    (
        local foundIndex = 0
        for rowIndex = 1 to globalAZRegistryRows.count while foundIndex == 0 do
            if globalAZNamesEqual globalAZRegistryRows[rowIndex][2] materialName do foundIndex = rowIndex
        foundIndex
    )

    fn findGlobalAZMaterialAnalysis materialValue =
    (
        local found = undefined
        for analysis in globalAZMaterialAnalyses while found == undefined do
            if analysis[1] == materialValue do found = analysis
        found
    )

    fn addGlobalAZConflict conflictType itemText detailText =
    (
        local duplicate = false
        for rowValue in globalAZConflictRows while not duplicate do
            if rowValue[1] == conflictType and rowValue[2] == itemText and rowValue[3] == detailText do duplicate = true
        if not duplicate do append globalAZConflictRows #(conflictType, itemText, detailText)
        true
    )

    fn markGlobalAZMaterialConflict materialAnalysis conflictType detailText =
    (
        materialAnalysis[2] = "CONFLICT"
        if materialAnalysis[3] == "" then
            materialAnalysis[3] = detailText
        else if findString materialAnalysis[3] detailText == undefined do
            materialAnalysis[3] += " | " + detailText
        addGlobalAZConflict conflictType (materialAnalysis[1].name as string) detailText
        true
    )

    fn sortGlobalAZRegistry =
    (
        local remainingRows = for rowValue in globalAZRegistryRows collect rowValue
        local sortedRows = #()
        while remainingRows.count > 0 do
        (
            local bestIndex = 1
            for rowIndex = 2 to remainingRows.count do
            (
                if compareGlobalAZNames remainingRows[rowIndex][2] remainingRows[bestIndex][2] < 0 do
                    bestIndex = rowIndex
            )
            append sortedRows remainingRows[bestIndex]
            deleteItem remainingRows bestIndex
        )
        for rowIndex = 1 to sortedRows.count do sortedRows[rowIndex][1] = rowIndex
        globalAZRegistryRows = sortedRows
        globalAZRegistryRows
    )

    fn globalAZIntegerListText integerValues =
    (
        local sortedValues = for value in integerValues collect value
        sort sortedValues
        joinGlobalAZText sortedValues ","
    )

    fn globalAZNodeNames nodeValues =
    (
        local names = for nodeValue in nodeValues where isValidStoredNode nodeValue collect nodeValue.name
        sort names
        names
    )

    fn getGlobalAZDefinedRows materialValue =
    (
        local rows = #()
        local safeCount = amin materialValue.materialList.count materialValue.materialIDList.count
        for slotIndex = 1 to safeCount do
        (
            local subMaterial = materialValue.materialList[slotIndex]
            if subMaterial != undefined do
                append rows #(materialValue.materialIDList[slotIndex], safeMaterialName subMaterial, subMaterial, slotIndex)
        )
        rows
    )

    fn findGlobalAZRowsByID materialRows materialID =
    (
        for rowValue in materialRows where rowValue[1] == materialID collect rowValue
    )

    fn getGlobalAZUniqueFaceIDs nodeValue =
    (
        local faceIDs = #()
        local faceCount = polyop.getNumFaces nodeValue
        for faceIndex = 1 to faceCount do
        (
            local faceID = polyop.getFaceMatID nodeValue faceIndex
            if (findItem faceIDs faceID) == 0 do append faceIDs faceID
        )
        sort faceIDs
        faceIDs
    )

    fn buildGlobalAZMaterialAnalysis materialValue =
    (
        local analysis = #(materialValue, "READY", "", #())
        local materialCount = materialValue.materialList.count
        local idCount = materialValue.materialIDList.count

        if materialCount != idCount then
            markGlobalAZMaterialConflict analysis "MULTISUB LENGTH MISMATCH" "materialList/materialIDList lengths do not match."
        else
        (
            analysis[4] = getGlobalAZDefinedRows materialValue
            if analysis[4].count == 0 do
                markGlobalAZMaterialConflict analysis "EMPTY MULTISUB" "No non-empty sub-material is available for reindex."

            if materialCount > 1 do
            (
                for leftSlot = 1 to (materialCount - 1) do
                (
                    for rightSlot = leftSlot + 1 to materialCount do
                    (
                        if materialValue.materialIDList[leftSlot] == materialValue.materialIDList[rightSlot] do
                            markGlobalAZMaterialConflict analysis "DUPLICATE MATERIAL ID" ("Material ID " + (materialValue.materialIDList[leftSlot] as string) + " is assigned to multiple slots.")
                    )
                )
            )

            for rowValue in analysis[4] do
            (
                if rowValue[2] == "" do
                    markGlobalAZMaterialConflict analysis "EMPTY MATERIAL NAME" ("Slot " + (rowValue[4] as string) + " has an empty material name.")
            )

            if analysis[4].count > 1 do
            (
                for leftIndex = 1 to (analysis[4].count - 1) do
                (
                    for rightIndex = leftIndex + 1 to analysis[4].count do
                    (
                        if globalAZNamesEqual analysis[4][leftIndex][2] analysis[4][rightIndex][2] do
                            markGlobalAZMaterialConflict analysis "DUPLICATE MATERIAL NAME IN MULTISUB" ("Case-insensitive name '" + analysis[4][leftIndex][2] + "' appears in multiple slots.")
                    )
                )
            )
        )
        analysis
    )

    fn buildGlobalAZRegistry eligibleNodes =
    (
        globalAZRegistryRows = #()

        for nodeValue in eligibleNodes do
        (
            local materialAnalysis = findGlobalAZMaterialAnalysis nodeValue.material
            if materialAnalysis != undefined do
            (
                for materialRow in materialAnalysis[4] do
                (
                    local materialName = materialRow[2]
                    local registryIndex = findGlobalAZRegistryRow materialName
                    if registryIndex == 0 then
                    (
                        append globalAZRegistryRows #(0, materialName, materialRow[3], materialClassText materialRow[3],
                            #(materialRow[1]), #(nodeValue), "READY", #(materialRow[3]))
                    )
                    else
                    (
                        local registryRow = globalAZRegistryRows[registryIndex]
                        appendUniqueInteger registryRow[5] materialRow[1]
                        appendUniqueNode registryRow[6] nodeValue
                        appendUniqueMaterial registryRow[8] materialRow[3]
                        if (dotNetClass "System.StringComparer").Ordinal.Compare materialName registryRow[2] < 0 do
                            registryRow[2] = materialName
                    )
                )
            )
        )

        sortGlobalAZRegistry()

        if globalAZRegistryRows.count > 60000 do
            addGlobalAZConflict "MATERIAL ID LIMIT" "Global Registry" "The registry exceeds the 60,000 Material ID safety limit."

        for registryRow in globalAZRegistryRows do
        (
            local materialReferences = registryRow[8]
            if materialReferences.count > 1 do
            (
                local baseMaterial = materialReferences[1]
                local baseClass = materialClassText baseMaterial
                local baseDiffuse = readComparableDiffuse baseMaterial
                for materialIndex = 2 to materialReferences.count do
                (
                    local comparedMaterial = materialReferences[materialIndex]
                    local comparedClass = materialClassText comparedMaterial
                    if baseClass != comparedClass then
                    (
                        registryRow[7] = "CLASS CONFLICT"
                        addGlobalAZConflict "CLASS CONFLICT" registryRow[2] ("SAME NAME / DIFFERENT CLASS: " + baseClass + " vs " + comparedClass)
                    )
                    else
                    (
                        local comparedDiffuse = readComparableDiffuse comparedMaterial
                        if baseDiffuse[1] and comparedDiffuse[1] and not diffuseColorsEqual baseDiffuse[2] comparedDiffuse[2] do
                        (
                            registryRow[7] = "COLOR CONFLICT"
                            addGlobalAZConflict "COLOR CONFLICT" registryRow[2] "SAME NAME / DIFFERENT DIFFUSE"
                        )
                    )
                )
            )
        )
        globalAZRegistryRows
    )

    fn validateGlobalAZEmptySlots =
    (
        for materialAnalysis in globalAZMaterialAnalyses do
        (
            local materialValue = materialAnalysis[1]
            local slotCount = amin materialValue.materialList.count materialValue.materialIDList.count
            for slotIndex = 1 to slotCount where materialValue.materialList[slotIndex] == undefined do
            (
                local emptyID = materialValue.materialIDList[slotIndex]
                local collides = false
                for definedRow in materialAnalysis[4] while not collides do
                (
                    local registryIndex = findGlobalAZRegistryRow definedRow[2]
                    if registryIndex > 0 and globalAZRegistryRows[registryIndex][1] == emptyID do collides = true
                )
                if collides do
                    markGlobalAZMaterialConflict materialAnalysis "EMPTY SLOT ID COLLISION" ("Empty slot " + (slotIndex as string) + " uses ID " + (emptyID as string) + ", which a reindexed material also requires.")
            )
        )
        true
    )

    fn validateGlobalAZSharedUsers eligibleNodes =
    (
        for materialAnalysis in globalAZMaterialAnalyses do
        (
            local materialValue = materialAnalysis[1]
            local externalUsers = #()
            for sceneNode in objects do
            (
                local usesMaterial = false
                try (usesMaterial = sceneNode.material == materialValue) catch (usesMaterial = false)
                if usesMaterial and (findItem eligibleNodes sceneNode) == 0 do appendUniqueNode externalUsers sceneNode
            )
            if externalUsers.count > 0 do
            (
                local names = globalAZNodeNames externalUsers
                markGlobalAZMaterialConflict materialAnalysis "EXTERNAL MATERIAL USER" ("Shared Multi/Sub is also used by " + (externalUsers.count as string) +
                    " object(s) that cannot be remapped: " + joinGlobalAZText names ", " +
                    ". Select all Editable Poly users before applying.")
            )
        )
        true
    )

    fn buildGlobalAZObjectAnalyses selectedNodes eligibleNodes =
    (
        globalAZObjectAnalyses = #()
        globalAZSkippedRows = #()

        for nodeValue in selectedNodes do
        (
            if nodeValue.material == undefined then
            (
                append globalAZSkippedRows #(nodeValue.name, "NO MATERIAL / SKIP", "No material is assigned.")
                append globalAZObjectAnalyses #(nodeValue, "NO MATERIAL / SKIP", "No material is assigned.", #(), false, undefined)
            )
            else if not isMultiMaterial nodeValue.material then
            (
                append globalAZSkippedRows #(nodeValue.name, "SINGLE MATERIAL / NO REINDEX REQUIRED", materialClassText nodeValue.material)
                append globalAZObjectAnalyses #(nodeValue, "SINGLE MATERIAL / NO REINDEX REQUIRED", "No Multi/Sub is created.", #(), false, undefined)
            )
            else if not isEditablePolyNode nodeValue then
            (
                append globalAZSkippedRows #(nodeValue.name, "UNSUPPORTED GEOMETRY / SKIP", "Base object is not Editable Poly.")
                append globalAZObjectAnalyses #(nodeValue, "UNSUPPORTED GEOMETRY / SKIP", "Base object is not Editable Poly.", #(), false, nodeValue.material)
            )
            else
            (
                local materialAnalysis = findGlobalAZMaterialAnalysis nodeValue.material
                local remapRows = #()
                local objectStatus = "READY"
                local objectDetail = "Ready"
                local applicable = true

                if materialAnalysis == undefined then
                (
                    objectStatus = "ERROR"
                    objectDetail = "Multi/Sub analysis is unavailable."
                    applicable = false
                )
                else
                (
                    for materialRow in materialAnalysis[4] do
                    (
                        local registryIndex = findGlobalAZRegistryRow materialRow[2]
                        if registryIndex == 0 then
                        (
                            objectStatus = "ERROR"
                            objectDetail = "Global registry lookup failed for " + materialRow[2] + "."
                            applicable = false
                        )
                        else
                        (
                            local registryRow = globalAZRegistryRows[registryIndex]
                            local rowStatus = if registryRow[7] == "READY" then "READY" else registryRow[7]
                            append remapRows #(materialRow[1], materialRow[2], registryRow[1], rowStatus, materialRow[3], materialRow[4])
                        )
                    )

                    if materialAnalysis[2] != "READY" then
                    (
                        objectStatus = "CONFLICT"
                        objectDetail = materialAnalysis[3]
                        applicable = false
                    )

                    local faceIDs = getGlobalAZUniqueFaceIDs nodeValue
                    for faceID in faceIDs do
                    (
                        if (findGlobalAZRowsByID materialAnalysis[4] faceID).count != 1 do
                        (
                            objectStatus = "UNDEFINED FACE MATERIAL ID"
                            objectDetail = "Face Material ID " + (faceID as string) + " is not represented by one non-empty Multi/Sub slot."
                            applicable = false
                            addGlobalAZConflict "UNDEFINED FACE MATERIAL ID" nodeValue.name objectDetail
                        )
                    )
                )

                append globalAZObjectAnalyses #(nodeValue, objectStatus, objectDetail, remapRows, applicable, nodeValue.material)
            )
        )
        globalAZObjectAnalyses
    )

    fn captureGlobalAZReportSnapshot statusOverride:"" =
    (
        lastGlobalAZSelectedNames = globalAZNodeNames globalAZSelectionNodes
        lastGlobalAZRegistryRows = #()
        for registryRow in globalAZRegistryRows do
        (
            local statusText = if statusOverride == "" or registryRow[7] != "READY" then registryRow[7] else statusOverride
            append lastGlobalAZRegistryRows #(
                registryRow[1] as string,
                registryRow[2],
                globalAZIntegerListText registryRow[5],
                registryRow[4],
                registryRow[6].count as string,
                statusText
            )
        )

        lastGlobalAZObjectRows = #()
        for analysis in globalAZObjectAnalyses where analysis[4].count > 0 do
        (
            local rows = #()
            for remapRow in analysis[4] do
            (
                local statusText = if statusOverride == "" or remapRow[4] != "READY" then remapRow[4] else statusOverride
                append rows #(remapRow[1] as string, remapRow[2], remapRow[3] as string, statusText)
            )
            append lastGlobalAZObjectRows #(analysis[1].name, rows)
        )
        lastGlobalAZConflictRows = for rowValue in globalAZConflictRows collect #(rowValue[1], rowValue[2], rowValue[3])
        true
    )

    fn analyzeGlobalAZ updateUI:true recordOperation:false =
    (
        globalAZSelectionNodes = for nodeValue in selection where isValidStoredNode nodeValue collect nodeValue
        globalAZRegistryRows = #()
        globalAZMaterialAnalyses = #()
        globalAZObjectAnalyses = #()
        globalAZConflictRows = #()
        globalAZSkippedRows = #()
        globalAZAnalysisReady = false

        local eligibleNodes = #()
        local uniqueMultiMaterials = #()
        for nodeValue in globalAZSelectionNodes do
        (
            if nodeValue.material != undefined and isMultiMaterial nodeValue.material and isEditablePolyNode nodeValue do
            (
                append eligibleNodes nodeValue
                appendUniqueMaterial uniqueMultiMaterials nodeValue.material
            )
        )

        for materialValue in uniqueMultiMaterials do
            append globalAZMaterialAnalyses (buildGlobalAZMaterialAnalysis materialValue)

        buildGlobalAZRegistry eligibleNodes
        validateGlobalAZEmptySlots()
        validateGlobalAZSharedUsers eligibleNodes
        buildGlobalAZObjectAnalyses globalAZSelectionNodes eligibleNodes

        local readyCount = 0
        for analysis in globalAZObjectAnalyses where analysis[5] do readyCount += 1
        globalAZAnalysisReady = globalAZSelectionNodes.count > 0 and readyCount > 0 and globalAZConflictRows.count == 0

        if globalAZSelectionNodes.count == 0 then
            setStatus "GLOBAL A-Z: Select one or more objects."
        else if globalAZConflictRows.count > 0 then
            setStatus ("GLOBAL A-Z BLOCKED: " + (globalAZConflictRows.count as string) + " conflict(s). Review the A-Z preview.")
        else if readyCount == 0 then
            setStatus "GLOBAL A-Z: No applicable Editable Poly Multi/Sub object was selected."
        else
            setStatus ("GLOBAL A-Z Analyze complete: " + (readyCount as string) + " ready object(s), " +
                (globalAZRegistryRows.count as string) + " unique material(s), " +
                (globalAZSkippedRows.count as string) + " skipped.")

        if recordOperation do
        (
            lastOperation = #globalAZAnalyze
            captureGlobalAZReportSnapshot()
        )
        if updateUI do LunarMaterialIDNormalizerRollout.refreshGlobalAZViewer()
        globalAZAnalysisReady
    )

    fn getGlobalAZPreviewValues =
    (
        local registryValues = #()
        for registryRow in globalAZRegistryRows do
            append registryValues #(registryRow[1], registryRow[2], globalAZIntegerListText registryRow[5],
                registryRow[4], registryRow[6].count, registryRow[7])

        local objectValues = #()
        for analysis in globalAZObjectAnalyses do
        (
            local rows = #()
            for remapRow in analysis[4] do append rows #(remapRow[1], remapRow[2], remapRow[3], remapRow[4])
            append objectValues #(if isValidStoredNode analysis[1] then analysis[1].name else "<Invalid Node>", analysis[2], analysis[3], rows, analysis[5])
        )
        #(globalAZAnalysisReady, globalAZNodeNames globalAZSelectionNodes, registryValues, objectValues,
            for rowValue in globalAZConflictRows collect #(rowValue[1], rowValue[2], rowValue[3]),
            for rowValue in globalAZSkippedRows collect #(rowValue[1], rowValue[2], rowValue[3]))
    )

    fn snapshotGlobalAZMaterials =
    (
        local snapshots = #()
        for materialAnalysis in globalAZMaterialAnalyses do
        (
            local materialValue = materialAnalysis[1]
            local slotCount = materialValue.materialList.count
            local materials = for slotIndex = 1 to slotCount collect materialValue.materialList[slotIndex]
            local ids = for slotIndex = 1 to slotCount collect materialValue.materialIDList[slotIndex]
            local names = for slotIndex = 1 to slotCount collect
                (if slotIndex <= materialValue.names.count then materialValue.names[slotIndex] else "")
            local enabledValues = for slotIndex = 1 to slotCount collect
                (if slotIndex <= materialValue.mapEnabled.count then materialValue.mapEnabled[slotIndex] else true)
            append snapshots #(materialValue, materials, ids, names, enabledValues)
        )
        snapshots
    )

    fn restoreGlobalAZMaterials snapshots =
    (
        for snapshot in snapshots do
        (
            local materialValue = snapshot[1]
            local slotCount = snapshot[2].count
            materialValue.materialList.count = slotCount
            materialValue.materialIDList.count = slotCount
            materialValue.names.count = slotCount
            materialValue.mapEnabled.count = slotCount
            for slotIndex = 1 to slotCount do
            (
                materialValue.materialList[slotIndex] = snapshot[2][slotIndex]
                materialValue.materialIDList[slotIndex] = snapshot[3][slotIndex]
                materialValue.names[slotIndex] = snapshot[4][slotIndex]
                materialValue.mapEnabled[slotIndex] = snapshot[5][slotIndex]
            )
        )
        true
    )

    fn snapshotGlobalAZFaceSets =
    (
        local snapshots = #()
        for analysis in globalAZObjectAnalyses where analysis[5] do
        (
            local mappingSnapshots = #()
            for remapRow in analysis[4] do append mappingSnapshots #(remapRow[1], remapRow[3], #{})

            local faceCount = polyop.getNumFaces analysis[1]
            for faceIndex = 1 to faceCount do
            (
                local oldID = polyop.getFaceMatID analysis[1] faceIndex
                local mappingIndex = 0
                for rowIndex = 1 to mappingSnapshots.count while mappingIndex == 0 do
                    if mappingSnapshots[rowIndex][1] == oldID do mappingIndex = rowIndex
                if mappingIndex == 0 then
                    throw (analysis[1].name + ": Face " + (faceIndex as string) + " uses unmapped Material ID " + (oldID as string) + ".")
                else
                    mappingSnapshots[mappingIndex][3][faceIndex] = true
            )
            append snapshots #(analysis[1], mappingSnapshots)
        )
        snapshots
    )

    fn restoreGlobalAZFaces faceSnapshots =
    (
        for objectSnapshot in faceSnapshots do
        (
            for mappingSnapshot in objectSnapshot[2] where mappingSnapshot[3].numberSet > 0 do
                polyop.setFaceMatID objectSnapshot[1] mappingSnapshot[3] mappingSnapshot[1]
        )
        true
    )

    fn reorderGlobalAZMulti materialAnalysis =
    (
        local materialValue = materialAnalysis[1]
        local slotCount = materialValue.materialList.count
        local nonEmptyRows = #()
        local emptyRows = #()

        for slotIndex = 1 to slotCount do
        (
            local subMaterial = materialValue.materialList[slotIndex]
            local oldName = if slotIndex <= materialValue.names.count then materialValue.names[slotIndex] else ""
            local enabledValue = if slotIndex <= materialValue.mapEnabled.count then materialValue.mapEnabled[slotIndex] else true
            if subMaterial == undefined then
                append emptyRows #(subMaterial, materialValue.materialIDList[slotIndex], oldName, enabledValue)
            else
            (
                local registryIndex = findGlobalAZRegistryRow (safeMaterialName subMaterial)
                if registryIndex == 0 do throw ("Global registry lookup failed during reorder for " + safeMaterialName subMaterial + ".")
                append nonEmptyRows #(subMaterial, globalAZRegistryRows[registryIndex][1], safeMaterialName subMaterial, enabledValue)
            )
        )

        if nonEmptyRows.count > 1 do
        (
            local remainingRows = for rowValue in nonEmptyRows collect rowValue
            nonEmptyRows = #()
            while remainingRows.count > 0 do
            (
                local bestIndex = 1
                for rowIndex = 2 to remainingRows.count where remainingRows[rowIndex][2] < remainingRows[bestIndex][2] do
                    bestIndex = rowIndex
                append nonEmptyRows remainingRows[bestIndex]
                deleteItem remainingRows bestIndex
            )
        )

        local reorderedRows = #()
        for rowValue in nonEmptyRows do append reorderedRows rowValue
        for rowValue in emptyRows do append reorderedRows rowValue

        materialValue.materialList.count = slotCount
        materialValue.materialIDList.count = slotCount
        materialValue.names.count = slotCount
        materialValue.mapEnabled.count = slotCount
        for slotIndex = 1 to slotCount do
        (
            materialValue.materialList[slotIndex] = reorderedRows[slotIndex][1]
            materialValue.materialIDList[slotIndex] = reorderedRows[slotIndex][2]
            materialValue.names[slotIndex] = reorderedRows[slotIndex][3]
            materialValue.mapEnabled[slotIndex] = reorderedRows[slotIndex][4]
        )
        true
    )

    fn applyGlobalAZFaceSets faceSnapshots =
    (
        for objectSnapshot in faceSnapshots do
        (
            for mappingSnapshot in objectSnapshot[2] where mappingSnapshot[3].numberSet > 0 do
                polyop.setFaceMatID objectSnapshot[1] mappingSnapshot[3] mappingSnapshot[2]
        )
        true
    )

    fn verifyGlobalAZResult faceSnapshots =
    (
        local verified = true
        for objectSnapshot in faceSnapshots while verified do
        (
            for mappingSnapshot in objectSnapshot[2] while verified do
            (
                for faceIndex in mappingSnapshot[3] while verified do
                    if polyop.getFaceMatID objectSnapshot[1] faceIndex != mappingSnapshot[2] do verified = false
            )
        )

        for materialAnalysis in globalAZMaterialAnalyses while verified do
        (
            local previousID = 0
            local materialValue = materialAnalysis[1]
            for slotIndex = 1 to materialValue.materialList.count while verified do
            (
                local subMaterial = materialValue.materialList[slotIndex]
                if subMaterial != undefined do
                (
                    local currentID = materialValue.materialIDList[slotIndex]
                    local registryIndex = findGlobalAZRegistryRow (safeMaterialName subMaterial)
                    if registryIndex == 0 or currentID != globalAZRegistryRows[registryIndex][1] or currentID <= previousID then
                        verified = false
                    else if materialValue.names[slotIndex] != safeMaterialName subMaterial then
                        verified = false
                    previousID = currentID
                )
            )
        )
        verified
    )

    fn applyGlobalAZReindex =
    (
        if not analyzeGlobalAZ updateUI:true recordOperation:false then
        (
            lmnLog "WARN" "Global A-Z Reindex was blocked by live validation."
            false
        )
        else
        (
            local materialSnapshots = #()
            local faceSnapshots = #()
            local operationFailed = false
            local failureText = ""

            try
            (
                materialSnapshots = snapshotGlobalAZMaterials()
                faceSnapshots = snapshotGlobalAZFaceSets()
                captureGlobalAZReportSnapshot statusOverride:"REINDEXED"
            )
            catch
            (
                operationFailed = true
                failureText = "Snapshot failed: " + exceptionText()
            )

            if not operationFailed do
            (
                undo "Global A-Z Material Reindex" on
                (
                    try
                    (
                        for materialAnalysis in globalAZMaterialAnalyses do reorderGlobalAZMulti materialAnalysis
                        applyGlobalAZFaceSets faceSnapshots
                        if not verifyGlobalAZResult faceSnapshots do throw "Post-apply verification failed."
                    )
                    catch
                    (
                        operationFailed = true
                        failureText = exceptionText()
                        try (restoreGlobalAZMaterials materialSnapshots) catch()
                        try (restoreGlobalAZFaces faceSnapshots) catch()
                    )
                )
            )

            if operationFailed then
            (
                setStatus ("GLOBAL A-Z ERROR: " + failureText)
                lmnLog "ERROR" ("Global A-Z Reindex failed: " + failureText)
                false
            )
            else
            (
                local reindexedObjectCount = faceSnapshots.count
                local reindexedMaterialCount = globalAZRegistryRows.count
                redrawViews()
                analyzeGlobalAZ updateUI:true recordOperation:false
                lastOperation = #globalAZReindex
                local resultMessage = "GLOBAL A-Z complete: " + (reindexedObjectCount as string) +
                    " object(s), " + (reindexedMaterialCount as string) +
                    " global material ID(s). Existing Multi/Sub references and appearance were preserved."
                setStatus resultMessage
                lmnLog "INFO" resultMessage
                LunarMaterialIDNormalizerRollout.autoExportReport()
                true
            )
        )
    )

    fn refreshGlobalAZObjectPreview =
    (
        if globalAZControls != undefined do
        (
            local objectCombo = globalAZControls[3]
            local objectList = globalAZControls[4]
            clearListView objectList
            local selectedIndex = objectCombo.selectedIndex + 1
            if selectedIndex >= 1 and selectedIndex <= globalAZObjectAnalyses.count then
            (
                local analysis = globalAZObjectAnalyses[selectedIndex]
                for remapRow in analysis[4] do
                    addListViewRow objectList #(remapRow[1], remapRow[2], remapRow[3], remapRow[4])
                if analysis[4].count == 0 do addListViewRow objectList #(analysis[2], analysis[3])
            )
            else
                addListViewRow objectList #("Run Analyze A-Z")
        )
    )

    fn refreshGlobalAZViewer =
    (
        if globalAZControls != undefined do
        (
            local summaryLabel = globalAZControls[1]
            local registryList = globalAZControls[2]
            local objectCombo = globalAZControls[3]
            local conflictList = globalAZControls[5]
            local applyButton = globalAZControls[6]

            summaryLabel.text = "Selected Objects: " + (globalAZSelectionNodes.count as string) +
                "     |     Unique Materials: " + (globalAZRegistryRows.count as string) +
                "     |     Conflicts: " + (globalAZConflictRows.count as string) +
                "     |     Uses current scene selection; Master / Targets are not required."

            clearListView registryList
            for registryRow in globalAZRegistryRows do
                addListViewRow registryList #(registryRow[1], registryRow[2], globalAZIntegerListText registryRow[5],
                    registryRow[4], registryRow[6].count, registryRow[7])
            if globalAZRegistryRows.count == 0 do addListViewRow registryList #("Run Analyze A-Z")

            local previousIndex = objectCombo.selectedIndex
            objectCombo.items.clear()
            for analysis in globalAZObjectAnalyses do
            (
                local itemText = (if isValidStoredNode analysis[1] then analysis[1].name else "<Invalid Node>") + "  [" + analysis[2] + "]"
                objectCombo.items.add itemText
            )
            if globalAZObjectAnalyses.count > 0 then
                objectCombo.selectedIndex = if previousIndex >= 0 and previousIndex < globalAZObjectAnalyses.count then previousIndex else 0
            else
                refreshGlobalAZObjectPreview()

            clearListView conflictList
            for rowValue in globalAZConflictRows do addListViewRow conflictList rowValue
            for rowValue in globalAZSkippedRows do addListViewRow conflictList #(rowValue[2], rowValue[1], rowValue[3])
            if globalAZConflictRows.count == 0 and globalAZSkippedRows.count == 0 do addListViewRow conflictList #("None")

            applyButton.enabled = globalAZAnalysisReady
        )
        true
    )

    fn onGlobalAZObjectChanged sender eventArgs = refreshGlobalAZObjectPreview()
    fn onGlobalAZAnalyze sender eventArgs = analyzeGlobalAZ updateUI:true recordOperation:true
    fn onGlobalAZApply sender eventArgs = applyGlobalAZReindex()
    fn onGlobalAZClose sender eventArgs = if globalAZForm != undefined do globalAZForm.Close()
    fn onGlobalAZFormClosed sender eventArgs =
    (
        globalAZForm = undefined
        globalAZControls = undefined
    )

    fn showGlobalAZViewer =
    (
        if globalAZForm != undefined then
        (
            globalAZForm.Activate()
            true
        )
        else
        (
            local form = dotNetObject "System.Windows.Forms.Form"
            form.text = "Lunar Material ID Normalizer MK2 — GLOBAL A-Z REINDEX"
            form.size = dotNetObject "System.Drawing.Size" 1120 780
            form.minimumSize = dotNetObject "System.Drawing.Size" 960 680
            form.startPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").CenterScreen

            local titleLabel = dotNetObject "System.Windows.Forms.Label"
            titleLabel.text = "GLOBAL A-Z REINDEX — CASE-INSENSITIVE / CURRENT SELECTION / NO MASTER REQUIRED"
            titleLabel.location = dotNetObject "System.Drawing.Point" 12 12
            titleLabel.size = dotNetObject "System.Drawing.Size" 1078 24
            titleLabel.font = dotNetObject "System.Drawing.Font" "Segoe UI" 10.0 (dotNetClass "System.Drawing.FontStyle").Bold
            form.controls.add titleLabel

            local summaryLabel = dotNetObject "System.Windows.Forms.Label"
            summaryLabel.text = "Selected Objects: 0     |     Unique Materials: 0     |     Uses current scene selection."
            summaryLabel.location = dotNetObject "System.Drawing.Point" 12 40
            summaryLabel.size = dotNetObject "System.Drawing.Size" 1078 22
            form.controls.add summaryLabel

            local analyzeButton = dotNetObject "System.Windows.Forms.Button"
            analyzeButton.text = "Analyze A-Z"
            analyzeButton.location = dotNetObject "System.Drawing.Point" 12 68
            analyzeButton.size = dotNetObject "System.Drawing.Size" 180 34
            form.controls.add analyzeButton
            dotNet.addEventHandler analyzeButton "Click" onGlobalAZAnalyze

            local applyButton = dotNetObject "System.Windows.Forms.Button"
            applyButton.text = "Apply A-Z Reindex"
            applyButton.location = dotNetObject "System.Drawing.Point" 202 68
            applyButton.size = dotNetObject "System.Drawing.Size" 200 34
            applyButton.enabled = false
            form.controls.add applyButton
            dotNet.addEventHandler applyButton "Click" onGlobalAZApply

            local tabs = dotNetObject "System.Windows.Forms.TabControl"
            tabs.location = dotNetObject "System.Drawing.Point" 12 112
            tabs.size = dotNetObject "System.Drawing.Size" 1078 568
            form.controls.add tabs

            local registryPage = dotNetObject "System.Windows.Forms.TabPage" "Global Registry"
            local objectPage = dotNetObject "System.Windows.Forms.TabPage" "Per-Object Preview"
            local conflictPage = dotNetObject "System.Windows.Forms.TabPage" "Conflicts / Skipped"
            tabs.tabPages.add registryPage
            tabs.tabPages.add objectPage
            tabs.tabPages.add conflictPage

            local registryList = dotNetObject "System.Windows.Forms.ListView"
            registryList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView registryList #(#("New ID", 70), #("Material Name", 260), #("Old IDs", 170), #("Class", 170), #("Used By", 80), #("Status", 280))
            registryPage.controls.add registryList

            local objectCombo = dotNetObject "System.Windows.Forms.ComboBox"
            objectCombo.location = dotNetObject "System.Drawing.Point" 10 10
            objectCombo.size = dotNetObject "System.Drawing.Size" 1038 24
            objectCombo.dropDownStyle = (dotNetClass "System.Windows.Forms.ComboBoxStyle").DropDownList
            objectPage.controls.add objectCombo
            dotNet.addEventHandler objectCombo "SelectedIndexChanged" onGlobalAZObjectChanged

            local objectList = dotNetObject "System.Windows.Forms.ListView"
            objectList.location = dotNetObject "System.Drawing.Point" 10 42
            objectList.size = dotNetObject "System.Drawing.Size" 1038 480
            configureListView objectList #(#("Old ID", 100), #("Material Name", 460), #("New ID", 100), #("Status", 350))
            objectPage.controls.add objectList

            local conflictList = dotNetObject "System.Windows.Forms.ListView"
            conflictList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView conflictList #(#("Type / Status", 260), #("Item / Object", 260), #("Detail", 500))
            conflictPage.controls.add conflictList

            local closeButton = dotNetObject "System.Windows.Forms.Button"
            closeButton.text = "Close"
            closeButton.location = dotNetObject "System.Drawing.Point" 940 694
            closeButton.size = dotNetObject "System.Drawing.Size" 150 32
            form.controls.add closeButton
            dotNet.addEventHandler closeButton "Click" onGlobalAZClose
            dotNet.addEventHandler form "FormClosed" onGlobalAZFormClosed

            globalAZForm = form
            globalAZControls = #(summaryLabel, registryList, objectCombo, objectList, conflictList, applyButton)
            refreshGlobalAZViewer()
            form.Show()
            true
        )
    )

    fn findCanonicalRowByName materialName rows:canonicalRows =
    (
        local foundIndex = 0
        for indexValue = 1 to rows.count while foundIndex == 0 do
        (
            if exactNameEquals rows[indexValue][2] materialName do foundIndex = indexValue
        )
        foundIndex
    )

    fn findCanonicalRowByID materialID rows:canonicalRows =
    (
        local foundIndex = 0
        for indexValue = 1 to rows.count while foundIndex == 0 do
        (
            if rows[indexValue][1] == materialID do foundIndex = indexValue
        )
        foundIndex
    )

    fn sortCanonicalRowsByID rows =
    (
        local remainingRows = for rowValue in rows collect rowValue
        local sortedRows = #()
        while remainingRows.count > 0 do
        (
            local bestIndex = 1
            for indexValue = 2 to remainingRows.count where remainingRows[indexValue][1] < remainingRows[bestIndex][1] do
                bestIndex = indexValue
            append sortedRows remainingRows[bestIndex]
            deleteItem remainingRows bestIndex
        )
        sortedRows
    )

    fn maxCanonicalID rows =
    (
        local maximumID = 0
        for rowValue in rows where rowValue[1] > maximumID do maximumID = rowValue[1]
        maximumID
    )

    fn findTargetAnalysis nodeValue =
    (
        local foundIndex = 0
        for indexValue = 1 to targetAnalyses.count while foundIndex == 0 do
        (
            if targetAnalyses[indexValue][1] == nodeValue do foundIndex = indexValue
        )
        if foundIndex == 0 then undefined else targetAnalyses[foundIndex]
    )

    fn getUniqueFaceIDs nodeValue =
    (
        local faceIDs = #()
        local faceCount = polyop.getNumFaces nodeValue
        for faceIndex = 1 to faceCount do
        (
            local faceID = polyop.getFaceMatID nodeValue faceIndex
            if (findItem faceIDs faceID) == 0 do append faceIDs faceID
        )
        sort faceIDs
        faceIDs
    )

    fn getDefinedMultiRows materialValue =
    (
        local rows = #()
        local materialCount = materialValue.materialList.count
        local idCount = materialValue.materialIDList.count
        local safeCount = amin materialCount idCount

        for slotIndex = 1 to safeCount do
        (
            local subMaterial = materialValue.materialList[slotIndex]
            if subMaterial != undefined do
            (
                append rows #(
                    materialValue.materialIDList[slotIndex],
                    safeMaterialName subMaterial,
                    subMaterial,
                    slotIndex
                )
            )
        )
        rows
    )

    fn findMultiRowByID materialRows materialID =
    (
        local foundRows = #()
        for rowValue in materialRows where rowValue[1] == materialID do append foundRows rowValue
        foundRows
    )

    fn buildMasterCanonical =
    (
        canonicalRows = #()
        analysisHasConflict = false

        if not isValidStoredNode masterNode then
        (
            setStatus "Set a valid Master object."
            false
        )
        else if masterNode.material == undefined then
        (
            setStatus ("MASTER " + masterNode.name + " has no material.")
            false
        )
        else if not isMultiMaterial masterNode.material then
        (
            setStatus ("MASTER " + masterNode.name + " must use a Multi/Sub-Object material.")
            false
        )
        else
        (
            local masterMaterial = masterNode.material
            local materialCount = masterMaterial.materialList.count
            local idCount = masterMaterial.materialIDList.count

            if materialCount != idCount then
            (
                setStatus "MASTER materialList/materialIDList lengths do not match."
                analysisHasConflict = true
                false
            )
            else
            (
                for slotIndex = 1 to materialCount do
                (
                    local subMaterial = masterMaterial.materialList[slotIndex]
                    if subMaterial != undefined do
                    (
                        local materialID = masterMaterial.materialIDList[slotIndex]
                        local materialName = safeMaterialName subMaterial
                        local stateText = "MASTER"

                        if materialName.count == 0 then
                        (
                            stateText = "CONFLICT : EMPTY NAME"
                            analysisHasConflict = true
                        )
                        else if findCanonicalRowByName materialName rows:canonicalRows > 0 then
                        (
                            stateText = "DUPLICATE NAME"
                            analysisHasConflict = true
                            local previousIndex = findCanonicalRowByName materialName rows:canonicalRows
                            canonicalRows[previousIndex][4] = "DUPLICATE NAME"
                            canonicalRows[previousIndex][5] = #conflict
                        )

                        if findCanonicalRowByID materialID rows:canonicalRows > 0 then
                        (
                            stateText = "CONFLICT : DUPLICATE ID"
                            analysisHasConflict = true
                            local previousIDIndex = findCanonicalRowByID materialID rows:canonicalRows
                            canonicalRows[previousIDIndex][4] = "CONFLICT : DUPLICATE ID"
                            canonicalRows[previousIDIndex][5] = #conflict
                        )

                        append canonicalRows #(materialID, materialName, subMaterial, stateText,
                            (if stateText == "MASTER" then #master else #conflict), masterNode, slotIndex,
                            materialClassText subMaterial, effectiveMaterialClassText subMaterial,
                            readComparableDiffuse subMaterial)
                    )
                )

                canonicalRows = sortCanonicalRowsByID canonicalRows
                if canonicalRows.count == 0 then
                (
                    setStatus "MASTER Multi/Sub-Object material has no defined sub-materials."
                    analysisHasConflict = true
                    false
                )
                else true
            )
        )
    )

    fn ensureVirtualCanonical materialName materialReference sourceNode =
    (
        local rowIndex = findCanonicalRowByName materialName
        if rowIndex > 0 then
        (
            local matchState = if isClassConflictName materialName then
                "CLASS CONFLICT"
            else if isDiffuseConflictName materialName then
                "COLOR CONFLICT"
            else
                "MATCH"
            #(canonicalRows[rowIndex][1], matchState)
        )
        else
        (
            local newID = (maxCanonicalID canonicalRows) + 1
            if newID > 60000 do
                throw "Cannot append a material because the next Material ID exceeds MAXScript's 60,000 limit."
            append canonicalRows #(newID, materialName, materialReference,
                ("PENDING APPEND : " + sourceNode.name), #pending, sourceNode, 0,
                materialClassText materialReference, effectiveMaterialClassText materialReference,
                readComparableDiffuse materialReference)
            pendingCount += 1
            #(newID, "PENDING APPEND")
        )
    )

    fn analyzeMultiTarget nodeValue materialValue =
    (
        local materialRows = getDefinedMultiRows materialValue
        local remapRows = #()
        local targetError = ""

        if materialValue.materialList.count != materialValue.materialIDList.count then
            targetError = "materialList/materialIDList lengths do not match."

        for materialRow in materialRows while targetError == "" do
        (
            local oldID = materialRow[1]
            local materialName = materialRow[2]
            local materialReference = materialRow[3]

            if materialName.count == 0 then
                targetError = "Material ID " + (oldID as string) + " has an empty material name."
            else
            (
                local sameIDRows = findMultiRowByID materialRows oldID
                if sameIDRows.count > 1 then
                    targetError = "Material ID " + (oldID as string) + " is assigned to multiple sub-material slots."
                else
                (
                    local canonicalResult = ensureVirtualCanonical materialName materialReference nodeValue
                    append remapRows #(oldID, materialName, canonicalResult[1], canonicalResult[2], materialReference,
                        materialClassText materialReference, effectiveMaterialClassText materialReference,
                        readComparableDiffuse materialReference)
                    if canonicalResult[2] == "MATCH" do matchedCount += 1
                )
            )
        )

        if targetError == "" do
        (
            local faceIDs = getUniqueFaceIDs nodeValue
            for faceID in faceIDs while targetError == "" do
            (
                if (findMultiRowByID materialRows faceID).count == 0 do
                    targetError = "Face Material ID " + (faceID as string) + " has no defined target sub-material."
            )
        )

        if targetError == "" then
            #(nodeValue, "READY", "Ready", remapRows, true)
        else
            #(nodeValue, "ERROR", targetError, remapRows, false)
    )

    fn analyzeSingleTarget nodeValue materialValue =
    (
        local materialName = safeMaterialName materialValue
        if materialName.count == 0 then
            #(nodeValue, "ERROR", "The single material has an empty name.", #(), false)
        else
        (
            local canonicalResult = ensureVirtualCanonical materialName materialValue nodeValue
            local remapRows = #()
            local faceIDs = getUniqueFaceIDs nodeValue
            for faceID in faceIDs do
                append remapRows #(faceID, materialName, canonicalResult[1], canonicalResult[2], materialValue,
                    materialClassText materialValue, effectiveMaterialClassText materialValue,
                    readComparableDiffuse materialValue)
            if canonicalResult[2] == "MATCH" do matchedCount += 1
            #(nodeValue, "READY", "Ready (single material)", remapRows, true)
        )
    )

    fn analyzeTarget nodeValue =
    (
        if not isValidStoredNode nodeValue then
            #(nodeValue, "INVALID", "The Target node is invalid.", #(), false)
        else if nodeValue.material == undefined then
            #(nodeValue, "NO MATERIAL", "Skipped: no material assigned.", #(), false)
        else if not isEditablePolyNode nodeValue then
            #(nodeValue, "UNSUPPORTED", "Skipped: the base object is not Editable Poly.", #(), false)
        else
        (
            try
            (
                if isMultiMaterial nodeValue.material then
                    analyzeMultiTarget nodeValue nodeValue.material
                else
                    analyzeSingleTarget nodeValue nodeValue.material
            )
            catch
            (
                #(nodeValue, "ERROR", ("Analysis failed: " + exceptionText()), #(), false)
            )
        )
    )

    fn refreshTargetList =
    (
        local selectedNodes = #()
        local previousSelection = lbTargets.selection
        for indexValue = 1 to targetNodes.count where previousSelection[indexValue] do
            append selectedNodes targetNodes[indexValue]

        cleanStoredNodes()
        local itemNames = #()
        for nodeValue in targetNodes do
        (
            local analysis = findTargetAnalysis nodeValue
            local suffix = if analysis == undefined then "" else "  [" + analysis[2] + "]"
            append itemNames (nodeValue.name + suffix)
        )
        lbTargets.items = itemNames

        local restoredSelection = #{}
        for indexValue = 1 to targetNodes.count where (findItem selectedNodes targetNodes[indexValue]) > 0 do
            restoredSelection[indexValue] = true
        lbTargets.selection = restoredSelection
    )

    fn refreshMasterUI =
    (
        cleanStoredNodes()
        lblMaster.text = if isValidStoredNode masterNode then
            "Master Object: " + masterNode.name
        else
            "Master Object: Not set"
    )

    fn refreshCanonicalTable =
    (
        clearListView lvCanonical
        canonicalRows = sortCanonicalRowsByID canonicalRows
        lvCanonical.beginUpdate()
        for rowValue in canonicalRows do
            addListViewRow lvCanonical #(
                (rowValue[1] as string),
                rowValue[2],
                preprocessMaterialTypeText rowValue[3],
                canonicalStatusText rowValue
            )
        lvCanonical.endUpdate()
    )

    fn refreshPreview targetIndex:0 =
    (
        clearListView lvRemap
        local selectedIndex = targetIndex
        if selectedIndex == 0 and lbTargets.selection.numberSet > 0 do
            selectedIndex = (lbTargets.selection as array)[1]

        if selectedIndex < 1 or selectedIndex > targetNodes.count then
            lblPreviewTarget.text = "Target: Select one target from the list"
        else
        (
            local nodeValue = targetNodes[selectedIndex]
            local analysis = findTargetAnalysis nodeValue
            if analysis == undefined then
                lblPreviewTarget.text = "Target: " + nodeValue.name + " (run Analyze)"
            else
            (
                lblPreviewTarget.text = "Target: " + nodeValue.name + " | " + analysis[2] + " | " + analysis[3]
                lvRemap.beginUpdate()
                for remapRow in analysis[4] do
                    addListViewRow lvRemap #((remapRow[1] as string), remapRow[2], (remapRow[3] as string), remapStatusText remapRow)
                lvRemap.endUpdate()
            )
        )
    )

    fn refreshSummary =
    (
        local masterName = if isValidStoredNode masterNode then masterNode.name else "None"
        lblSummary.text = "MASTER: " + masterName +
            " | Targets: " + (targetNodes.count as string) +
            " | Materials: " + (canonicalRows.count as string) +
            " | Matched: " + (matchedCount as string) +
            " | Pending Append: " + (pendingCount as string)
        lblConversionSummary.text = "USD: " + (usdMaterialCount as string) +
            " | Existing VRay: " + (existingVRayCount as string) +
            " | Unsupported: " + (unsupportedMaterialCount as string) +
            " | Texture Ignored: " + (textureIgnoredCount as string) +
            " | Class/Color Conflicts: " + (classConflictCount as string) + "/" + (preprocessConflictCount as string)
    )

    fn refreshAllUI =
    (
        refreshMasterUI()
        refreshTargetList()
        refreshCanonicalTable()
        refreshPreview()
        refreshSummary()
    )

    fn invalidateAnalysis message =
    (
        canonicalRows = #()
        targetAnalyses = #()
        matchedCount = 0
        pendingCount = 0
        scopedMaterials = #()
        conversionPlan = #()
        diffuseConflictNames = #()
        classConflictNames = #()
        usdMaterialCount = 0
        existingVRayCount = 0
        unsupportedMaterialCount = 0
        textureIgnoredCount = 0
        preprocessConflictCount = 0
        classConflictCount = 0
        preprocessErrorText = ""
        lastSkippedCount = 0
        analysisReady = false
        analysisHasConflict = false
        refreshAllUI()
        if message != "" do setStatus message
    )

    fn setMasterNode nodeValue =
    (
        if not isValidStoredNode nodeValue then
        (
            setStatus "Select one valid object for Master."
            false
        )
        else
        (
            masterNode = nodeValue
            for indexValue = targetNodes.count to 1 by -1 where targetNodes[indexValue] == masterNode do
                deleteItem targetNodes indexValue
            invalidateAnalysis ("MASTER set: " + masterNode.name)
            true
        )
    )

    fn clearMasterNode =
    (
        masterNode = undefined
        invalidateAnalysis "MASTER cleared."
        true
    )

    fn captureMasterFromSelection =
    (
        if selection.count != 1 then
        (
            setStatus "Select exactly one object, then press Set Master."
            false
        )
        else setMasterNode selection[1]
    )

    fn addTargetNodes nodesToAdd =
    (
        local addedCount = 0
        for nodeValue in nodesToAdd do
        (
            if isValidStoredNode nodeValue and nodeValue != masterNode and (findItem targetNodes nodeValue) == 0 do
            (
                append targetNodes nodeValue
                addedCount += 1
            )
        )
        invalidateAnalysis ("Added " + (addedCount as string) + " Target(s).")
        addedCount
    )

    fn addSelectedTargets =
    (
        addTargetNodes (for nodeValue in selection collect nodeValue)
    )

    fn removeSelectedTargets =
    (
        local selectedIndices = lbTargets.selection
        local removedCount = selectedIndices.numberSet
        for indexValue = targetNodes.count to 1 by -1 where selectedIndices[indexValue] do
            deleteItem targetNodes indexValue
        invalidateAnalysis ("Removed " + (removedCount as string) + " Target(s).")
        removedCount
    )

    fn clearTargetNodes =
    (
        targetNodes = #()
        invalidateAnalysis "Targets cleared."
        true
    )

    fn analyzeAll updateUI:true recordOperation:false =
    (
        if recordOperation do
        (
            lastOperation = #analyze
            lastSyncedSlotCount = 0
        )
        cleanStoredNodes()
        targetAnalyses = #()
        matchedCount = 0
        pendingCount = 0
        lastSkippedCount = 0
        analysisReady = false

        local preprocessOK = analyzePreprocess()
        local masterOK = buildMasterCanonical()
        if not masterOK then
        (
            if updateUI do refreshAllUI()
            false
        )
        else if targetNodes.count == 0 then
        (
            setStatus "Add at least one Target."
            if updateUI do refreshAllUI()
            false
        )
        else
        (
            for nodeValue in targetNodes do append targetAnalyses (analyzeTarget nodeValue)
            canonicalRows = sortCanonicalRowsByID canonicalRows
            analysisReady = not analysisHasConflict and preprocessOK

            local readyTargets = 0
            local skippedTargets = 0
            local errorTargets = 0
            for analysis in targetAnalyses do
            (
                if analysis[5] then readyTargets += 1
                else if analysis[2] == "NO MATERIAL" or analysis[2] == "UNSUPPORTED" then skippedTargets += 1
                else errorTargets += 1
            )
            lastSkippedCount = skippedTargets

            if readyTargets == 0 do analysisReady = false
            if errorTargets > 0 do analysisReady = false

            if classConflictCount > 0 then
                setStatus ("CLASS CONFLICT: SAME NAME / DIFFERENT EFFECTIVE CLASS in " + (classConflictCount as string) + " material name(s). Apply is blocked.")
            else if preprocessConflictCount > 0 then
                setStatus ("COLOR CONFLICT: SAME NAME / DIFFERENT DIFFUSE in " + (preprocessConflictCount as string) + " material name(s). Apply is blocked.")
            else if not preprocessOK then
                setStatus (if preprocessErrorText != "" then preprocessErrorText else "ERROR: USD preprocess validation failed. Scene was not changed.")
            else if analysisHasConflict then
                setStatus "MASTER has duplicate/conflicting names or IDs. Apply is blocked."
            else if errorTargets > 0 then
                setStatus ("Analyze found " + (errorTargets as string) + " error Target(s). Apply is blocked.")
            else if readyTargets == 0 then
                setStatus "No applicable Target remains."
            else
                setStatus ("Analyze complete: " + (readyTargets as string) + " ready, " +
                    (skippedTargets as string) + " skipped, " + (pendingCount as string) + " pending append.")

            btnApply.enabled = analysisReady
            if updateUI do refreshAllUI()
            analysisReady
        )
    )

    fn appendPendingMaterials masterMaterial =
    (
        local appendedCount = 0
        for rowValue in canonicalRows where rowValue[5] == #pending do
        (
            local newSlot = masterMaterial.materialList.count + 1
            masterMaterial.materialList.count = newSlot
            masterMaterial.materialIDList.count = newSlot
            masterMaterial.names.count = newSlot
            masterMaterial.mapEnabled.count = newSlot
            masterMaterial.materialList[newSlot] = rowValue[3]
            masterMaterial.materialIDList[newSlot] = rowValue[1]
            masterMaterial.names[newSlot] = rowValue[2]
            masterMaterial.mapEnabled[newSlot] = true
            appendedCount += 1
        )
        appendedCount
    )

    fn remapTargetFaces nodeValue remapRows =
    (
        local faceCount = polyop.getNumFaces nodeValue
        local facesByMapping = #()
        for remapRow in remapRows do append facesByMapping #{}

        for faceIndex = 1 to faceCount do
        (
            local oldID = polyop.getFaceMatID nodeValue faceIndex
            local mappingIndex = 0
            for indexValue = 1 to remapRows.count while mappingIndex == 0 do
            (
                if remapRows[indexValue][1] == oldID do mappingIndex = indexValue
            )
            if mappingIndex == 0 then
                throw ("Face " + (faceIndex as string) + " uses unmapped Material ID " + (oldID as string) + ".")
            else
                facesByMapping[mappingIndex][faceIndex] = true
        )

        for indexValue = 1 to remapRows.count where facesByMapping[indexValue].numberSet > 0 do
            polyop.setFaceMatID nodeValue facesByMapping[indexValue] remapRows[indexValue][3]
        true
    )

    fn verifyTarget nodeValue remapRows masterMaterial =
    (
        local verified = nodeValue.material == masterMaterial
        if verified do
        (
            local faceCount = polyop.getNumFaces nodeValue
            for faceIndex = 1 to faceCount while verified do
            (
                local currentID = polyop.getFaceMatID nodeValue faceIndex
                local isExpected = false
                for remapRow in remapRows where remapRow[3] == currentID do
                (
                    isExpected = true
                    exit
                )
                if not isExpected do verified = false
            )
        )
        verified
    )

    fn formatColorValue colorValue =
    (
        if colorValue == undefined then
            "N/A"
        else
            ((colorValue.r as integer) as string) + "," +
            ((colorValue.g as integer) as string) + "," +
            ((colorValue.b as integer) as string)
    )

    fn formatDiffuseInfo diffuseInfo =
    (
        if diffuseInfo != undefined and diffuseInfo.count >= 2 and diffuseInfo[1] then
            formatColorValue diffuseInfo[2]
        else
            "N/A"
    )

    fn operationLabel operationValue =
    (
        case operationValue of
        (
            #analyze: "ANALYZE"
            #convertOnly: "CONVERT ONLY"
            #normalize: "NORMALIZE/APPLY"
            #globalAZAnalyze: "GLOBAL A-Z ANALYZE"
            #globalAZReindex: "GLOBAL A-Z REINDEX"
            default: "NONE"
        )
    )

    fn operationFilenamePart operationValue =
    (
        case operationValue of
        (
            #convertOnly: "ConvertOnly"
            #normalize: "Normalize"
            #globalAZAnalyze: "GlobalAZAnalyze"
            #globalAZReindex: "GlobalAZReindex"
            default: "Analyze"
        )
    )

    fn reportTimestamp filenameSafe:false =
    (
        local dateTimeClass = dotNetClass "System.DateTime"
        if filenameSafe then
            dateTimeClass.Now.ToString "yyyyMMdd_HHmmss"
        else
            dateTimeClass.Now.ToString "yyyy-MM-dd HH:mm:ss"
    )

    fn sceneDisplayPath =
    (
        if maxFileName == "" then "<Unsaved Scene>" else maxFilePath + maxFileName
    )

    fn reportDefaultPath =
    (
        local sceneBase = if maxFileName == "" then "Untitled" else getFilenameFile maxFileName
        local reportName = sceneBase + "_MaterialNormalize_" + operationFilenamePart lastOperation + "_" +
            reportTimestamp filenameSafe:true + ".txt"
        local reportDirectory = if maxFilePath != "" then maxFilePath else getDir #export
        if reportDirectory == undefined or reportDirectory == "" or not doesDirectoryExist reportDirectory do
            reportDirectory = getDir #userScripts
        if reportDirectory == undefined or reportDirectory == "" or not doesDirectoryExist reportDirectory do
            reportDirectory = (dotNetClass "System.IO.Path").GetTempPath()
        (pathConfig.appendPath (reportDirectory as string) reportName) as string
    )

    fn isValidReportSeedPath reportPath =
    (
        reportPath != undefined and classOf reportPath == String and reportPath.count > 0 and
            doesDirectoryExist (getFilenamePath reportPath)
    )

    fn buildReportText =
    (
        local reportText = ""
        local newLine = "\r\n"
        local masterName = if isValidStoredNode masterNode then masterNode.name else "None"
        local predictedConversionCount = if lastOperation == #analyze then conversionPlan.count else lastApplyConvertedCount
        local appendedDisplayCount = if lastOperation == #normalize then lastApplyAppendedCount else pendingCount
        local reportMaterialCount = if lastOperation == #convertOnly then lastConvertOnlyMaterialCount else canonicalRows.count
        local reportUSDCount = if lastOperation == #convertOnly then lastConvertOnlyUSDCount else usdMaterialCount
        local reportExistingVRayCount = if lastOperation == #convertOnly then lastConvertOnlyExistingVRayCount else existingVRayCount
        local reportUnsupportedCount = if lastOperation == #convertOnly then lastConvertOnlyUnsupportedCount else unsupportedMaterialCount
        local reportSkippedCount = if lastOperation == #convertOnly then lastConvertOnlySkippedCount else lastSkippedCount

        reportText += "Lunar Material ID Normalizer Report" + newLine
        reportText += "Tool Version: MK2" + newLine
        reportText += "Report Format Version: 1" + newLine
        reportText += "Scene Path: " + sceneDisplayPath() + newLine
        reportText += "Generated: " + reportTimestamp() + newLine
        reportText += "Last Operation: " + operationLabel lastOperation + newLine + newLine

        reportText += "[PREPROCESS SETTINGS]" + newLine
        reportText += "Convert USD -> VRay: " + (if chkConvertUSD.checked then "ON" else "OFF") + newLine
        reportText += "Override Glossiness: " + (if chkOverrideGlossiness.checked then "ON" else "OFF") + newLine
        reportText += "Glossiness Value: " + formattedPrint spnGlossiness.value format:".2f" + newLine
        reportText += "Override Reflection: " + (if chkOverrideReflection.checked then "ON" else "OFF") + newLine
        reportText += "Reflection RGB: " + formatColorValue cpReflection.color + newLine
        reportText += "Sync Multi/Sub Slot Names: " + (if chkSyncSlotNames.checked then "ON" else "OFF") + newLine + newLine

        reportText += "[MASTER]" + newLine + masterName + newLine + newLine
        reportText += "[TARGETS]" + newLine
        if targetNodes.count == 0 then reportText += "None" + newLine
        for nodeValue in targetNodes do
            reportText += (if isValidStoredNode nodeValue then nodeValue.name else "<Invalid Node>") + newLine
        reportText += newLine

        if lastOperation == #convertOnly do
        (
            reportText += "[CONVERT ONLY SELECTION]" + newLine
            for nodeName in lastConvertOnlyNodeNames do reportText += nodeName + newLine
            if lastConvertOnlyNodeNames.count == 0 do reportText += "None" + newLine
            reportText += newLine
        )

        reportText += "[SUMMARY]" + newLine
        reportText += "Material Count: " + (reportMaterialCount as string) + newLine
        reportText += "USD Material Count: " + (reportUSDCount as string) + newLine
        reportText += "Existing VRayMtl Count: " + (reportExistingVRayCount as string) + newLine
        reportText += "Unsupported Count: " + (reportUnsupportedCount as string) + newLine
        reportText += "Converted Count: " + (predictedConversionCount as string) + newLine
        reportText += "Matched Count: " + (matchedCount as string) + newLine
        reportText += "Pending/Appended Count: " + (appendedDisplayCount as string) + newLine
        reportText += "Class Conflict Count: " + (classConflictCount as string) + newLine
        reportText += "Color Conflict Count: " + (preprocessConflictCount as string) + newLine
        reportText += "Skipped Count: " + (reportSkippedCount as string) + newLine
        reportText += "Slot Names Updated: " + (lastSyncedSlotCount as string) + newLine + newLine

        reportText += "[CANONICAL MATERIAL TABLE]" + newLine
        reportText += "ID\tMaterial Name\tRaw Class\tEffective / Final Class\tSource / Status" + newLine
        for rowValue in canonicalRows do
            reportText += (rowValue[1] as string) + "\t" + rowValue[2] + "\t" + rowValue[8] + "\t" + rowValue[9] + "\t" + canonicalStatusText rowValue + newLine
        reportText += newLine

        reportText += "[PER TARGET REMAP TABLE]" + newLine
        for analysis in targetAnalyses do
        (
            reportText += "Target Object: " + (if isValidStoredNode analysis[1] then analysis[1].name else "<Invalid Node>") + newLine
            reportText += "Old ID\tMaterial Name\tRaw Class\tEffective Class\tNew ID\tStatus" + newLine
            for remapRow in analysis[4] do
                reportText += (remapRow[1] as string) + "\t" + remapRow[2] + "\t" + remapRow[6] + "\t" + remapRow[7] + "\t" + (remapRow[3] as string) + "\t" + remapStatusText remapRow + newLine
            if analysis[4].count == 0 do reportText += "-\t-\t-\t-\t-\t" + analysis[2] + " / " + analysis[3] + newLine
            reportText += newLine
        )

        reportText += "[MATERIAL CONVERSION TABLE]" + newLine
        reportText += "Source Material\tSource Class\tConverted Material\tFinal Class\tDiffuse\tGlossiness Override\tReflection Override" + newLine
        if lastOperation == #analyze then
        (
            for sourceMaterial in conversionPlan do
                reportText += safeMaterialName sourceMaterial + "\t" + materialClassText sourceMaterial + "\t" + safeMaterialName sourceMaterial + "\tVRayMtl\t" + formatDiffuseInfo (readComparableDiffuse sourceMaterial) + "\t" +
                    (if chkOverrideGlossiness.checked then formattedPrint spnGlossiness.value format:".2f" else "OFF") + "\t" +
                    (if chkOverrideReflection.checked then formatColorValue cpReflection.color else "OFF") + newLine
        )
        else
        (
            for conversionRow in lastConversionRows do
                reportText += conversionRow[1] + "\t" + conversionRow[2] + "\t" + conversionRow[3] + "\t" + conversionRow[4] + "\t" +
                    formatDiffuseInfo conversionRow[5] + "\t" + conversionRow[6] + "\t" + conversionRow[7] + newLine
        )
        if (if lastOperation == #analyze then conversionPlan.count else lastConversionRows.count) == 0 do reportText += "None" + newLine
        reportText += newLine

        reportText += "[APPENDED MATERIALS]" + newLine
        if lastOperation == #normalize then
        (
            for rowValue in lastAppendedRows do reportText += (rowValue[1] as string) + "\t" + rowValue[2] + newLine
            if lastAppendedRows.count == 0 do reportText += "None" + newLine
        )
        else
        (
            local pendingFound = false
            for rowValue in canonicalRows where rowValue[5] == #pending do
            (
                reportText += (rowValue[1] as string) + "\t" + rowValue[2] + "\tPENDING" + newLine
                pendingFound = true
            )
            if not pendingFound do reportText += "None" + newLine
        )
        reportText += newLine

        reportText += "[CONFLICTS / WARNINGS]" + newLine
        for conflictName in classConflictNames do reportText += "CLASS CONFLICT\t" + conflictName + newLine
        for conflictName in diffuseConflictNames do reportText += "COLOR CONFLICT\t" + conflictName + newLine
        if lastOperation == #convertOnly then
        (
            for unsupportedRow in lastConvertOnlyUnsupportedRows do
                reportText += "UNSUPPORTED / KEEP\t" + unsupportedRow[1] + "\t" + unsupportedRow[2] + newLine
        )
        else
        (
            for materialValue in scopedMaterials where not isUSDPreviewMaterial materialValue and not isVRayMaterial materialValue do
                reportText += "UNSUPPORTED / KEEP\t" + safeMaterialName materialValue + "\t" + materialClassText materialValue + newLine
        )
        for materialValue in scopedMaterials where materialHasTextureDrivenDiffuse materialValue do
            reportText += "TEXTURE IGNORED\t" + safeMaterialName materialValue + newLine
        if lastOperation != #analyze do
        (
            for materialName in lastTextureIgnoredNames do
                reportText += "TEXTURE IGNORED DURING CONVERSION\t" + materialName + newLine
        )
        for analysis in targetAnalyses where not analysis[5] do
            reportText += analysis[2] + "\t" + (if isValidStoredNode analysis[1] then analysis[1].name else "<Invalid Node>") + "\t" + analysis[3] + newLine
        local isGlobalAZReport = lastOperation == #globalAZAnalyze or lastOperation == #globalAZReindex
        if isGlobalAZReport do
        (
            for conflictRow in lastGlobalAZConflictRows do
                reportText += conflictRow[1] + "\t" + conflictRow[2] + "\t" + conflictRow[3] + newLine
        )
        if classConflictNames.count == 0 and diffuseConflictNames.count == 0 and reportUnsupportedCount == 0 and textureIgnoredCount == 0 and
            (lastOperation == #analyze or lastTextureIgnoredNames.count == 0) and lastSkippedCount == 0 and
            (not isGlobalAZReport or lastGlobalAZConflictRows.count == 0) do
            reportText += "None" + newLine

        if isGlobalAZReport do
        (
            reportText += newLine + "[GLOBAL A-Z REINDEX]" + newLine
            reportText += "Selected Object Count: " + (lastGlobalAZSelectedNames.count as string) + newLine
            reportText += "Global Material Count: " + (lastGlobalAZRegistryRows.count as string) + newLine
            for nodeName in lastGlobalAZSelectedNames do reportText += "Selected Object\t" + nodeName + newLine
            reportText += "New ID\tMaterial Name\tOld IDs\tClass\tUsed By\tStatus" + newLine
            for registryRow in lastGlobalAZRegistryRows do
                reportText += registryRow[1] + "\t" + registryRow[2] + "\t" + registryRow[3] + "\t" +
                    registryRow[4] + "\t" + registryRow[5] + "\t" + registryRow[6] + newLine
            if lastGlobalAZRegistryRows.count == 0 do reportText += "None" + newLine

            reportText += newLine + "[PER OBJECT A-Z REMAP]" + newLine
            for objectGroup in lastGlobalAZObjectRows do
            (
                reportText += "Object: " + objectGroup[1] + newLine
                reportText += "Old ID\tMaterial Name\tNew ID\tStatus" + newLine
                for remapRow in objectGroup[2] do
                    reportText += remapRow[1] + "\t" + remapRow[2] + "\t" + remapRow[3] + "\t" + remapRow[4] + newLine
                reportText += newLine
            )
            if lastGlobalAZObjectRows.count == 0 do reportText += "None" + newLine
        )

        reportText
    )

    /* Loaded reports are deliberately value-only snapshots.
       Model indices:
       1 format version, 2 metadata pairs, 3 preprocess pairs, 4 master lines,
       5 target lines, 6 summary pairs, 7 canonical rows, 8 target remap groups,
       9 conversion rows, 10 appended rows, 11 report warnings,
       12 parser warnings, 13 Convert Only selection lines, 14 source path,
       15 optional Global A-Z data, 16 optional per-object A-Z groups.
       No scene node or material reference is stored in this model. */

    fn trimReportText textValue =
    (
        if textValue == undefined then
            ""
        else
        (
            local value = textValue as string
            local firstIndex = 1
            local lastIndex = value.count
            while firstIndex <= lastIndex and (findString " \t\r\n" value[firstIndex]) != undefined do firstIndex += 1
            while lastIndex >= firstIndex and (findString " \t\r\n" value[lastIndex]) != undefined do lastIndex -= 1
            if lastIndex < firstIndex then "" else substring value firstIndex (lastIndex - firstIndex + 1)
        )
    )

    fn reportTextStartsWith textValue prefixValue =
    (
        textValue != undefined and prefixValue != undefined and textValue.count >= prefixValue.count and
            substring textValue 1 prefixValue.count == prefixValue
    )

    fn splitReportTextLines reportText =
    (
        local normalized = substituteString (substituteString reportText "\r\n" "\n") "\r" "\n"
        local lines = #()
        local currentLine = ""
        for charIndex = 1 to normalized.count do
        (
            if normalized[charIndex] == "\n" then
            (
                append lines currentLine
                currentLine = ""
            )
            else
                currentLine += normalized[charIndex]
        )
        append lines currentLine
        lines
    )

    fn splitReportTabs lineValue =
    (
        local values = #()
        local currentValue = ""
        for charIndex = 1 to lineValue.count do
        (
            if lineValue[charIndex] == "\t" then
            (
                append values currentValue
                currentValue = ""
            )
            else
                currentValue += lineValue[charIndex]
        )
        append values currentValue
        values
    )

    fn isReportIntegerText textValue =
    (
        local value = trimReportText textValue
        local firstDigit = 1
        local valid = value.count > 0
        if valid and (value[1] == "+" or value[1] == "-") do firstDigit = 2
        if firstDigit > value.count then valid = false
        if valid do
        (
            for charIndex = firstDigit to value.count while valid do
                if (findString "0123456789" value[charIndex]) == undefined do valid = false
        )
        valid
    )

    fn reportPairValue pairs keyValue =
    (
        local result = ""
        for pairValue in pairs while result == "" do
            if pairValue.count >= 2 and pairValue[1] == keyValue do result = pairValue[2]
        result
    )

    fn parseReportPairs lines sectionLabel warnings:#() =
    (
        local pairs = #()
        for lineValue in lines do
        (
            local cleanLine = trimReportText lineValue
            if cleanLine != "" and cleanLine != "None" do
            (
                local colonIndex = findString cleanLine ":"
                if colonIndex == undefined then
                    append warnings (sectionLabel + ": ignored malformed key/value row: " + cleanLine)
                else
                (
                    local keyValue = trimReportText (substring cleanLine 1 (colonIndex - 1))
                    local valueStart = colonIndex + 1
                    local pairText = if valueStart > cleanLine.count then "" else trimReportText (substring cleanLine valueStart (cleanLine.count - valueStart + 1))
                    if keyValue == "" then
                        append warnings (sectionLabel + ": ignored a row with an empty key.")
                    else
                        append pairs #(keyValue, pairText)
                )
            )
        )
        pairs
    )

    fn reportSectionLines sections sectionName =
    (
        local result = #()
        for sectionValue in sections while result.count == 0 do
            if sectionValue[1] == sectionName do result = sectionValue[2]
        result
    )

    fn normalizeReportColumns values expectedCount sectionLabel warnings =
    (
        local result = for value in values collect value
        if result.count < expectedCount do
        (
            append warnings (sectionLabel + ": a malformed row had " + (result.count as string) + " of " + (expectedCount as string) + " columns.")
            while result.count < expectedCount do append result ""
        )
        if result.count > expectedCount do
        (
            append warnings (sectionLabel + ": a row had extra columns; extras were preserved in the final column.")
            local mergedValue = result[expectedCount]
            for valueIndex = expectedCount + 1 to result.count do mergedValue += " | " + result[valueIndex]
            result = for valueIndex = 1 to expectedCount collect (if valueIndex == expectedCount then mergedValue else result[valueIndex])
        )
        result
    )

    fn parseReportTable lines expectedCount sectionLabel headerPrefix:"" integerColumns:#() =
    (
        local rows = #()
        local warnings = #()
        for lineValue in lines do
        (
            local cleanLine = trimReportText lineValue
            if cleanLine != "" and cleanLine != "None" and (headerPrefix == "" or not reportTextStartsWith cleanLine headerPrefix) do
            (
                local rowValue = normalizeReportColumns (splitReportTabs lineValue) expectedCount sectionLabel warnings
                for columnIndex in integerColumns do
                (
                    local integerText = trimReportText rowValue[columnIndex]
                    if integerText != "-" and not isReportIntegerText integerText do
                        append warnings (sectionLabel + ": invalid integer '" + integerText + "' was kept as text.")
                )
                append rows rowValue
            )
        )
        #(rows, warnings)
    )

    fn parseTargetRemapSection lines =
    (
        local groups = #()
        local warnings = #()
        local currentTarget = ""
        local currentRows = #()

        for lineValue in lines do
        (
            local cleanLine = trimReportText lineValue
            if reportTextStartsWith cleanLine "Target Object:" then
            (
                if currentTarget != "" do append groups #(currentTarget, currentRows)
                currentTarget = trimReportText (substring cleanLine 15 (cleanLine.count - 14))
                if currentTarget == "" do currentTarget = "<Unnamed Target>"
                currentRows = #()
            )
            else if cleanLine != "" and not reportTextStartsWith cleanLine "Old ID\tMaterial Name" do
            (
                if currentTarget == "" then
                    append warnings ("PER TARGET REMAP TABLE: ignored a row before any Target Object header: " + cleanLine)
                else
                (
                    local parsedRow = parseReportTable #(lineValue) 6 "PER TARGET REMAP TABLE" integerColumns:#(1,5)
                    for rowValue in parsedRow[1] do append currentRows rowValue
                    for warningValue in parsedRow[2] do append warnings warningValue
                )
            )
        )
        if currentTarget != "" do append groups #(currentTarget, currentRows)
        #(groups, warnings)
    )

    fn parseGlobalAZReportSection lines =
    (
        local pairs = #()
        local selectedNames = #()
        local rows = #()
        local warnings = #()
        for lineValue in lines do
        (
            local cleanLine = trimReportText lineValue
            if reportTextStartsWith cleanLine "Selected Object Count:" or reportTextStartsWith cleanLine "Global Material Count:" then
            (
                local pairResult = parseReportPairs #(lineValue) "GLOBAL A-Z REINDEX" warnings:warnings
                for pairValue in pairResult do append pairs pairValue
            )
            else if reportTextStartsWith cleanLine "Selected Object\t" then
            (
                local values = splitReportTabs lineValue
                if values.count >= 2 then append selectedNames values[2] else append warnings "GLOBAL A-Z REINDEX: malformed Selected Object row."
            )
            else if cleanLine != "" and cleanLine != "None" and not reportTextStartsWith cleanLine "New ID\tMaterial Name" do
            (
                local tableResult = parseReportTable #(lineValue) 6 "GLOBAL A-Z REINDEX" integerColumns:#(1,5)
                for rowValue in tableResult[1] do append rows rowValue
                for warningValue in tableResult[2] do append warnings warningValue
            )
        )
        #(#(pairs, selectedNames, rows), warnings)
    )

    fn parsePerObjectAZReportSection lines =
    (
        local groups = #()
        local warnings = #()
        local currentObject = ""
        local currentRows = #()
        for lineValue in lines do
        (
            local cleanLine = trimReportText lineValue
            if reportTextStartsWith cleanLine "Object:" then
            (
                if currentObject != "" do append groups #(currentObject, currentRows)
                currentObject = trimReportText (substring cleanLine 8 (cleanLine.count - 7))
                if currentObject == "" do currentObject = "<Unnamed Object>"
                currentRows = #()
            )
            else if cleanLine != "" and cleanLine != "None" and not reportTextStartsWith cleanLine "Old ID\tMaterial Name" do
            (
                if currentObject == "" then
                    append warnings ("PER OBJECT A-Z REMAP: ignored a row before any Object header: " + cleanLine)
                else
                (
                    local tableResult = parseReportTable #(lineValue) 4 "PER OBJECT A-Z REMAP" integerColumns:#(1,3)
                    for rowValue in tableResult[1] do append currentRows rowValue
                    for warningValue in tableResult[2] do append warnings warningValue
                )
            )
        )
        if currentObject != "" do append groups #(currentObject, currentRows)
        #(groups, warnings)
    )

    fn parseAppendedReportSection lines =
    (
        local rows = #()
        local warnings = #()
        for lineValue in lines do
        (
            local cleanLine = trimReportText lineValue
            if cleanLine != "" and cleanLine != "None" do
            (
                local values = splitReportTabs lineValue
                if values.count < 2 do
                (
                    append warnings ("APPENDED MATERIALS: a malformed row had " + (values.count as string) + " of at least 2 columns.")
                    while values.count < 2 do append values ""
                )
                if values.count == 2 do append values ""
                if values.count > 3 do values = normalizeReportColumns values 3 "APPENDED MATERIALS" warnings
                if not isReportIntegerText values[1] do
                    append warnings ("APPENDED MATERIALS: invalid integer '" + values[1] + "' was kept as text.")
                append rows values
            )
        )
        #(rows, warnings)
    )

    fn meaningfulReportLines lines =
    (
        for lineValue in lines where trimReportText lineValue != "" and trimReportText lineValue != "None" collect lineValue
    )

    fn parseReportText reportText =
    (
        if reportText == undefined or classOf reportText != String or trimReportText reportText == "" then
            #(false, "The selected report is empty.", undefined)
        else
        (
            local lines = splitReportTextLines reportText
            local firstMeaningfulIndex = 0
            for lineIndex = 1 to lines.count while firstMeaningfulIndex == 0 do
                if trimReportText lines[lineIndex] != "" do firstMeaningfulIndex = lineIndex

            if firstMeaningfulIndex == 0 or trimReportText lines[firstMeaningfulIndex] != "Lunar Material ID Normalizer Report" then
                #(false, "This file is not a Lunar Material ID Normalizer report.", undefined)
            else
            (
                local preambleLines = #()
                local sections = #()
                local currentSection = ""
                local currentLines = #()

                for lineIndex = firstMeaningfulIndex + 1 to lines.count do
                (
                    local cleanLine = trimReportText lines[lineIndex]
                    local isHeader = cleanLine.count >= 2 and cleanLine[1] == "[" and cleanLine[cleanLine.count] == "]"
                    if isHeader then
                    (
                        if currentSection != "" do append sections #(currentSection, currentLines)
                        currentSection = substring cleanLine 2 (cleanLine.count - 2)
                        currentLines = #()
                    )
                    else if currentSection == "" then
                        append preambleLines lines[lineIndex]
                    else
                        append currentLines lines[lineIndex]
                )
                if currentSection != "" do append sections #(currentSection, currentLines)

                local recognizableSections = #("PREPROCESS SETTINGS", "MASTER", "TARGETS", "SUMMARY", "CANONICAL MATERIAL TABLE", "PER TARGET REMAP TABLE", "MATERIAL CONVERSION TABLE", "APPENDED MATERIALS", "CONFLICTS / WARNINGS", "GLOBAL A-Z REINDEX", "PER OBJECT A-Z REMAP")
                local recognizableCount = 0
                for sectionValue in sections do if findItem recognizableSections sectionValue[1] > 0 do recognizableCount += 1

                if recognizableCount == 0 then
                    #(false, "The report header is valid, but no recognized report sections were found.", undefined)
                else
                (
                    local parserWarnings = #()
                    local metadata = parseReportPairs preambleLines "REPORT HEADER" warnings:parserWarnings
                    local formatVersion = reportPairValue metadata "Report Format Version"
                    if formatVersion == "" then
                    (
                        formatVersion = "1"
                        append parserWarnings "Legacy report: Report Format Version was missing and was interpreted as version 1."
                    )

                    if formatVersion != "1" then
                        #(false, "Unsupported Report Format Version: " + formatVersion, undefined)
                    else
                    (
                        local preprocessPairs = parseReportPairs (reportSectionLines sections "PREPROCESS SETTINGS") "PREPROCESS SETTINGS" warnings:parserWarnings
                        local summaryPairs = parseReportPairs (reportSectionLines sections "SUMMARY") "SUMMARY" warnings:parserWarnings
                        local integerSummaryKeys = #("Material Count", "USD Material Count", "Existing VRayMtl Count", "Unsupported Count", "Converted Count", "Matched Count", "Pending/Appended Count", "Class Conflict Count", "Color Conflict Count", "Skipped Count", "Slot Names Updated")
                        for pairValue in summaryPairs where findItem integerSummaryKeys pairValue[1] > 0 do
                            if not isReportIntegerText pairValue[2] do append parserWarnings ("SUMMARY: invalid integer '" + pairValue[2] + "' for " + pairValue[1] + " was kept as text.")
                        local canonicalResult = parseReportTable (reportSectionLines sections "CANONICAL MATERIAL TABLE") 5 "CANONICAL MATERIAL TABLE" headerPrefix:"ID\tMaterial Name" integerColumns:#(1)
                        local remapResult = parseTargetRemapSection (reportSectionLines sections "PER TARGET REMAP TABLE")
                        local conversionResult = parseReportTable (reportSectionLines sections "MATERIAL CONVERSION TABLE") 7 "MATERIAL CONVERSION TABLE" headerPrefix:"Source Material\t"
                        local appendedResult = parseAppendedReportSection (reportSectionLines sections "APPENDED MATERIALS")
                        local globalAZResult = parseGlobalAZReportSection (reportSectionLines sections "GLOBAL A-Z REINDEX")
                        local perObjectAZResult = parsePerObjectAZReportSection (reportSectionLines sections "PER OBJECT A-Z REMAP")
                        local warningRows = #()
                        for lineValue in reportSectionLines sections "CONFLICTS / WARNINGS" where trimReportText lineValue != "" and trimReportText lineValue != "None" do
                            append warningRows (splitReportTabs lineValue)

                        for warningValue in canonicalResult[2] do append parserWarnings warningValue
                        for warningValue in remapResult[2] do append parserWarnings warningValue
                        for warningValue in conversionResult[2] do append parserWarnings warningValue
                        for warningValue in appendedResult[2] do append parserWarnings warningValue
                        for warningValue in globalAZResult[2] do append parserWarnings warningValue
                        for warningValue in perObjectAZResult[2] do append parserWarnings warningValue

                        local reportModel = #(
                            formatVersion,
                            metadata,
                            preprocessPairs,
                            meaningfulReportLines (reportSectionLines sections "MASTER"),
                            meaningfulReportLines (reportSectionLines sections "TARGETS"),
                            summaryPairs,
                            canonicalResult[1],
                            remapResult[1],
                            conversionResult[1],
                            appendedResult[1],
                            warningRows,
                            parserWarnings,
                            meaningfulReportLines (reportSectionLines sections "CONVERT ONLY SELECTION"),
                            "",
                            globalAZResult[1],
                            perObjectAZResult[1]
                        )
                        #(true, "", reportModel)
                    )
                )
            )
        )
    )

    fn addLoadedViewerPlaceholder listControl message =
    (
        addListViewRow listControl #(message)
    )

    fn loadedViewerAddRows listControl rows =
    (
        if rows.count == 0 then
            addLoadedViewerPlaceholder listControl "Not available in this report"
        else
            for rowValue in rows do addListViewRow listControl rowValue
    )

    fn onLoadedReportTargetChanged sender eventArgs =
    (
        if loadedReport != undefined and loadedReportTargetList != undefined do
        (
            local targetList = loadedReportTargetList[2]
            clearListView targetList
            local selectedIndex = sender.selectedIndex + 1
            if selectedIndex >= 1 and selectedIndex <= loadedReport[8].count then
            (
                local rows = loadedReport[8][selectedIndex][2]
                loadedViewerAddRows targetList rows
            )
            else
                addLoadedViewerPlaceholder targetList "Select a target report snapshot"
        )
    )

    fn onLoadedReportAZTargetChanged sender eventArgs =
    (
        if loadedReport != undefined and loadedReportAZTargetList != undefined do
        (
            local objectList = loadedReportAZTargetList[2]
            clearListView objectList
            local selectedIndex = sender.selectedIndex + 1
            if selectedIndex >= 1 and selectedIndex <= loadedReport[16].count then
                loadedViewerAddRows objectList loadedReport[16][selectedIndex][2]
            else
                addLoadedViewerPlaceholder objectList "Select an A-Z object snapshot"
        )
    )

    fn onLoadedReportViewerClosed sender eventArgs =
    (
        loadedReportForm = undefined
        loadedReportTargetList = undefined
        loadedReportAZTargetList = undefined
    )

    fn onLoadedReportViewerClose sender eventArgs =
    (
        if loadedReportForm != undefined do loadedReportForm.Close()
    )

    fn onLoadedReportViewerOpenAnother sender eventArgs =
    (
        loadReportWithDialog()
    )

    fn showLoadedReportViewer =
    (
        if loadedReport == undefined then
            false
        else
        (
            if loadedReportForm != undefined do try (loadedReportForm.Close()) catch()

            local form = dotNetObject "System.Windows.Forms.Form"
            form.text = "Lunar Material ID Normalizer — LOADED REPORT — READ ONLY"
            form.size = dotNetObject "System.Drawing.Size" 1040 760
            form.minimumSize = dotNetObject "System.Drawing.Size" 900 650
            form.startPosition = (dotNetClass "System.Windows.Forms.FormStartPosition").CenterScreen

            local banner = dotNetObject "System.Windows.Forms.Label"
            banner.text = "LOADED REPORT — READ ONLY     |     READ ONLY SNAPSHOT"
            banner.location = dotNetObject "System.Drawing.Point" 12 12
            banner.size = dotNetObject "System.Drawing.Size" 996 24
            banner.font = dotNetObject "System.Drawing.Font" "Segoe UI" 11.0 (dotNetClass "System.Drawing.FontStyle").Bold
            form.controls.add banner

            local pathLabel = dotNetObject "System.Windows.Forms.Label"
            pathLabel.text = "Source: " + loadedReport[14]
            pathLabel.location = dotNetObject "System.Drawing.Point" 12 40
            pathLabel.size = dotNetObject "System.Drawing.Size" 996 20
            pathLabel.autoEllipsis = true
            form.controls.add pathLabel

            local tabs = dotNetObject "System.Windows.Forms.TabControl"
            tabs.location = dotNetObject "System.Drawing.Point" 12 68
            tabs.size = dotNetObject "System.Drawing.Size" 996 594
            form.controls.add tabs

            local summaryPage = dotNetObject "System.Windows.Forms.TabPage" "Summary"
            local canonicalPage = dotNetObject "System.Windows.Forms.TabPage" "Canonical Materials"
            local remapPage = dotNetObject "System.Windows.Forms.TabPage" "Target Remap"
            local conversionPage = dotNetObject "System.Windows.Forms.TabPage" "Conversions"
            local appendedPage = dotNetObject "System.Windows.Forms.TabPage" "Appended"
            local warningPage = dotNetObject "System.Windows.Forms.TabPage" "Conflicts / Warnings"
            local globalAZPage = dotNetObject "System.Windows.Forms.TabPage" "Global A-Z"
            local perObjectAZPage = dotNetObject "System.Windows.Forms.TabPage" "Per-Object A-Z"
            tabs.tabPages.add summaryPage
            tabs.tabPages.add canonicalPage
            tabs.tabPages.add remapPage
            tabs.tabPages.add conversionPage
            tabs.tabPages.add appendedPage
            tabs.tabPages.add warningPage
            tabs.tabPages.add globalAZPage
            tabs.tabPages.add perObjectAZPage

            local summaryList = dotNetObject "System.Windows.Forms.ListView"
            summaryList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView summaryList #(#("Field", 300), #("Snapshot Value", 650))
            addListViewRow summaryList #("READ ONLY SNAPSHOT", "No loaded value can modify the current scene.")
            addListViewRow summaryList #("Report Format Version", loadedReport[1])
            for pairValue in loadedReport[2] where pairValue[1] != "Report Format Version" do addListViewRow summaryList pairValue
            for pairValue in loadedReport[3] do addListViewRow summaryList #("Preprocess / " + pairValue[1], pairValue[2])
            addListViewRow summaryList #("Master", if loadedReport[4].count == 0 then "Not available" else loadedReport[4][1])
            addListViewRow summaryList #("Targets", if loadedReport[5].count == 0 then "Not available" else (loadedReport[5].count as string))
            for pairValue in loadedReport[6] do addListViewRow summaryList #("Summary / " + pairValue[1], pairValue[2])
            for pairValue in loadedReport[15][1] do addListViewRow summaryList #("Global A-Z / " + pairValue[1], pairValue[2])
            summaryPage.controls.add summaryList

            local canonicalList = dotNetObject "System.Windows.Forms.ListView"
            canonicalList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView canonicalList #(#("ID", 70), #("Material Name", 240), #("Raw Class", 170), #("Effective / Final Class", 190), #("Source / Status", 270))
            loadedViewerAddRows canonicalList loadedReport[7]
            canonicalPage.controls.add canonicalList

            local targetCombo = dotNetObject "System.Windows.Forms.ComboBox"
            targetCombo.location = dotNetObject "System.Drawing.Point" 10 10
            targetCombo.size = dotNetObject "System.Drawing.Size" 950 24
            targetCombo.dropDownStyle = (dotNetClass "System.Windows.Forms.ComboBoxStyle").DropDownList
            for groupValue in loadedReport[8] do targetCombo.items.add groupValue[1]
            remapPage.controls.add targetCombo
            local targetList = dotNetObject "System.Windows.Forms.ListView"
            targetList.location = dotNetObject "System.Drawing.Point" 10 42
            targetList.size = dotNetObject "System.Drawing.Size" 950 500
            configureListView targetList #(#("Old ID", 75), #("Material Name", 235), #("Raw Class", 155), #("Effective Class", 165), #("New ID", 75), #("Status", 225))
            remapPage.controls.add targetList
            loadedReportTargetList = #(targetCombo, targetList)
            dotNet.addEventHandler targetCombo "SelectedIndexChanged" onLoadedReportTargetChanged
            if loadedReport[8].count > 0 then targetCombo.selectedIndex = 0 else addLoadedViewerPlaceholder targetList "Not available in this report"

            local conversionList = dotNetObject "System.Windows.Forms.ListView"
            conversionList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView conversionList #(#("Source Material", 190), #("Source Class", 140), #("Converted Material", 190), #("Final Class", 120), #("Diffuse", 100), #("Glossiness", 100), #("Reflection", 120))
            loadedViewerAddRows conversionList loadedReport[9]
            conversionPage.controls.add conversionList

            local appendedList = dotNetObject "System.Windows.Forms.ListView"
            appendedList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView appendedList #(#("ID", 90), #("Material Name", 550), #("Status", 280))
            loadedViewerAddRows appendedList loadedReport[10]
            appendedPage.controls.add appendedList

            local warningList = dotNetObject "System.Windows.Forms.ListView"
            warningList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView warningList #(#("Type", 230), #("Item", 300), #("Detail", 400))
            for warningRow in loadedReport[11] do
                addListViewRow warningList (normalizeReportColumns warningRow 3 "VIEWER WARNING" #())
            for warningText in loadedReport[12] do addListViewRow warningList #("PARSER WARNING", warningText, "")
            if loadedReport[11].count == 0 and loadedReport[12].count == 0 do addLoadedViewerPlaceholder warningList "None"
            warningPage.controls.add warningList

            local globalAZList = dotNetObject "System.Windows.Forms.ListView"
            globalAZList.dock = (dotNetClass "System.Windows.Forms.DockStyle").Fill
            configureListView globalAZList #(#("New ID", 75), #("Material Name", 250), #("Old IDs", 160), #("Class", 150), #("Used By", 80), #("Status", 230))
            loadedViewerAddRows globalAZList loadedReport[15][3]
            globalAZPage.controls.add globalAZList

            local perObjectAZCombo = dotNetObject "System.Windows.Forms.ComboBox"
            perObjectAZCombo.location = dotNetObject "System.Drawing.Point" 10 10
            perObjectAZCombo.size = dotNetObject "System.Drawing.Size" 950 24
            perObjectAZCombo.dropDownStyle = (dotNetClass "System.Windows.Forms.ComboBoxStyle").DropDownList
            for groupValue in loadedReport[16] do perObjectAZCombo.items.add groupValue[1]
            perObjectAZPage.controls.add perObjectAZCombo
            local perObjectAZList = dotNetObject "System.Windows.Forms.ListView"
            perObjectAZList.location = dotNetObject "System.Drawing.Point" 10 42
            perObjectAZList.size = dotNetObject "System.Drawing.Size" 950 500
            configureListView perObjectAZList #(#("Old ID", 100), #("Material Name", 430), #("New ID", 100), #("Status", 290))
            perObjectAZPage.controls.add perObjectAZList
            loadedReportAZTargetList = #(perObjectAZCombo, perObjectAZList)
            dotNet.addEventHandler perObjectAZCombo "SelectedIndexChanged" onLoadedReportAZTargetChanged
            if loadedReport[16].count > 0 then perObjectAZCombo.selectedIndex = 0 else addLoadedViewerPlaceholder perObjectAZList "Not available in this report"

            local openButton = dotNetObject "System.Windows.Forms.Button"
            openButton.text = "Open Another Report..."
            openButton.location = dotNetObject "System.Drawing.Point" 12 674
            openButton.size = dotNetObject "System.Drawing.Size" 190 32
            form.controls.add openButton
            dotNet.addEventHandler openButton "Click" onLoadedReportViewerOpenAnother

            local closeButton = dotNetObject "System.Windows.Forms.Button"
            closeButton.text = "Close"
            closeButton.location = dotNetObject "System.Drawing.Point" 858 674
            closeButton.size = dotNetObject "System.Drawing.Size" 150 32
            form.controls.add closeButton
            dotNet.addEventHandler closeButton "Click" onLoadedReportViewerClose
            dotNet.addEventHandler form "FormClosed" onLoadedReportViewerClosed

            loadedReportForm = form
            form.Show()
            true
        )
    )

    fn loadReportFromPath reportPath showViewer:true showErrors:true =
    (
        local loadError = ""
        local parsedResult = undefined
        if reportPath == undefined or classOf reportPath != String or reportPath == "" then
            loadError = "No report path was provided."
        else if not doesFileExist reportPath then
            loadError = "The selected report file does not exist."
        else
        (
            try
            (
                local reportText = (dotNetClass "System.IO.File").ReadAllText reportPath
                parsedResult = parseReportText reportText
                if not parsedResult[1] do loadError = parsedResult[2]
            )
            catch
            (
                loadError = "The report could not be read as UTF-8 text: " + exceptionText()
            )
        )

        if loadError != "" then
        (
            setStatus ("ERROR: " + loadError)
            lmnLog "WARN" loadError
            if showErrors do messageBox loadError title:"Load Material Normalize Report"
            false
        )
        else
        (
            loadedReport = parsedResult[3]
            loadedReport[14] = reportPath
            setStatus ("Loaded read-only report: " + getFilenameFile reportPath + getFilenameType reportPath)
            if showViewer do showLoadedReportViewer()
            true
        )
    )

    fn loadReportWithDialog =
    (
        local reportPath = getOpenFileName caption:"Load Material Normalize Report" types:"Text Report (*.txt)|*.txt|"
        if reportPath == undefined then true else loadReportFromPath reportPath showViewer:true showErrors:true
    )

    fn getLoadedReportSnapshot =
    (
        loadedReport
    )

    fn exportReportToPath reportPath =
    (
        if reportPath == undefined or reportPath == "" then
            false
        else
        (
            try
            (
                local fileClass = dotNetClass "System.IO.File"
                local utf8Encoding = dotNetObject "System.Text.UTF8Encoding" false
                fileClass.WriteAllText reportPath (buildReportText()) utf8Encoding
                lastReportPath = reportPath
                lmnLog "INFO" ("Report exported: " + reportPath)
                true
            )
            catch
            (
                lmnLog "ERROR" ("Report export failed: " + exceptionText())
                false
            )
        )
    )

    fn exportReportWithDialog =
    (
        if lastOperation == #globalAZAnalyze or lastOperation == #globalAZReindex then
            refreshGlobalAZViewer()
        else
            analyzeAll updateUI:true
        local defaultReportPath = reportDefaultPath()
        if not isValidReportSeedPath defaultReportPath then
        (
            setStatus "ERROR: A valid default report path could not be created."
            false
        )
        else
        (
            local reportPath = getSaveFileName caption:"Export Material Normalize Report" filename:defaultReportPath types:"Text Report (*.txt)|*.txt|"
            if reportPath == undefined then
                false
            else if exportReportToPath reportPath then
            (
                setStatus ("Report exported: " + reportPath)
                true
            )
            else
            (
                setStatus "ERROR: Report export failed."
                false
            )
        )
    )

    fn autoExportReport =
    (
        if not chkAutoExport.checked then
            true
        else
        (
            local reportPath = reportDefaultPath()
            if exportReportToPath reportPath then
                true
            else
            (
                lmnLog "WARN" "The scene operation succeeded, but automatic report export failed."
                false
            )
        )
    )

    fn convertMaterialsOnly =
    (
        local selectedNodes = for nodeValue in selection where isValidStoredNode nodeValue collect nodeValue
        if selectedNodes.count == 0 then
        (
            setStatus "ERROR: Select one or more objects to convert."
            false
        )
        else
        (
            local preprocessOK = analyzePreprocess scopeNodes:selectedNodes
            local preprocessValidation = validatePreprocessOptions()
            local selectedMaterialCount = scopedMaterials.count
            local selectedExistingVRayCount = existingVRayCount
            local selectedUnsupportedCount = unsupportedMaterialCount
            local selectedUnsupportedRows = for materialValue in scopedMaterials where not isUSDPreviewMaterial materialValue and not isVRayMaterial materialValue collect
                #(safeMaterialName materialValue, materialClassText materialValue)
            local selectedSkippedCount = 0
            for nodeValue in selectedNodes where nodeValue.material == undefined do selectedSkippedCount += 1

            if not preprocessOK then
            (
                refreshAllUI()
                false
            )
            else if not preprocessValidation[1] then
            (
                setStatus preprocessValidation[2]
                false
            )
            else if conversionPlan.count == 0 and not chkSyncSlotNames.checked then
            (
                setStatus "No eligible USD material or enabled preprocessing action was found."
                false
            )
            else
            (
                local convertedCount = 0
                local syncedCount = 0
                local operationFailed = false
                conversionCache = #()
                lastTextureIgnoredNames = for materialValue in scopedMaterials where materialHasTextureDrivenDiffuse materialValue collect safeMaterialName materialValue
                lastConvertOnlyNodeNames = for nodeValue in selectedNodes collect nodeValue.name

                undo "Convert USD Materials Only" on
                (
                    try
                    (
                        convertedCount = applyUSDConversionsToNodes selectedNodes
                        lastConversionRows = captureConversionRowsFromCache()
                        syncedCount = syncMultiSlotNamesForNodes selectedNodes
                    )
                    catch
                    (
                        operationFailed = true
                        lmnLog "ERROR" ("Convert Materials Only failed: " + exceptionText())
                    )
                )

                if operationFailed then
                (
                    setStatus "ERROR: Convert Materials Only failed."
                    false
                )
                else
                (
                    lastApplyConvertedCount = convertedCount
                    lastApplyAppendedCount = 0
                    lastSyncedSlotCount = syncedCount
                    lastAppendedRows = #()
                    lastOperation = #convertOnly
                    lastConvertOnlyMaterialCount = selectedMaterialCount
                    lastConvertOnlyExistingVRayCount = selectedExistingVRayCount
                    lastConvertOnlyUnsupportedCount = selectedUnsupportedCount
                    lastConvertOnlySkippedCount = selectedSkippedCount
                    lastConvertOnlyUnsupportedRows = selectedUnsupportedRows
                    redrawViews()
                    analyzePreprocess scopeNodes:selectedNodes
                    lastConvertOnlyUSDCount = usdMaterialCount
                    if isValidStoredNode masterNode and targetNodes.count > 0 then
                        analyzeAll updateUI:true
                    else
                        refreshAllUI()
                    local resultMessage = "Convert Materials Only complete: " + (convertedCount as string) +
                        " converted, " + (selectedExistingVRayCount as string) + " existing VRay kept, " +
                        (selectedUnsupportedCount as string) + " unsupported kept, " + (selectedSkippedCount as string) +
                        " object(s) skipped, " + (syncedCount as string) + " slot name(s) updated. No IDs or assignments changed."
                    setStatus resultMessage
                    lmnLog "INFO" resultMessage
                    autoExportReport()
                    true
                )
            )
        )
    )

    fn applyNormalization =
    (
        if not analyzeAll updateUI:true then
        (
            lmnLog "WARN" "Normalize / Apply was blocked by validation."
            false
        )
        else
        (
            local preprocessValidation = validatePreprocessOptions()
            if not preprocessValidation[1] then
            (
                setStatus preprocessValidation[2]
                lmnLog "ERROR" preprocessValidation[2]
                false
            )
            else
            (
                local masterMaterial = masterNode.material
                local appendedCount = 0
                local normalizedCount = 0
                local convertedCount = 0
                local failedCount = 0
                local syncedCount = 0
                local applicableAnalyses = for analysis in targetAnalyses where analysis[5] collect analysis
                lastConversionRows = #()
                lastAppendedRows = #()
                lastTextureIgnoredNames = for materialValue in scopedMaterials where materialHasTextureDrivenDiffuse materialValue collect safeMaterialName materialValue

                undo "Convert USD and Normalize Material IDs" on
                (
                    try
                    (
                        convertedCount = applyUSDConversions()
                        lastConversionRows = captureConversionRowsFromCache()

                        if convertedCount > 0 do
                        (
                            if not analyzeAll updateUI:false do
                                throw "Post-conversion validation failed before Material ID normalization."
                            masterMaterial = masterNode.material
                            applicableAnalyses = for analysis in targetAnalyses where analysis[5] collect analysis
                        )

                        lastAppendedRows = for rowValue in canonicalRows where rowValue[5] == #pending collect rowValue
                        appendedCount = appendPendingMaterials masterMaterial
                        syncedCount += syncRegisteredMultiSlotNames()

                        for analysis in applicableAnalyses do
                        (
                            local nodeValue = analysis[1]
                            try
                            (
                                remapTargetFaces nodeValue analysis[4]
                                nodeValue.material = masterMaterial
                                if verifyTarget nodeValue analysis[4] masterMaterial then
                                    normalizedCount += 1
                                else
                                (
                                    failedCount += 1
                                    lmnLog "ERROR" (nodeValue.name + ": post-apply verification failed.")
                                )
                            )
                            catch
                            (
                                failedCount += 1
                                lmnLog "ERROR" (nodeValue.name + ": " + exceptionText())
                            )
                        )
                        syncedCount += syncMultiSlotNames masterMaterial
                    )
                    catch
                    (
                        failedCount += applicableAnalyses.count
                        lmnLog "ERROR" ("Apply failed: " + exceptionText())
                    )
                )

                lastApplyConvertedCount = convertedCount
                lastApplyAppendedCount = appendedCount
                lastSyncedSlotCount = syncedCount
                redrawViews()
                analyzeAll updateUI:true

                local glossinessText = if chkConvertUSD.checked and chkOverrideGlossiness.checked then
                    formattedPrint spnGlossiness.value format:".2f"
                else "OFF"
                local reflectionText = if chkConvertUSD.checked and chkOverrideReflection.checked then
                    ((cpReflection.color.r as integer) as string) + "," +
                    ((cpReflection.color.g as integer) as string) + "," +
                    ((cpReflection.color.b as integer) as string)
                else "OFF"
                local resultMessage = "Normalized " + (normalizedCount as string) +
                    " object(s). Converted " + (convertedCount as string) +
                    " USD. Appended " + (appendedCount as string) +
                    ". Glossiness: " + glossinessText + " / Reflection: " + reflectionText
                if failedCount > 0 do resultMessage += " / " + (failedCount as string) + " failed"
                setStatus resultMessage
                lmnLog "INFO" resultMessage
                local operationSucceeded = failedCount == 0 and normalizedCount > 0
                if operationSucceeded do
                (
                    lastOperation = #normalize
                    autoExportReport()
                )
                operationSucceeded
            )
        )
    )

    on LunarMaterialIDNormalizerRollout open do
    (
        configureListView lvCanonical #(#("ID", 44), #("Material Name", 142), #("Type", 104), #("Source / Status", 142))
        configureListView lvRemap #(#("Old ID", 62), #("Material", 265), #("New ID", 62), #("Status", 310))
        updatePreprocessControlStates()
        refreshAllUI()
    )

    on LunarMaterialIDNormalizerRollout close do
    (
        if loadedReportForm != undefined do try (loadedReportForm.Close()) catch()
        if globalAZForm != undefined do try (globalAZForm.Close()) catch()
    )

    on chkConvertUSD changed state do
    (
        updatePreprocessControlStates()
        invalidateAnalysis "USD conversion option changed. Run Analyze again."
    )

    on chkOverrideGlossiness changed state do
    (
        updatePreprocessControlStates()
        invalidateAnalysis "Glossiness override option changed. Run Analyze again."
    )

    on spnGlossiness changed value do
        invalidateAnalysis "Glossiness override value changed. Run Analyze again."

    on chkOverrideReflection changed state do
    (
        updatePreprocessControlStates()
        invalidateAnalysis "Reflection override option changed. Run Analyze again."
    )

    on cpReflection changed colorValue do
        invalidateAnalysis "Reflection override color changed. Run Analyze again."

    on chkSyncSlotNames changed state do
        invalidateAnalysis "Slot-name synchronization option changed. Run Analyze again."

    on btnSetMaster pressed do captureMasterFromSelection()

    on btnClearMaster pressed do
        clearMasterNode()

    on btnAddTargets pressed do addSelectedTargets()
    on btnRemoveTargets pressed do removeSelectedTargets()

    on btnClearTargets pressed do
    (
        clearTargetNodes()
    )

    on lbTargets selected indexValue do refreshPreview targetIndex:indexValue
    on btnAnalyze pressed do
    (
        analyzeAll updateUI:true recordOperation:true
    )
    on btnConvertOnly pressed do convertMaterialsOnly()
    on btnApply pressed do applyNormalization()
    on btnOpenGlobalAZ pressed do showGlobalAZViewer()
    on btnLoadReport pressed do loadReportWithDialog()
    on btnExportReport pressed do exportReportWithDialog()
)

createDialog LunarMaterialIDNormalizerRollout style:#(#style_titlebar, #style_sysmenu, #style_minimizebox)
