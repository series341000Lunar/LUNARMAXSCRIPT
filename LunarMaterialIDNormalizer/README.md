# Lunar Material ID Normalizer

Cinema 4D 등에서 가져온 오브젝트를 각각 Attach한 뒤 서로 달라진 Multi/Sub-Object Material ID 순서와 Editable Poly face Material ID를 하나의 Master 기준으로 정규화하는 3ds Max MAXScript Utility입니다.

## 실행

1. 3ds Max에서 `Scripting > Run Script...`를 엽니다.
2. [`src/LunarMaterialIDNormalizer.ms`](src/LunarMaterialIDNormalizer.ms)를 실행합니다.

스크립트 한 파일만으로 UI가 열리고 동작합니다.

## 사용 순서

1. 기준 Attach 결과 오브젝트 하나를 선택하고 `Set Master`를 누릅니다.
2. 나머지 Attach 결과 오브젝트들을 선택하고 `Add Selected Targets`를 누릅니다.
3. `Analyze`를 눌러 Canonical Material Table과 Target Remap Preview를 확인합니다.
4. 새 재질은 `PENDING APPEND : <Object>`로 표시됩니다.
5. Master의 중복 이름/ID 충돌이 없고 preview가 올바르면 `Normalize / Apply`를 누릅니다.

Apply 전체는 `Normalize Material IDs`라는 하나의 Undo 단위로 감쌉니다.

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
- 기존 material 이름과 속성
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

`tests/LunarMaterialIDNormalizer_smoke.ms`를 Autodesk 3ds Max 2026.3.3 Batch에서 실행해 37개 검사가 통과했습니다. 검증 범위에는 요구된 A-F 시나리오, Analyze 무변경, case-sensitive matching, 단일 material Target, 실제 material reference append, modifier stack/transform/pivot/topology 보존, 한 번의 Undo 복원이 포함됩니다.

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
