# Lunar Transform Assistant

[한국어](README.md) · [Català](README.ca.md)

Autodesk 3ds Max 2026용 MAXScript 제작 보조 도구입니다. 명시적으로 지정한 Source와 Targets 사이에서 지원되는 Transform Channel, Full Transform, Base Object를 Copy 또는 Instance하고, 현재 Selection의 Transform Lock과 Node-level Hidden 상태를 관리합니다.

예측 가능한 동작과 기존 Scene Data 보존을 우선합니다. 지원하지 않는 Controller 구조는 자동 변환하지 않고 건너뛰며 Listener에 이유를 기록합니다.

## 파일

```text
src/LunarTransformAssistant.ms
macros/LunarTransformAssistant.mcr
README.md
README.ca.md
```

## 설치와 실행

권장 설치 구조는 다음과 같습니다.

```text
<3ds Max user scripts>\LunarTransformAssistant\src\LunarTransformAssistant.ms
<3ds Max user scripts>\LunarTransformAssistant\macros\LunarTransformAssistant.mcr
```

1. 위 구조로 `src`와 `macros`를 복사합니다.
2. 3ds Max에서 **Scripting > Run Script**를 열고 `macros\LunarTransformAssistant.mcr`을 실행합니다.
3. **Customize > Customize User Interface**에서 Category `Lunar Tools`의 `Lunar Transform Assistant` Action을 Toolbar, Menu, Quad Menu 또는 Keyboard Shortcut에 추가합니다.

MacroScript Metadata는 다음과 같습니다.

```text
Category: Lunar Tools
Internal name: LunarTransformAssistant
Tooltip: Lunar Transform Assistant
```

Launcher는 자신의 위치를 기준으로 `..\src\LunarTransformAssistant.ms`를 먼저 찾고, 이후 권장 User Scripts 경로를 확인합니다. 이미 Rollout이 열려 있으면 중복 Dialog를 만들거나 저장된 Source/Targets를 초기화하지 않고 기존 창에 Focus합니다. Action 등록 없이 한 번만 실행하려면 `src/LunarTransformAssistant.ms`를 직접 실행할 수 있습니다.

## Source / Target Workflow

### Manual

1. Scene Node 하나를 선택하고 `Set Source`를 누릅니다.
2. Target Nodes를 하나 이상 선택하고 `Set Targets`를 누릅니다.
3. 원하는 Copy 또는 Instance 작업을 실행합니다.

Target Capture에 Source가 포함되어 있으면 자동 제외합니다. 작업 직전에 저장된 Node를 다시 검증하고, 삭제되거나 유효하지 않은 Target은 안전하게 제거하며 삭제된 Source는 해제합니다. `Clear Targets`는 Manual Target List만 비웁니다.

Transform Lock과 `Unhide Selected Nodes`는 저장된 Source/Targets가 아니라 버튼을 누르는 순간의 현재 3ds Max Selection을 사용합니다.

### First Selected = Source / Last Selected = Source

1. `Start / Reset Ordered Selection`을 누릅니다.
2. 단일 선택과 다중 선택을 원하는 순서로 조합합니다.
3. First Mode에서는 Flattened Batch Order의 첫 Node가 Source, 나머지가 Targets가 됩니다.
4. Last Mode에서는 마지막 Node가 Source, 앞의 Nodes가 Targets가 됩니다.

Manual State와 Ordered Selection Batch History는 서로 독립적으로 저장됩니다. Mode 전환은 어느 State도 지우지 않으며, First/Last Mode는 같은 Batch History를 즉시 재해석합니다.

## Ordered Selection 규칙

