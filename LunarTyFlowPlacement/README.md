# Lunar → tyFlow Placement MK1

[한국어](README.md) · [Català](README.ca.md)

`LunarTyFlowPlacement_MK1.ms`는 C4D에서 수동 배치한 3ds Max Source Object들을 이름 기준 Family로 묶고, 등록된 하나의 tyFlow 안에 Family별 `LUNAR_` Event를 생성하거나 갱신합니다.

## 실행

1. 3ds Max에서 `src/LunarTyFlowPlacement_MK1.ms`를 `Run Script...`로 실행합니다.
2. Target tyFlow 하나를 선택하고 `Use Selected tyFlow`를 누릅니다.
3. 배치 Source Object들을 선택합니다. Target tyFlow가 Selection에 함께 있어도 자동 제외됩니다.
4. `ANALYZE`로 Family, Count, Shape Source, Status를 확인합니다.
5. `BUILD / UPDATE`를 실행합니다.

## Family 규칙

- 마지막 `_<digits>`만 제거합니다: `Cup_015 → Cup`, `Small_Pot_002 → Small_Pot`.
- `Kettle001`, `Point001`, `B52`처럼 규칙과 일치하지 않는 이름은 숫자를 추측해 제거하지 않습니다.
- Nonstandard Node는 전체 이름을 독립 Family 이름으로 사용하고 `NONSTANDARD NAME` Warning을 표시합니다.
- 각 Family의 Analyze 입력 순서상 첫 valid Node가 Shape Source입니다.

## 옵션

- `Ignore Instance Relationship` 기본값은 ON입니다. ON에서는 이름만으로 묶고 Geometry/Instance 관계를 검사하지 않습니다.
- OFF에서는 모든 Family Node가 Shape Source와 같은 `baseObject` reference를 공유하는지 검사합니다. 다르면 해당 Family만 `INSTANCE / GEOMETRY MISMATCH`로 Skip합니다.
- `Update Existing LUNAR Events` 기본값은 ON입니다. 같은 이름의 `LUNAR_<Family>` Event가 있으면 해당 Event 안의 Birth Objects와 Shape만 갱신합니다. OFF이면 `ALREADY EXISTS`로 Skip합니다.

## 생성 구조와 안전 경계

각 Family Event에는 다음 순서로 Operator가 설정됩니다.

- Birth Objects
  - `objectList`: Analyze 당시 저장한 handle로 다시 확인된 Source Nodes
  - `objectsInheritGeometry = false`
  - `objectsCenterPivots = false`
  - `inheritPosition / inheritRotation / inheritScale = true`
- Shape
  - `shape_type_tab = #(2)` — Reference Object mode
  - `instancedGeo_tab = #(Shape Source)`
  - `meshCenterPivots_tab = #(false)`
  - `scale_tab = #(false)`
- Mesh
  - `meshType = 0` — `TriMesh`
  - `renderOnly = true` — `[Render]`
- Display
  - `displayMode = 4` — `Geometry`

최종 Event 구조는 `Birth Objects → Shape → Mesh (TriMesh [Render]) → Display (Geometry)`입니다.

Source Node의 transform, pivot offset, geometry, visibility, hidden/frozen state, layer, parent는 변경하지 않습니다. 기존 non-`LUNAR_` Event/Operator는 찾거나 수정하거나 삭제하지 않습니다. Build/Update는 하나의 Undo 단위이며, 새 Event 구성 실패 시 그 Event를 제거하고 기존 LUNAR Event 갱신 실패 시 변경 전 Operator 값을 복구합니다.

## 검증 환경

- Autodesk 3ds Max 2026.3.3 Security Fix
- 설치 파일 `tyFlow_2026.dlo` version `2.0100.0.0`
- `tests/LunarTyFlowPlacement_smoke.ms`: 39 Passed / 0 Failed

테스트는 이름 분류, 단일/다중 Family, Instance ignore/validation, 기존 Event 보호, Update/Skip, 삭제된 Shape Source, Source 불변성뿐 아니라 실제 particle Position/Rotation/Scale과 Shape mesh 결과까지 확인합니다.

## 라이선스

이 도구는 GNU General Public License v3.0으로 배포됩니다. 자세한 내용은 [../LICENSE](../LICENSE)를 참조하세요.
