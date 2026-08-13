# Lunar Material ID Normalizer

Cinema 4D 또는 USD에서 가져온 오브젝트의 `USD Preview Surface`를 단순한 `VRayMtl`로 전처리하고, 서로 달라진 Multi/Sub-Object Material ID 순서와 Editable Poly face Material ID를 하나의 Master 기준으로 정규화하는 3ds Max MAXScript Utility입니다.

## 실행

1. 3ds Max에서 `Scripting > Run Script...`를 엽니다.
2. [`src/LunarMaterialIDNormalizer.ms`](src/LunarMaterialIDNormalizer.ms)를 실행합니다.

스크립트 한 파일만으로 UI가 열리고 동작합니다.

## 사용 순서

1. `PREPROCESS`에서 USD 변환과 새 VRayMtl에 적용할 Override를 설정합니다.
2. 기준 Attach 결과 오브젝트 하나를 선택하고 `Set Master`를 누릅니다.
3. 나머지 Attach 결과 오브젝트들을 선택하고 `Add Selected Targets`를 누릅니다.
4. `Analyze`를 눌러 변환 예정 상태, Canonical Material Table과 Target Remap Preview를 확인합니다.
5. 새 재질은 `PENDING APPEND : <Object>`로 표시됩니다.
6. 이름/색상 및 Master 이름/ID 충돌이 없고 preview가 올바르면 `Normalize / Apply`를 누릅니다.

USD 변환, append, face ID remap, Master material 할당을 포함한 Apply 전체는 `Convert USD and Normalize Material IDs`라는 하나의 Undo 단위로 감쌉니다.

## USD → VRayMtl 전처리

- `Convert USD Preview Surface to VRayMtl`은 기본 ON이며, OFF이면 기존 Material ID 정규화만 수행합니다.
- Multi/Sub container와 Material ID는 그대로 두고 `MaxUsdPreviewSurface` sub-material reference만 교체합니다.
- 새 VRayMtl에는 원본 이름과 constant `diffuseColor`만 복사합니다.
- texture network는 만들지 않고 fallback color만 사용하며 Table에 `TEXTURE IGNORED`로 표시합니다.
- metallic, roughness, opacity, emission, normal, displacement 등은 변환하지 않습니다.
- 동일한 원본 USD material reference는 conversion cache를 통해 하나의 VRayMtl reference로 재사용합니다.
- 기존 VRayMtl과 지원하지 않는 재질은 변경하지 않습니다.
- `Override Glossiness`는 0.0~1.0의 V-Ray glossiness 값이며, `Override Reflection`은 RGB color입니다. 둘 다 이번 Apply에서 새로 생성되는 VRayMtl에만 적용됩니다.
- Override가 OFF이면 USD roughness/metallic에서 값을 계산하지 않고 VRayMtl의 기본값을 유지합니다.
- 동일한 정확한 이름에 서로 다른 diffuse color가 발견되면 `SAME NAME / DIFFERENT DIFFUSE` conflict로 Apply를 차단합니다.
- V-Ray가 없거나 확인된 VRayMtl property를 사용할 수 없으면 scene을 변경하지 않고 오류를 표시합니다.
- Analyze는 VRayMtl 생성이나 material reference 교체 없이 계획만 계산합니다.

현재 설치 환경에서 확인해 사용하는 property는 USD의 `diffuseColor`, `diffuseColor_map`과 VRayMtl의 `Diffuse`, `Reflection`, `reflection_glossiness`, `brdf_useRoughness`입니다. Apply 직전에는 해당 class와 property를 다시 검증합니다.

## 처리 원칙