- Node 하나를 추가한 Action은 정확한 Action 순서를 보존하는 Single Selection Batch입니다.
- 여러 Nodes를 한 번에 추가한 Action은 Multiple Selection Batch입니다. Rectangle Selection과 Select By Name Multi-selection을 지원합니다.
- Batch는 생성 순서대로 Flatten합니다.
- Multiple Selection Batch 내부에는 의미 있는 Viewport Click Order가 없으므로 Node Handle 오름차순과 Name Fallback을 이용한 결정적 순서를 사용합니다.
- Single과 Multiple Batch를 섞을 수 있습니다. 예: single A → multiple B-Z → single Final.
- Multiple Batch가 하나라도 있으면 UI는 개별 Node Name과 내부 순서를 표시하지 않고 `Multiple Selection` 또는 `Mixed / Multiple Selection` Summary와 Object Count만 표시합니다.
- Deselect한 Node는 기존 Order에서 제거됩니다. Multiple Batch가 한 Node만 남아도 Batch Type은 Multiple로 유지됩니다.
- 다시 선택한 한 Node는 새 마지막 Single Batch, 여러 Nodes는 새 마지막 Multiple Batch가 됩니다.
- 같은 Node는 둘 이상의 Batch에 들어갈 수 없으며, 작업에는 최소 두 개의 유효 Node가 필요합니다.
- 새로운 Ordered Session 전에는 `Start / Reset Ordered Selection`을 사용합니다.

Callback은 이전 Selection Snapshot과 현재 유효 Selection의 차이를 비교합니다. `NodeEventCallback`이 전달한 AnimHandle Array 순서와 3ds Max `selection` Collection 순서는 사용자 Click Order로 간주하지 않습니다. 삭제된 Node는 Callback, UI Refresh, Operation Validation 시점에 정리됩니다.

## Copy와 Instance

Copy는 현재 평가값 또는 독립적인 Base Object Copy를 기록합니다.

- Selected Transform Channel Copy: 현재 Frame의 값만 복사
- Full Transform Copy: Source World Transform Matrix 할당
- Base Object Copy: Source Base Object의 독립 Copy 할당

Instance는 Controller 또는 Base Object Reference를 공유합니다.

- Selected-channel Instance: 체크한 Component Controller만 공유
- Full Transform Instance: 전체 Transform Controller 공유
- Base Object Instance: Source Base Object 공유

Instance 관계는 양방향이므로 어느 한쪽의 수정이 같은 Reference를 공유하는 모든 Node에 영향을 줄 수 있습니다. 호환성을 만들기 위한 Controller 자동 변환은 수행하지 않습니다.

## Transform Channel 동작

Transform Matrix는 Position, Rotation, Scale의 X/Y/Z를 제어합니다. Transform Copy Checkbox와 Transform Lock Checkbox는 서로 독립적입니다.

### Current-value Copy

독립 Component Track이 있는 경우 Source Component Controller의 현재 값을 읽어 Target의 동일 Component에 `currentTime`으로 기록합니다.

- Position: `Position_XYZ`
- Rotation: `Euler_XYZ`
- Scale: `ScaleXYZ`

Source와 Target의 `Euler_XYZ` Axis Order가 다르면 같은 X/Y/Z Angle의 좌표 해석이 달라지므로 건너뜁니다.

기본 `Bezier_Scale`은 독립 X/Y/Z Subcontroller가 없습니다. `Copy Selected Channels`에 한해 Source와 Target이 모두 `Bezier_Scale`이면 체크한 Component는 Source, 체크하지 않은 Component는 Target의 평가값으로 합성한 Current Scale Value를 씁니다. Controller 교체나 Key 복사는 하지 않지만, Animated Frame에서는 3ds Max의 일반 Animate State에 따라 Composite Scale Key가 갱신 또는 생성될 수 있습니다.

### Selected-channel Instance

Source와 Target 모두 호환되고 쓰기 가능한 독립 Component Controller를 제공할 때만 지원합니다.

- `Position_XYZ`
- Axis Order가 같은 `Euler_XYZ`
- `ScaleXYZ`

실제 Category Controller와 Component SubAnim을 확인해 체크한 Target Component에만 Source Component Controller를 할당합니다. 체크하지 않은 Component는 유지됩니다. `Bezier_Scale`의 개별 Axis Instance는 지원하지 않습니다.

