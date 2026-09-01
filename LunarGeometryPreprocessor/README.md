# Lunar Geometry Preprocessor MK1

[한국어](README.md) · [Català](README.ca.md)

`LunarGeometryPreprocessor_MK1.ms`는 외부 DCC에서 가져온 수동 배치 Geometry를 엄격한 Mesh 데이터로 분류하고, 사용자가 각 Group의 의미를 확인해 Family Name을 입력한 뒤 안전하게 Rename하거나 선택적으로 Instance 관계를 정규화하는 3ds Max 2026용 독립 MAXScript 툴입니다.

## 실행

3ds Max에서 다음 파일을 **Scripting > Run Script**로 실행합니다.

```text
src\LunarGeometryPreprocessor_MK1.ms
```

## 권장 Workflow

1. 분류할 Scene Geometry를 선택합니다. Camera, Light, Helper, Point, tyFlow, Particle System 등은 자동으로 제외됩니다.
2. `ANALYZE SELECTED GEOMETRY`를 누릅니다. Analyze는 Scene을 변경하지 않고 Node Handle Snapshot만 유지합니다.
3. 표에서 Row를 선택한 뒤 `SELECT GROUP` 또는 `FRAME GROUP`으로 Viewport에서 모델을 확인합니다.
4. `Group Name (edit)` Cell에 각 Family Name을 직접 입력합니다. 빈 이름, 중복 이름, 잘못된 문자열, 외부 Scene Node와의 최종 이름 충돌은 Apply를 차단합니다.
5. 이름만 바꾸려면 `RENAME GROUPS`, Instance 관계만 정규화하려면 `MAKE INSTANCES`, 둘 다 하려면 `APPLY ALL`을 사용합니다.

Rename 형식은 Group별 `<GroupName>_001`부터 시작하며, 원래 trailing number가 작은 Node부터 번호를 부여합니다.

## Geometry 판정

- Fast Bucket: vertex count, face count
- Strict Hash: quantized local vertex positions + ordered face indices의 SHA-256
- Final Verify: 모든 local vertex position을 `0.0001` scene-unit tolerance로 비교하고 모든 face vertex index를 정확히 비교

SHA-256은 Candidate Bucket 내부의 빠른 우선 탐색에 사용됩니다. Quantization 경계에 걸친 단정밀도 역변환 오차 때문에 Hash가 달라진 경우에도 같은 Verts/Faces Bucket 안에서 최종 strict 비교가 판정을 확정하므로, Hash collision이나 Hash 불일치만으로 Geometry를 잘못 합치거나 분리하지 않습니다.

Node의 world position, rotation, scale은 Geometry Signature에 포함하지 않습니다. Vertex/Face count가 같아도 실제 위치 데이터 또는 topology가 다르면 별도 Group으로 유지됩니다. Vertex index가 완전히 재구성된 Mesh나 fuzzy/rotation-invariant matching은 MK1 범위가 아닙니다.

Modifier가 없는 동일 `baseObject` Instance는 Signature를 Cache하여 한 번만 분석합니다. Modifier가 있는 Node는 evaluated Mesh로 분류할 수 있지만 Instance Normalize에서는 보수적으로 `STACK UNSAFE / INSTANCE SKIPPED` 처리합니다.

## 안전 원칙

- Analyze: Scene 변경 없음
- Rename: 이름만 변경, 충돌 방지용 two-pass temporary name 사용
- Instance Normalize: Lunar Transform Assistant에서 검증된 `target.baseObject = source.baseObject` 방식 사용
- Instance 전후 transform, position, rotation, scale, pivot/object offset, parent, layer, material, hidden/frozen/visibility, wire color, world bounds 검증
- 검증 실패 시 원래 Base Object로 즉시 rollback하고 해당 Node를 `INSTANCE UNSAFE`로 보고
- Center Pivot, Reset XForm, Collapse, Attach, Editable Poly 강제 변환, Transform Bake, Material 통합, Layer/Visibility 변경, tyFlow 작업은 수행하지 않음

각 Scene 변경 버튼은 Undo 단위를 만들며, `APPLY ALL`은 `Undo "Lunar Geometry Preprocessor"` 한 번으로 되돌릴 수 있습니다.

## 테스트

`tests\LunarGeometryPreprocessor_smoke.ms`는 다음을 포함합니다.

- 동일 Geometry의 position/rotation/scale 독립 분류
- 같은 vertex/face count지만 다른 Geometry 분리
- Analyze source-state 불변성
- Group 선택
- 중복 Suggested Name 및 외부 이름 충돌 차단
- deterministic three-digit Rename과 Rename Only 불변성
- Copy-to-Instance 변환 및 Node별 transform/pivot/material 보존
- 기존 8 Instance + 2 Copy에서 2개만 변환
- Modifier Stack의 보수적 Instance Skip

## 라이선스

이 도구는 GNU General Public License v3.0으로 배포됩니다. 자세한 내용은 [../LICENSE](../LICENSE)를 참조하세요.
