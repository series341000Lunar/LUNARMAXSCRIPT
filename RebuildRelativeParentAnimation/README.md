# Rebuild Relative Parent Animation

독립적인 World Transform 애니메이션을 실제 Parent hierarchy와 편집 가능한 Child 로컬 PRS 키로 변환하는 3ds Max MAXScript 도구입니다. 외부 라이브러리를 사용하지 않습니다.

## 실행

3ds Max에서 **Scripting > Run Script**로 [`src/LG_RebuildRelativeParentAnimation.ms`](src/LG_RebuildRelativeParentAnimation.ms)를 실행합니다. 창을 연 뒤 Child를 먼저 선택하고 Parent를 **마지막에 하나씩 추가 선택**한 다음 **Rebuild Relative Parent Animation**을 누릅니다. 도구는 현재 `selection` 배열의 순서를 Parent 판정에 사용하지 않고, 창이 열린 동안 새로 추가된 단일 Node를 기록합니다. 창을 열기 전에 이미 모든 오브젝트를 선택했거나 여러 Node가 한 번에 추가되어 순서가 모호하면 **Pick Parent (fallback)**로 Parent를 지정합니다. Parent를 직접 지정한 경우 현재 선택된 나머지 Node가 Children입니다.

처리 범위는 `animationRange.start`부터 `animationRange.end`까지 1프레임 간격입니다. **Bake Scale**은 기본 OFF입니다. 성공 시 현재 시간과 선택은 그대로 유지되며, 전체 변경은 한 번의 Undo로 되돌릴 수 있습니다. 실패하면 변경을 취소하고 Listener와 UI에 오류를 표시합니다.

## 처리와 검증

1. hierarchy/controller를 바꾸기 전에 Parent와 모든 Child의 `node.transform` World Matrix3를 전 프레임 캡처합니다.
2. `ChildLocalTM = ChildWorldTM * inverse(ParentWorldTM)`로 로컬 변환을 계산합니다.
3. Child에 Parent를 지정하고 Child의 기존 Transform Controller를 PRS / Position XYZ / Euler XYZ / Scale로 교체합니다. Position/Euler 축은 Linear Float 키로 기록합니다. Parent Controller는 수정하지 않습니다.
4. 모든 샘플 프레임에서 Parent 및 Child의 World 위치/회전을 원본과 비교합니다. 허용 오차는 위치 `0.0001` scene unit, 회전 `0.01°`입니다. Bake Scale ON에서는 World Matrix basis도 비교합니다. 초과 시 Undo transaction을 취소합니다.

geometry, pivot/object offset, modifier, material은 수정하지 않습니다. 임시 Dummy나 Constraint도 만들지 않습니다.

## 제한사항

- 1프레임 샘플 사이의 원본 움직임을 재구성하지는 않습니다. Linear 키로 overshoot를 억제하지만, sub-frame 궤적이 원본과 완전히 같다는 보장은 없습니다.
- World Matrix 샘플만으로는 프레임 사이에 숨어 있는 여러 바퀴 회전 수를 복원할 수 없습니다. Euler XYZ의 동등한 표현 중 앞 프레임에 가장 가까운 값을 선택합니다.
- Parent Matrix가 singular이거나 계산된 로컬 Matrix에 shear, zero scale, mirror가 있으면 오류로 중단합니다. Bake Scale OFF에서 Scale 차이는 보존 대상이 아니며 Translation/Rotation 검증이 우선입니다.
- AlembicXform 파일을 사용한 실물 검증은 아직 하지 않았습니다. Source Controller에 직접 접근하지 않고 최종 World Matrix를 읽는 방식이며, Position/Orientation Constraint Source는 3ds Max Batch에서 검증했습니다.

## 검증

`tests/RRPA_smoke.ms`를 3ds Max 2027 Batch에서 실행했습니다. A Translation, B Parent Rotation/Orbit, C 3 Children, D Position/Orientation Constraint, E 4-level hierarchy와 추가 Scale ON/Euler 180° 경계/기존 Parent 교체/singular Parent 거부 시나리오가 **26 PASS / 0 FAIL**입니다. 테스트 보고서는 `tests/RRPA-smoke-result.txt`에 기록됩니다. 실제 사용자 장면의 UI/viewport 확인은 별도 단계입니다.