### 지원하지 않는 Controller 예

- Quaternion / TCB Rotation
- Rotation List, Position List, Scale List
- LookAt / Path Constraint
- Script Controller
- CAT / Biped Controller
- Plugin-specific Controller
- 누락되었거나 쓰기 불가능한 Component SubAnim
- 서로 다른 Euler Axis Order

지원하지 않는 경우 `[LTA][WARN]` 또는 `[LTA][ERROR]`로 기록하고 해당 작업을 건너뜁니다. Controller Type 변경, Key 삭제, Constraint 또는 Wire Parameter 생성은 수행하지 않습니다.

## Full Transform

`Copy Full Transform`은 Source World Transform을 각 Target에 할당하고 Target Parent는 바꾸지 않습니다. 적용 후 Target World Matrix를 Source와 비교해 거부되거나 부분 적용된 결과를 성공으로 집계하지 않습니다.

`Instance Full Transform`은 Source의 전체 Transform Controller를 Target에 할당합니다. Source와 Target의 Parent가 다르면 같은 Local Controller가 다른 World Transform을 만들 수 있음을 경고하지만 Parenting을 바꾸지는 않습니다.

Transform Lock, Constraint, Special Rig 또는 비지원 Controller가 할당을 막으면 실패하거나 Verification Rejected로 보고될 수 있습니다.

## Base Object

일반 Geometry Base Object, Primitive 및 흔한 Editable Poly-compatible Geometry를 지원합니다.

```maxscript
-- Copy Base Object
target.baseObject = copy source.baseObject

-- Instance Base Object
target.baseObject = source.baseObject
```

오직 `baseObject`만 할당합니다. Whole Node Clone, Source Modifier Stack Copy, Stack Collapse, Parent 변경, Target Rename, Material Copy를 하지 않습니다. 3ds Max가 조합을 허용하면 기존 Target Modifier는 교체된 Base Object 위에 유지됩니다.

Non-Geometry Base Object, XRef Base Object, Group Head, 3ds Max가 거부하는 Object/Modifier Stack 조합은 지원하지 않습니다.

## Transform Lock

Lock 작업은 현재 Selection과 별도의 Lock Checkbox Matrix를 사용합니다. 3ds Max Transform Lock Bit 순서는 다음과 같습니다.

```text
1 Position X
2 Position Y
3 Position Z
4 Rotation X
5 Rotation Y
6 Rotation Z
7 Scale X
8 Scale Y
9 Scale Z
```

`Lock Checked`와 `Unlock Checked`는 기존 BitArray를 읽고 체크한 Bit만 변경한 뒤 나머지가 유지되었는지 검증합니다. `Lock All`과 `Unlock All`은 9개 Bit 전체를 설정하고 검증합니다. Controller Type과 Animation Key는 변경하지 않습니다.

## Visibility

`Unhide Selected Nodes`는 현재 Selection에 대해 다음 값만 변경합니다.

```maxscript
node.isNodeHidden = false
```

Node의 Layer를 Unhide하지 않습니다. Layer가 계속 숨겨져 있으면 Listener에 Warning을 표시하며 같은 Layer의 다른 Object는 변경하지 않습니다.

## Undo, 진단, 지원 범위

- Scene을 바꾸는 각 Button은 하나의 Named Undo Block에서 Batch를 실행합니다.
- 여러 Targets를 한 Batch로 처리하되 한 Target의 실패가 나머지 처리를 중단하지 않습니다.
- 변경이 검증된 경우에만 Batch 후 `redrawViews()`를 최대 한 번 호출합니다.
- UI Status는 간단한 결과를, Listener는 `[LTA][INFO]`, `[LTA][WARN]`, `[LTA][ERROR]` Prefix로 Node별 이유와 Batch Summary를 표시합니다.
- 주요 지원 범위는 일반 Geometry Node, Standard PRS, Position XYZ, Euler XYZ, Scale XYZ, 일반 Bezier Scale 현재값 Copy, Primitive/Editable Poly-compatible Base Object, Multiple Targets입니다.
- Special Rig, XRef, Group Head, Non-Geometry Base Object, Plugin-specific Controller는 범위 밖입니다.

