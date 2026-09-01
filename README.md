# LUNARMAXSCRIPT

[한국어](README.md) · [Català](README.ca.md)

Autodesk 3ds Max 제작 작업을 보조하는 개인용 MAXScript 도구 모음입니다. 각 도구는 저장소 최상위의 독립 디렉터리에 있으며, 구현 파일·테스트·도구별 한국어/Català 문서를 함께 관리합니다.

## 도구

### Lunar Geometry Preprocessor MK1

선택한 Geometry를 엄격한 Mesh 데이터로 분류하고, 확인된 Group을 결정적으로 Rename하거나 안전한 범위에서 Base Object Instance 관계로 정규화합니다.

- 문서: [한국어](LunarGeometryPreprocessor/README.md) · [Català](LunarGeometryPreprocessor/README.ca.md)
- [MAXScript 소스](LunarGeometryPreprocessor/src/LunarGeometryPreprocessor_MK1.ms)
- [Smoke Test](LunarGeometryPreprocessor/tests/LunarGeometryPreprocessor_smoke.ms)

### Lunar Material ID Normalizer MK2

Editable Poly face Material ID와 Multi/Sub-Object material 배열을 Master 기준으로 정규화하고, USD Preview Surface 전처리 및 독립적인 Global A-Z Reindex Workflow를 제공합니다.

- 문서: [한국어](LunarMaterialIDNormalizer/README.md) · [Català](LunarMaterialIDNormalizer/README.ca.md)
- [MAXScript 소스](LunarMaterialIDNormalizer/src/LunarMaterialIDNormalizer.ms)
- [Smoke Test](LunarMaterialIDNormalizer/tests/LunarMaterialIDNormalizer_smoke.ms)

### Lunar Transform Assistant

명시적으로 지정한 Source와 Targets 사이에서 지원되는 Transform Channel, Full Transform, Base Object를 Copy 또는 Instance하고, Transform Lock과 Node Visibility를 관리합니다.

- 문서: [한국어](LunarTransformAssistant/README.md) · [Català](LunarTransformAssistant/README.ca.md)
- [MAXScript 소스](LunarTransformAssistant/src/LunarTransformAssistant.ms)
- [MacroScript Launcher](LunarTransformAssistant/macros/LunarTransformAssistant.mcr)

### Lunar → tyFlow Placement MK1

수동 배치된 Source Object를 이름 기반 Family로 묶고, 지정한 tyFlow 안의 Family별 `LUNAR_` Event를 안전하게 생성하거나 갱신합니다.

- 문서: [한국어](LunarTyFlowPlacement/README.md) · [Català](LunarTyFlowPlacement/README.ca.md)
- [MAXScript 소스](LunarTyFlowPlacement/src/LunarTyFlowPlacement_MK1.ms)
- [Smoke Test](LunarTyFlowPlacement/tests/LunarTyFlowPlacement_smoke.ms)

### Lunar VRayMtl Batch Override

활성 Slate Material Editor View에서 직접 선택한 고유 `VRayMtl` Reference에만 사용자가 활성화한 Parameter Override를 일괄 적용합니다.

- 문서: [한국어](LunarVRayMtlBatchOverride/README.md) · [Català](LunarVRayMtlBatchOverride/README.ca.md)
- [MAXScript 소스](LunarVRayMtlBatchOverride/src/Lunar_VRayMtl_Batch_Override.ms)
- 테스트: [Core Smoke](LunarVRayMtlBatchOverride/tests/Lunar_VRayMtl_Batch_Override_smoke.ms) · [SME Regression](LunarVRayMtlBatchOverride/tests/Lunar_VRayMtl_Batch_Override_sme_regression.ms) · [Property Probe](LunarVRayMtlBatchOverride/tests/VRayMtl_property_probe.ms)

## 저장소 구조

공용 파일은 저장소 Root에 두고, 각 도구의 구현·테스트·문서는 해당 도구 디렉터리 안에 둡니다.

```text
LUNARMAXSCRIPT/
├── README.md
├── README.ca.md
├── LICENSE
├── AGENTS.md
├── LunarGeometryPreprocessor/
├── LunarMaterialIDNormalizer/
├── LunarTransformAssistant/
├── LunarTyFlowPlacement/
└── LunarVRayMtlBatchOverride/
```

## 지원 환경

도구는 Autodesk 3ds Max 2026용 MAXScript로 작성되었습니다. V-Ray 또는 tyFlow를 사용하는 도구는 각 README에 기록된 Plugin Version과 검증 범위를 확인하세요.

## 라이선스

이 저장소는 GNU General Public License v3.0으로 배포됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참조하세요.
