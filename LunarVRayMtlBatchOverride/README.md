# Lunar VRayMtl Batch Override

활성 Slate Material Editor 뷰에서 사용자가 직접 선택한 `VRayMtl` 인스턴스만 대상으로, 체크한 파라미터만 일괄 변경하는 독립 MAXScript 유틸리티입니다.

실행 파일: `src/Lunar_VRayMtl_Batch_Override.ms`

## 사용법

1. Slate Material Editor를 열고 현재 뷰에서 변경할 `VRayMtl` 노드를 선택합니다.
2. 스크립트를 실행합니다.
3. 변경할 항목만 체크하고 값과 Map Handling을 정합니다.
4. `Apply to Selected VRayMtl`을 누릅니다. Apply 시점에 현재 SME 선택을 다시 읽습니다.

Scene Object 선택, Material Assignment, Material ID, Face Material ID, Multi/Sub 하위 재질은 조회하거나 변경하지 않습니다. 동일한 재질 참조가 여러 번 들어오면 재질 참조 기준으로 한 번만 처리합니다.

## 구현 범위

- Base / Diffuse Color
- Reflection Color
- Reflection Surface: Glossiness 또는 Roughness
- Metalness
- Refraction Color
- Refraction Glossiness
- Map Handling: Keep, Disable, Remove
- 한 번의 Undo로 전체 Apply 복원
- Apply 중복 실행 잠금과 Material/Parameter 단위 오류 격리
- 첫 번째 선택 `VRayMtl`의 읽기 전용 Property 진단 출력

모든 Override 체크박스는 기본 OFF이고 Map Handling 기본값은 Keep입니다. 체크하지 않은 파라미터의 값과 맵에는 접근해 쓰지 않습니다.

## SME 선택 API

`sme.activeView`, `sme.GetView()`, `view.GetSelectedNodes()`를 사용합니다. 각 Node Interface의 실제 `reference`를 읽고 `superClassOf`와 `classOf`로 정확히 `VRayMtl`인지 판정합니다. 이름 비교로 재질 종류를 추측하지 않습니다.

## 현재 환경에서 확인한 VRayMtl Property

3ds Max 2026.3.3에 설치된 `VRayMtl`을 `getPropNames`로 진단하고, `isProperty` 및 실제 읽기/쓰기 테스트로 확인한 이름입니다.

| 의미 | 값 Property | Map Property | Map Enable Property |
|---|---|---|---|
| Base / Diffuse Color | `Diffuse` | `texmap_diffuse` | `texmap_diffuse_on` |
| Reflection Color | `Reflection` | `texmap_reflection` | `texmap_reflection_on` |
| Reflection Surface | `reflection_glossiness` | `texmap_reflectionGlossiness` | `texmap_reflectionGlossiness_on` |
| Metalness | `reflection_metalness` | `texmap_metalness` | `texmap_metalness_on` |
| Refraction Color | `Refraction` | `texmap_refraction` | `texmap_refraction_on` |
| Refraction Glossiness | `refraction_glossiness` | `texmap_refractionGlossiness` | `texmap_refractionGlossiness_on` |

Reflection Surface 모드 스위치는 `brdf_useRoughness`입니다.

## Glossiness / Roughness 처리

Reflection Surface는 `brdf_useRoughness`를 먼저 원하는 모드로 설정한 뒤 `reflection_glossiness`에 사용자가 입력한 값을 그대로 기록합니다. 따라서 Roughness `0.40`을 임의 반전하지 않고 Roughness 모드의 `0.40`으로 저장합니다.

Refraction Glossiness는 `refraction_glossiness`에 사용자가 입력한 값을 그대로 저장합니다. `1.0 - value` 반전을 하지 않으며 기존 `brdf_useRoughness` 모드도 바꾸지 않습니다.

## 버전 호환성과 안전 동작

호환성 계층은 String 또는 Name candidate를 Name으로 정규화한 뒤, 실제 Material Reference에 대한 `isProperty material propertyName` 결과를 최종 지원 기준으로 사용합니다. `getPropNames`는 Listener 진단 기능에서만 사용하며 resolver 판정에는 사용하지 않습니다. 접두사나 유사 이름을 임의 검색하지 않습니다.

- 값 Property를 확인할 수 없으면 해당 항목만 `Unsupported`로 기록하고 계속합니다.
- Map Property 또는 Enable Property를 확실히 확인할 수 없으면 맵은 유지합니다.
- Disable은 Map Reference를 보존하고 해당 Enable Property만 끕니다.
- Remove는 체크한 파라미터의 Map Reference만 `undefined`로 설정합니다.
- 다른 V-Ray 버전의 별칭은 실제 검증 전에는 지원한다고 간주하지 않습니다.
- Reflection Surface는 `reflection_glossiness`와 `brdf_useRoughness`가 모두 확인되어야 지원됩니다.

## 검증 결과

`tests/Lunar_VRayMtl_Batch_Override_smoke.ms`와 `tests/Lunar_VRayMtl_Batch_Override_sme_regression.ms`를 3ds Max 2026.3.3의 quiet/silent MAXScript 실행으로 수행했습니다.

- 전체 회귀 결과: `Passed: 37`, `Failed: 0`
- 12개 실제 VRayMtl SME 파라미터별 결과: `Passed: 9`, `Failed: 0`
- Base Color: `Success 12 | Unsupported 0 | Errors 0`
- Reflection Color: `Success 12 | Unsupported 0 | Errors 0`
- Surface: `Success 12 | Unsupported 0 | Errors 0`
- Metalness: `Success 12 | Unsupported 0 | Errors 0`
- Refraction Color: `Success 12 | Unsupported 0 | Errors 0`
- Refract Gloss: `Success 12 | Unsupported 0 | Errors 0`
- Direct `isProperty`: 7개 값/모드 Property 모두 지원 확인
- Direct Diffuse set/get: 값 변경 및 원복 확인
- 실제 V-Ray 값/모드/맵 Keep·Disable·Remove 검증
- 체크하지 않은 값과 맵 보존 검증
- 모든 Override OFF 무변경 검증
- Physical Material, Standard Material, Map 보호 검증
- 50개 `VRayMtl` 일괄 변경 후 Undo 한 번으로 값과 제거된 맵 복원 검증
- 실제 임시 SME 뷰에서 선택 Node 수, `VRayMtl` 필터링, Skipped 집계 검증
- 동일 재질 참조 3개 입력을 Unique `VRayMtl` 1개로 축약하는 검증
- UI 기본 OFF, Keep 기본값, 비활성 Control 연동 검증

`tests/VRayMtl_property_probe.ms`는 설치된 `VRayMtl`의 Property를 다시 조사할 때 사용하는 진단 스크립트입니다. 다른 V-Ray 빌드에서는 이 진단 결과를 확인한 뒤 호환성 표를 갱신해야 합니다.