## 알려진 제한

- 선택 Channel은 Controller-space Component이며 서로 다른 Controller Type이나 Euler Axis Order 사이에서 재해석하지 않습니다.
- Current-value Assignment는 현재 Frame과 3ds Max Animate Mode를 따르므로 Animated Controller에서 Key가 갱신 또는 생성될 수 있습니다.
- Full Transform Instance는 Local Controller Output을 공유하므로 Parent가 다르면 World Transform도 달라질 수 있습니다.
- Base Object 교체 가능 여부는 최종적으로 3ds Max가 판단합니다.
- Node-level Unhide만으로 Layer, Category 또는 Frozen-display 원인의 비가시성을 해제할 수 없습니다.
- Controller/Base Object Assignment의 실제 Undo 동작과 특수 Production Rig 호환성은 대상 3ds Max Build에서 추가 확인하는 것이 좋습니다.

+## 수동 Runtime Test Checklist

### Source / Target

- [ ] 유효한 Source 하나를 설정합니다.
- [ ] Target 하나와 여러 Targets를 각각 설정합니다.
- [ ] 저장된 Target을 삭제한 뒤 작업을 실행합니다.
- [ ] Target Capture에 Source를 실수로 포함해 자동 제외되는지 확인합니다.
- [ ] First Selected Mode로 전환해도 Manual Source/Targets가 유지되는지 확인합니다.
- [ ] Manual Mode로 돌아와 원래 Manual State가 활성화되는지 확인합니다.

### Ordered Selection

- [ ] First Selected를 선택하고 Reset한 뒤 A, `Ctrl+B`, `Ctrl+C` 순서로 선택합니다.
- [ ] Active Source가 A이고 Active Targets가 B/C인지 확인합니다.
- [ ] Mode만 Last Selected로 바꾸어 Active Source가 C, Targets가 A/B로 재해석되는지 확인합니다.
- [ ] B를 Deselect했을 때 Order가 A/C, 다시 선택했을 때 A/C/B가 되는지 확인합니다.
- [ ] Reset 후 A만 선택하면 Source/Target 작업이 차단되는지 확인합니다.
- [ ] 최소 20개 Node를 Rectangle-select해 유효한 Multiple Selection Summary와 안정적인 Source가 나오는지 확인합니다.
- [ ] 겉보기 Selection Order가 달라도 같은 Multi-selection에서 같은 Source가 결정되는지 확인합니다.
- [ ] Single→Multiple, Multiple→Single, Single→Multiple→Single 조합을 First/Last Mode에서 확인합니다.
- [ ] Multiple Batch의 일부 Node를 Deselect했을 때 해당 Nodes만 제거되는지 확인합니다.
- [ ] Node 하나를 Deselect 후 Reselect했을 때 새 마지막 Single Batch가 되는지 확인합니다.
- [ ] Multiple Batch가 있으면 개별 Name과 내부 Order가 숨겨지는지 확인합니다.
- [ ] 저장된 Ordered Node를 삭제해도 예외 없이 제거되는지 확인합니다.
- [ ] Rollout을 닫고 다시 열었을 때 Selection Event가 한 번만 기록되는지 확인합니다.

### Transform Copy / Instance

- [ ] Position X만, Position X/Z, Rotation Y, Non-uniform Scale X만 각각 Copy합니다.
- [ ] 체크하지 않은 Channel이 유지되는지 확인합니다.
- [ ] Non-zero Animation Frame에서 Copy를 확인합니다.
- [ ] Position XYZ Controller에서 Position X만 Instance하고 Controller Reference가 공유되는지 확인합니다.
- [ ] Target 수정이 Source에도 반영되는 양방향 Instance를 확인합니다.
- [ ] 비지원 Controller 작업이 Target을 변경하지 않는지 확인합니다.

