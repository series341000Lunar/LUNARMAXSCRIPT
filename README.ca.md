# LUNARMAXSCRIPT

[한국어](README.md) · [Català](README.ca.md)

Col·lecció personal d'eines MAXScript per assistir tasques de producció a Autodesk 3ds Max. Cada eina viu en un directori independent de primer nivell i manté conjuntament la implementació, les proves i la documentació específica en coreà i català.

## Eines

### Lunar Geometry Preprocessor MK1

Classifica la Geometry seleccionada mitjançant dades Mesh estrictes, permet reanomenar els Groups confirmats de manera determinista i, quan és segur, normalitza la relació entre còpies com a instàncies del mateix Base Object.

- Documentació: [한국어](LunarGeometryPreprocessor/README.md) · [Català](LunarGeometryPreprocessor/README.ca.md)
- [Codi MAXScript](LunarGeometryPreprocessor/src/LunarGeometryPreprocessor_MK1.ms)
- [Smoke Test](LunarGeometryPreprocessor/tests/LunarGeometryPreprocessor_smoke.ms)

### Lunar Material ID Normalizer MK2

Normalitza els Material ID de les cares d'Editable Poly i les taules de materials Multi/Sub-Object segons un Master, amb preprocessament d'USD Preview Surface i un workflow Global A-Z Reindex independent.

- Documentació: [한국어](LunarMaterialIDNormalizer/README.md) · [Català](LunarMaterialIDNormalizer/README.ca.md)
- [Codi MAXScript](LunarMaterialIDNormalizer/src/LunarMaterialIDNormalizer.ms)
- [Smoke Test](LunarMaterialIDNormalizer/tests/LunarMaterialIDNormalizer_smoke.ms)

### Lunar Transform Assistant

Copia o instancia Transform Channels, Full Transform i Base Objects compatibles entre un Source i diversos Targets definits explícitament, i també gestiona Transform Locks i la visibilitat de node.

- Documentació: [한국어](LunarTransformAssistant/README.md) · [Català](LunarTransformAssistant/README.ca.md)
- [Codi MAXScript](LunarTransformAssistant/src/LunarTransformAssistant.ms)
- [MacroScript Launcher](LunarTransformAssistant/macros/LunarTransformAssistant.mcr)

### Lunar → tyFlow Placement MK1

Agrupa Source Objects col·locats manualment en Families segons el nom i crea o actualitza de manera segura un Event `LUNAR_` per Family dins del tyFlow indicat.

- Documentació: [한국어](LunarTyFlowPlacement/README.md) · [Català](LunarTyFlowPlacement/README.ca.md)
- [Codi MAXScript](LunarTyFlowPlacement/src/LunarTyFlowPlacement_MK1.ms)
- [Smoke Test](LunarTyFlowPlacement/tests/LunarTyFlowPlacement_smoke.ms)

### Lunar VRayMtl Batch Override

Aplica en lot només els Parameter Overrides activats per l'usuari a les referències `VRayMtl` úniques seleccionades directament a la vista activa de Slate Material Editor.

- Documentació: [한국어](LunarVRayMtlBatchOverride/README.md) · [Català](LunarVRayMtlBatchOverride/README.ca.md)
- [Codi MAXScript](LunarVRayMtlBatchOverride/src/Lunar_VRayMtl_Batch_Override.ms)
- Proves: [Core Smoke](LunarVRayMtlBatchOverride/tests/Lunar_VRayMtl_Batch_Override_smoke.ms) · [SME Regression](LunarVRayMtlBatchOverride/tests/Lunar_VRayMtl_Batch_Override_sme_regression.ms) · [Property Probe](LunarVRayMtlBatchOverride/tests/VRayMtl_property_probe.ms)

## Estructura del repositori

Els fitxers compartits romanen a l'arrel. La implementació, les proves i la documentació de cada eina es mantenen dins del directori propi de l'eina.

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

## Entorn compatible

Les eines estan escrites en MAXScript per a Autodesk 3ds Max 2026. Per a les eines que fan servir V-Ray o tyFlow, consulteu al README corresponent la versió del plugin i l'abast de la validació.

## Llicència

Aquest repositori es distribueix sota la GNU General Public License v3.0. Consulteu [LICENSE](LICENSE) per obtenir-ne els detalls.
