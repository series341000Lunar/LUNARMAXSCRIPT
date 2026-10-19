# Renew Parent Animation

[한국어](README.md) · [Català](README.ca.md)

Blender 4.x에서 선택한 Child들의 **evaluated World Transform**을 전체 Scene frame range에서 먼저 캡처한 뒤, Active Object를 Parent로 설정하고 Parent-relative `location` / `rotation_quaternion` / `scale` Action으로 굽습니다. Child의 Mesh와 Material 데이터는 수정하지 않습니다.

## 설치 및 사용

1. Blender의 `Edit > Preferences > Add-ons > Install from Disk`에서 [renew_parent_animation.py](renew_parent_animation.py)를 설치·활성화합니다. Blender 4.4/4.5에서는 단일 파일 Add-on으로 실행됩니다.
2. Child를 먼저 선택하고 Parent를 마지막에 선택하여 Active Object로 만듭니다. 여러 Child를 선택할 수 있습니다.
3. 3D View의 `N > Animation Tools > Renew Parent Animation`을 실행합니다.

기본 Bake 범위는 `scene.frame_start`부터 `scene.frame_end`까지 1프레임 간격입니다. 완료 후 System Console에 Child별/전체 최대 위치 오차(Blender unit)와 회전 오차(deg)가 표시됩니다. 허용치는 위치 `0.0001`, 회전 `0.01°`이며 초과하면 Warning입니다. 원래 프레임, 선택, Active Object를 복원하고 Operator Undo를 지원합니다.

## 처리 범위와 제한

- Source 캡처에는 Dependency Graph의 최종 evaluated `matrix_world`를 사용합니다. 캡처가 모두 끝나기 전에는 Parent, Constraint, Action을 변경하지 않습니다.
- 기존 Child Constraint와 NLA Track은 mute하고, Transform Driver는 mute합니다. 이전 Action은 데이터 블록으로 남기되 Child의 활성 Action에서 분리합니다. 새 Action에는 매 프레임 `LINEAR` 키가 생성됩니다. Child의 비 Transform Object Action 채널이나 NLA도 활성 상태에서 제외될 수 있습니다.
- Scale도 함께 굽습니다. Parent-relative 행렬에 Object TRS로 표현할 수 없는 Shear가 있으면 변경 전에 오류로 중단합니다. Blender 단정밀도 및 프레임 사이 보간 때문에 검증은 샘플된 정수 프레임 기준입니다.
- Parent의 기존 Animation/Cache는 변경하지 않습니다. 따라서 Parent 자체가 외부 Cache에 의존한다면 전체 Hierarchy 재생 시 해당 Source는 계속 필요합니다. 실제 USD/ABC Transform Cache 파일은 이번 테스트에 포함되지 않았습니다.
- 새 Child Action은 네이티브 Object Transform 키이며 Child의 기존 Transform Cache Constraint 없이 평가됩니다. 원본 Child Source는 mute 상태로 보존되므로 재사용하려면 상태를 수동으로 정리하거나 Undo하십시오.

## 검증

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' -b --factory-startup --python 'RenewParentAnimation\tests\test_renew_parent_animation.py'
```

[테스트 스크립트](tests/test_renew_parent_animation.py)는 A Translation, B Translation+Rotation, C Multiple Children, D Constraint-driven Child, E Driver/NLA Source를 Blender 4.4.3/4.5.3에서 실행합니다. 추가로 중간 실패 Rollback, Parent cycle, Singular Matrix 거부를 검증합니다. 모든 테스트는 캡처한 evaluated Child World motion과 결과를 1~11프레임에서 비교합니다.