### Full Transform / Base Object

- [ ] Parent가 없는 경우, 같은 Parent, 다른 Parent에서 Full Transform Copy를 확인합니다.
- [ ] 같은 Parent에서 Full Transform Instance를 확인하고 다른 Parent Warning을 확인합니다.
- [ ] Sphere Source에서 Box Target으로 Base Object Copy/Instance를 실행합니다.
- [ ] Target Transform, Material, Modifier Stack이 유지되는지 확인합니다.
- [ ] Copy는 독립 Geometry, Instance는 공유 Base Object가 되는지 확인합니다.
- [ ] Multiple Targets를 함께 확인합니다.

### Visibility / Lock / Undo

- [ ] 숨겨진 Node를 Unhide하고, 숨겨진 Layer에서는 Warning이 표시되는지 확인합니다.
- [ ] 같은 Layer의 다른 Objects가 변경되지 않는지 확인합니다.
- [ ] Position X Lock, Rotation Y 추가 Lock, Position X Unlock을 순서대로 실행해 나머지 Flag 보존을 확인합니다.
- [ ] Lock All / Unlock All과 Multiple Selection을 확인합니다.
- [ ] 각 Button 실행이 지원 범위에서 하나의 Undo로 복원되는지 확인합니다.

## 정적 검토 범위

구현에서 다음 항목을 검토했습니다.

- Manual Capture State와 Callback 기반 Ordered State의 분리
- `selection[]` Collection Order를 Click Order로 사용하지 않는 구조
- Single/Multiple Batch를 Flatten한 공통 First/Last Source Resolver
- Callback Handle Order를 신뢰하지 않는 Previous/Current Selection Snapshot Diff
- Multiple Batch 내부의 결정적 Node Handle Order
- Duplicate 방지, Deselect 제거, Empty Batch 정리, Reselect Append
- Rollout-local State와 의도된 Global Rollout Reference 하나
- Manual/Ordered State의 `isValidNode` 기반 Stale Node 정리
- `NodeEventCallback` 등록, 해제, 중복 등록 방지
- Scene-changing Button Path당 하나의 Undo Context
- Target별 예외 격리와 Diagnostic Summary
- 체크하지 않은 Channel과 Lock State 보존
- Controller Conversion, Stack Collapse, `instanceReplace`, Constraint, Wire Parameter 부재
- Base Object-only Assignment와 Target Modifier Stack 보존
- 변경된 Batch당 최대 한 번의 Redraw
- 중복 MacroScript 등록과 Dialog Reopen 동작

## 검증 상태

Autodesk 3ds Max 2026.3.3 Batch에서 Main Rollout, MacroScript Launch/Reopen, Position X Copy/Instance, 부분 `Bezier_Scale` Copy, Transform Lock, Base Object Copy/Instance, Target Modifier 보존, Full Transform Copy/Instance, 세 Selection Mode, Mixed Single/Multiple Batch, Deselect/Reselect, 삭제 Node 정리, Callback Release/Reopen을 자동 검증했습니다.

Batch Harness는 실제 `NodeEventCallback` Handler에 AnimHandle Array를 전달했습니다. 실제 Viewport `Ctrl+Click`, Rectangle Selection, Select By Name Gesture와 UI 표시, One-step Undo, Non-zero-frame Animation, Layer-hidden Warning, 특수 Rig 및 다양한 Production Modifier Stack은 일반 3ds Max UI에서 수동 확인 대상입니다.

Batch Log의 `nToolFloat`와 `vexus_startup.ms` 오류는 기존 Third-party Startup Script에서 발생한 별도 Noise이며 Lunar Transform Assistant Script 오류로 판정되지 않았습니다.

## 라이선스

이 도구는 GNU General Public License v3.0으로 배포됩니다. 자세한 내용은 [../LICENSE](../LICENSE)를 참조하세요.