- Master는 Multi/Sub-Object Material이어야 합니다.
- 이름 비교는 대소문자를 구분하는 정확한 문자열 비교입니다.
- `.001`, `_001`, 숫자 suffix 제거, fuzzy/부분 일치 같은 자동 보정은 하지 않습니다.
- Multi/Sub 배열 slot과 Material ID가 같다고 가정하지 않습니다.
- 각 행은 `materialList[slot]`과 `materialIDList[slot]`을 함께 읽습니다.
- Master의 기존 ID는 재정렬하거나 변경하지 않습니다.
- 새 ID는 현재 Master와 analyze 중 예약된 ID의 최댓값 다음 번호를 사용합니다.
- 새 재질은 Target이 실제 사용한 sub-material reference 자체를 Master 끝 slot에 추가합니다.
- Target이 같은 이름을 여러 ID에서 사용하면 모두 하나의 Master ID로 합쳐집니다.
- Master에서 동일 이름이 서로 다른 ID에 있거나 동일 ID가 여러 slot에 있으면 Apply를 차단합니다.
- 재질이 없는 Target과 Editable Poly가 아닌 Target은 건너뛰고 UI에 상태를 표시합니다.
- 지원되는 Target의 face ID를 먼저 숫자 lookup으로 묶은 뒤 `polyop.setFaceMatID`를 ID별 face BitArray에 적용합니다.
- face remap 뒤 Target에는 Master와 동일한 Multi/Sub material reference를 할당합니다.

## 변경하지 않는 항목

이 도구는 다음 항목을 의도적으로 변경하지 않습니다.

- Vertex, Edge, Face topology
- Object transform, pivot, object name
- UV, smoothing group, normal
- Modifier stack
- 기존 VRayMtl 및 변환 대상이 아닌 material의 이름과 속성
- Master의 기존 Material ID

## 지원 범위와 제한

- face 편집 대상은 base object가 `Editable_Poly`인 노드입니다. 자동 변환이나 stack collapse는 하지 않습니다.
- Master는 Multi/Sub-Object Material만 지원합니다.
- Target은 Multi/Sub-Object Material과 단일 Material을 지원합니다.
- Target Multi/Sub에 같은 Material ID가 여러 slot으로 중복되어 있으면 어떤 재질을 의미하는지 모호하므로 해당 Target을 오류 처리합니다.
- Target face가 Multi/Sub에 정의되지 않은 ID를 사용하면 해당 Target을 오류 처리합니다.
- Analyze 이후 장면이 바뀌었을 수 있으므로 Apply 직전에 자동으로 다시 Analyze합니다.
- UI 동작, one-step Undo, renderer/plugin 전용 material reference는 실제 제작 환경에서도 확인하는 것이 좋습니다.

## 자동 검증

`tests/LunarMaterialIDNormalizer_smoke.ms`를 Autodesk 3ds Max 2026.3.3 Batch에서 실행해 69개 검사가 통과했습니다. 기존 정규화 회귀 범위에 더해 USD 기본 변환, 두 Override의 적용 범위와 OFF 기본값 보존, shared reference cache, Multi/Sub container/ID 보존, diffuse conflict 차단, Convert OFF, texture 무시, USD 변환까지 포함한 한 번의 Undo 복원을 검증합니다.

일반 3ds Max UI에서의 실제 클릭 흐름과 제작용 renderer/plugin material은 별도의 수동 확인 대상입니다.

## 간단 테스트 절차

- 순서만 다른 A/B/C Multi/Sub Target을 Analyze/Apply하고 각 face가 Master ID를 사용하는지 확인합니다.
- Target에만 D가 있을 때 Master의 `max(materialIDList) + 1`로 한 번만 추가되는지 확인합니다.
- 여러 Target에 D가 반복되어도 같은 ID와 같은 Master sub-material을 공유하는지 확인합니다.
- Master ID가 1, 4, 8이면 새 D가 9가 되는지 확인합니다.
- Master에 이름 A가 두 ID로 존재하면 `DUPLICATE NAME`이 표시되고 Apply가 차단되는지 확인합니다.
- 재질 없는 Target은 건너뛰고 나머지가 정상 처리되는지 확인합니다.

## License

This tool is licensed under the GNU General Public License v3.0. See [../LICENSE](../LICENSE).
