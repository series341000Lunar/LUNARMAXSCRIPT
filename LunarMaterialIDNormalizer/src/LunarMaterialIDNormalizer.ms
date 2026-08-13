/*
    Lunar Material ID Normalizer
    Autodesk 3ds Max 2026 / MAXScript

    Purpose:
    - Normalize Editable Poly face Material IDs to one Master Multi/Sub-Object material.
    - Match sub-materials by exact, case-sensitive material name.
    - Preserve existing Master IDs and append missing material references after max ID.
    - Analyze without scene changes; Apply in one undo block.
*/

global LunarMaterialIDNormalizerRollout

if LunarMaterialIDNormalizerRollout != undefined do
(
    try (destroyDialog LunarMaterialIDNormalizerRollout) catch()
)

rollout LunarMaterialIDNormalizerRollout "Lunar Material ID Normalizer" width:760 height:1018
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

    label lblSummary "MASTER: None | Targets: 0 | Materials: 0 | Matched: 0 | Pending Append: 0" pos:[10,938] width:740 height:18
    label lblConversionSummary "USD: 0 | Existing VRay: 0 | Unsupported: 0 | Texture Ignored: 0 | Conflicts: 0" pos:[10,960] width:740 height:18
    label lblStatus "Status: Ready" pos:[10,982] width:740 height:28

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

    fn analyzePreprocess =
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
        collectScopedMaterials()

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
            default: "NONE"
        )
    )

    fn operationFilenamePart operationValue =
    (
        case operationValue of
        (
            #convertOnly: "ConvertOnly"
            #normalize: "Normalize"
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
        pathConfig.appendPath reportDirectory reportName
    )

    fn buildReportText =
    (
        local reportText = ""
        local newLine = "\r\n"
        local masterName = if isValidStoredNode masterNode then masterNode.name else "None"
        local predictedConversionCount = if lastOperation == #analyze then conversionPlan.count else lastApplyConvertedCount
        local appendedDisplayCount = if lastOperation == #normalize then lastApplyAppendedCount else pendingCount

        reportText += "Lunar Material ID Normalizer Report" + newLine
        reportText += "Tool Version: 1.2" + newLine
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

        reportText += "[SUMMARY]" + newLine
        reportText += "Material Count: " + (canonicalRows.count as string) + newLine
        reportText += "USD Material Count: " + (usdMaterialCount as string) + newLine
        reportText += "Existing VRayMtl Count: " + (existingVRayCount as string) + newLine
        reportText += "Unsupported Count: " + (unsupportedMaterialCount as string) + newLine
        reportText += "Converted Count: " + (predictedConversionCount as string) + newLine
        reportText += "Matched Count: " + (matchedCount as string) + newLine
        reportText += "Pending/Appended Count: " + (appendedDisplayCount as string) + newLine
        reportText += "Class Conflict Count: " + (classConflictCount as string) + newLine
        reportText += "Color Conflict Count: " + (preprocessConflictCount as string) + newLine
        reportText += "Skipped Count: " + (lastSkippedCount as string) + newLine
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
        for materialValue in scopedMaterials where not isUSDPreviewMaterial materialValue and not isVRayMaterial materialValue do
            reportText += "UNSUPPORTED / KEEP\t" + safeMaterialName materialValue + "\t" + materialClassText materialValue + newLine
        for materialValue in scopedMaterials where materialHasTextureDrivenDiffuse materialValue do
            reportText += "TEXTURE IGNORED\t" + safeMaterialName materialValue + newLine
        if lastOperation != #analyze do
        (
            for materialName in lastTextureIgnoredNames do
                reportText += "TEXTURE IGNORED DURING CONVERSION\t" + materialName + newLine
        )
        for analysis in targetAnalyses where not analysis[5] do
            reportText += analysis[2] + "\t" + (if isValidStoredNode analysis[1] then analysis[1].name else "<Invalid Node>") + "\t" + analysis[3] + newLine
        if classConflictNames.count == 0 and diffuseConflictNames.count == 0 and unsupportedMaterialCount == 0 and textureIgnoredCount == 0 and
            (lastOperation == #analyze or lastTextureIgnoredNames.count == 0) and lastSkippedCount == 0 do
            reportText += "None" + newLine

        reportText
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
        analyzeAll updateUI:true
        local reportPath = getSaveFileName caption:"Export Material Normalize Report" filename:reportDefaultPath() types:"Text Report (*.txt)|*.txt|"
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
        cleanStoredNodes()
        if not isValidStoredNode masterNode then
        (
            setStatus "Set a valid Master object before conversion."
            false
        )
        else if targetNodes.count == 0 then
        (
            setStatus "Add at least one Target before conversion."
            false
        )
        else
        (
            local preprocessOK = analyzePreprocess()
            local preprocessValidation = validatePreprocessOptions()
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

                undo "Convert USD Materials Only" on
                (
                    try
                    (
                        convertedCount = applyUSDConversions()
                        lastConversionRows = captureConversionRowsFromCache()
                        syncedCount = syncRegisteredMultiSlotNames()
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
                    redrawViews()
                    analyzeAll updateUI:true
                    local resultMessage = "Convert Materials Only complete: " + (convertedCount as string) +
                        " converted, " + (syncedCount as string) + " slot name(s) updated. No IDs or assignments changed."
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
    (
        masterNode = undefined
        invalidateAnalysis "MASTER cleared."
    )

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
    on btnExportReport pressed do exportReportWithDialog()
)

createDialog LunarMaterialIDNormalizerRollout style:#(#style_titlebar, #style_sysmenu, #style_minimizebox)
