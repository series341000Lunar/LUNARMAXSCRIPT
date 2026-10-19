# Universal Selected Key Editor

새 범주 필터와 Value 셀 직접 입력은 **MK2**에서 제공합니다. 실행 파일은 `Universal_Selected_Key_Editor_MK2.ms`이며, 사용법과 검증 범위는 [MK2_README.md](MK2_README.md)를 참고하십시오. 아래 내용은 기존 0.6 파일의 설명입니다.

3ds Max 2027용 기존 키 편집기입니다. 실행 파일명은 기존 호출 경로를 유지하기 위해 `Universal_Selected_Key_Editor_v0_1.ms`이며, 내부 버전은 0.6입니다.

## 사용

1. Max에서 대상 오브젝트를 선택한 뒤 `.ms` 파일을 실행합니다. 현재 프레임의 키는 미리 선택할 필요가 없습니다.
2. 기본 **SELECT — Current frame only** 모드는 현재 `sliderTime` 프레임의 키만 표시합니다. 키 사전 선택은 필요하지 않으며, 다른 프레임의 키는 선택되어 있어도 제외합니다.
3. **ALL — All keys** 모드는 선택한 오브젝트에 속한 모든 키를 표시합니다. 모드를 바꾸면 즉시 다시 검색합니다.
4. SELECT에서는 시간 슬라이더를 옮길 때마다 갱신하며, 키가 없는 프레임은 목록과 편집란을 비웁니다. ALL은 키가 있는 프레임에서 자동 갱신합니다. 필요하면 **REFRESH / SCAN**으로 직접 갱신할 수 있습니다.
5. 목록에서 한 키를 고르고 값을 수정하거나 정수 TARGET FRAME을 입력합니다.

두 모드 모두 선택한 오브젝트 범위입니다. 오브젝트 선택과 무관한 씬 전체/Track View 전역 키 검색은 지원하지 않습니다. 키가 없는 트랙은 목록에 나오지 않으며, 최초 키 생성은 이번 변경 범위에서 제외했습니다.

## 0.3 시간 이동 자동 갱신

- 마우스 슬라이더 이동과 `sliderTime = 40f` 같은 스크립트 시간 변경을 감지합니다. 마지막 시간 변경 후 약 180ms 뒤 현재 프레임을 검사합니다.
- 키 선택 여부와 관계없이 갱신합니다. 검사 범위는 현재 선택 오브젝트입니다. SELECT는 빈 프레임도 갱신해 목록과 편집란을 비우며, ALL은 빈 프레임에서 기존 목록을 유지합니다.
- 캐시된 목록 대신 실제 트랙을 검사하므로, 목록 갱신 후 추가된 키도 감지합니다.
- SELECT는 현재 프레임만, ALL은 모든 프레임을 표시합니다. 갱신은 미적용 입력을 초기화합니다.
- 창을 닫으면 타이머와 해당 시간 콜백을 해제하며, 다시 실행할 때 중복 등록하지 않습니다. Max에서 시간 콜백을 전역 비활성화한 경우 이를 임의로 활성화하지 않습니다.

API 근거: [Time Change Callback Mechanism](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Change-Handlers-and-Callbacks/GUID-962137D0-2937-4A31-A3E0-2BBF8C365577.html), [Timer UI Control](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Creating-MAXScript-Tools/Scripted-Utilities-and-Rollouts/Rollout-User-Interface-Controls/Rollout-User-Interface-Controls-3/GUID-9A4F0A09-BB42-4EED-95CC-6B3D06939640.html).

## 0.4 현재 프레임 행 선택과 스크롤

자동 Refresh 후 현재 `sliderTime`과 같은 시간의 키 행을 선택하고 `EnsureVisible()`로 해당 행이 보이도록 스크롤합니다. 같은 프레임에 여러 트랙의 키가 있으면 이전에 목록에서 선택했던 컨트롤러를 우선하며, 그 트랙에 현재 프레임 키가 없으면 첫 번째 일치 행을 선택합니다. 값·프레임·접근 경로 입력부도 선택한 키에 맞춰 갱신합니다.

목록 안의 행 선택만 바꾸며, 씬의 실제 키 선택 상태와 키 데이터는 변경하지 않습니다. 수동 Refresh와 모드 전환의 기존 첫 행 선택 동작은 유지합니다.

## 0.6 현재 프레임 필터와 셀 배경

SELECT는 현재 프레임의 모든 지원 키만 표시하고 일치 행을 선택해 스크롤합니다. 다른 프레임의 선택 키도 표시하지 않습니다. 빈 프레임으로 이동하면 행 선택, 값, 프레임, 접근 경로 입력란을 함께 비웁니다. ALL은 계속 모든 키를 표시합니다. 씬 키 자체를 선택하거나 수정하지 않습니다.

`Object / Track (SubAnim)` 셀에만 옅은 배경색을 적용합니다. 실제 말단 트랙 이름에 독립된 X/Y/Z 표기가 있을 때 X는 적색(255,228,228), Y는 녹색(227,245,228), Z는 청색(225,236,255)입니다. `X Position`, `Y Rotation`, `Z Scale` 등이 대상이며, `Box`, `XYZ`, `Intensity`, 오브젝트/상위 경로 이름만으로 축 색상을 추정하지 않습니다.

실제 라이트 오브젝트의 트랙 셀은 옅은 노란색(255,248,204)입니다. V-Ray Light의 intensity에 해당하는 `multiplier`도 포함합니다. 라이트의 X/Y/Z 축 셀에는 축 색상을 우선합니다. 자동 선택된 행에서도 이 셀 색상은 유지하고, 다른 열의 선택 표시는 기본 동작을 유지합니다.

- **APPLY VALUE**: 원본 키의 값만 변경합니다.
- **CREATE NEW KEY**: 기존 키가 있는 트랙에서 지정 프레임에 키를 생성합니다. 점유 프레임은 거부합니다.
- **MOVE KEY**: 시간만 이동하고 원래 값을 보존합니다. 값 입력란의 미적용 수정은 이동에 사용하지 않습니다. 값 수정은 APPLY VALUE로 먼저 적용합니다.
- **COPY PATH**: 현재 세션의 인덱스 접근 경로를 복사합니다. AnimHandle과 SubAnim 인덱스는 영구 식별자가 아닙니다.

## 0.2 변경

- SELECT 기본값과 ALL을 별도 라디오 모드로 구성했습니다.
- Float 표시 정밀도를 높이고, 입력을 바꾸지 않으면 표시 문자열을 재해석하지 않고 실제 값을 사용합니다. Point3 등도 미수정 값은 원래 타입/값을 사용합니다.
- Boolean Controller(`boolean_float`)에 `true/false/on/off/1/0/1.0/0.0`을 받아 Float 0/1로 적용합니다. 일반 Float 트랙에는 이 변환을 적용하지 않습니다.
- 쓰기 전에 노드, SubAnim 인덱스 경로, 연결된 컨트롤러, 키 시간, 원본 값/타입을 다시 확인합니다. 외부 변경이 있으면 새로 고쳐야 합니다.
- 목록 행을 .NET `Tag`로 연결해 표시 순서와 원본 데이터의 인덱스를 분리했습니다.
- 같은 클래스의 임시 컨트롤러에서 작업을 먼저 시험하고, 키 수·목적지·타입/값·다른 키의 시간/값을 검사합니다.
- 중간 키를 넘는 이동은 I_KEYCONTROL의 `appendKey`를 사용해 네이티브 키 데이터를 복사합니다. 지원하지 않는 컨트롤러는 거부합니다.
- 쓰기는 하나의 Undo 기록으로 묶고 실패하면 자신의 작업만 취소합니다. 복구한 키 상태도 확인하며, 복구 불일치가 있으면 명시적으로 알립니다.
- 검색 실패 시 ListView의 업데이트 잠금을 해제합니다.

## 제한

원시 키 값은 Modify 패널의 표시 단위와 다를 수 있습니다. 각도·퍼센트·색상의 UI 단위를 자동 변환하지 않습니다. `On_Off`는 키 추가 자체가 토글에 영향을 주므로 편집을 거부합니다. `.value`를 읽을 수 있다는 것만으로 setter 지원을 보장하지 않습니다.

곡선 전체의 모양 보존을 보장하지 않습니다. 특히 Auto/Smooth 접선이나 중간 키를 넘는 이동은 인접 구간을 바꿀 수 있습니다. 플러그인의 복사/Undo 구현도 모두 검증된 것은 아닙니다. 원래 컨트롤러를 다른 클래스로 교체하지 않습니다.

## 검증

`tests/run_runtime_tests.ms`는 실제 소스의 접두사만 별도 `USKET_` 이름으로 바꾸고 테스트를 삽입하여 실행합니다. 사용자 도구 창을 교체하지 않습니다. 자신의 임시 테스트 오브젝트만 생성/삭제하고 선택 및 시간 슬라이더를 복원합니다. 저장/리셋/Undo 버퍼 삭제는 하지 않습니다. 테스트 작업은 Undo 이력에 남을 수 있습니다.

2026-10-19, 3ds Max 2027.2에서 **79 PASS / 0 FAIL**입니다. 두 검색 모드, Float/Point3/Boolean, Bend Angle, 표준 라이트 강도, 키 생성/충돌/이동, 이동 Undo/Redo, 외부 값·컨트롤러 변경 감지, 행 Tag 매핑을 확인했습니다. 실제 삽입 및 중간 키를 넘는 이동 직후 오류를 주입해 복구도 확인했습니다. 오류 주입은 메모리 안의 테스트용 사본에만 존재합니다.

0.3에서는 실제 `sliderTime` 대입, 키가 없는 프레임의 무갱신, SELECT의 선택 여부 조건, 최신 값 재조회, 캐시에 없던 새 키 감지, 연속 시간 변경 지연 처리, 콜백 해제 및 재열기 중복 방지까지 추가 검증했습니다.

0.4에서는 현재 프레임 행 선택과 편집란 갱신, 동일 프레임의 이전 트랙 우선/대체 행 선택, 60행 목록에서 선택 행의 실제 화면 경계와 스크롤 위치까지 검사했습니다. 프로그램에 의한 UI 검증이며 사용자 시각 승인과는 별개입니다.

0.5에서는 SELECT 모드의 미선택 현재 프레임 키 표시·목록 자동 선택, 다른 프레임 미선택 키 제외, 캐시에 없는 새 미선택 키 감지, 씬 키 선택 상태 미변경까지 검사했습니다.

0.6에서는 SELECT의 빈 프레임 목록/입력란 초기화, 다른 프레임의 선택된 키 제외, 현재 프레임만 표시하는 조건을 검사했습니다. 실제 XYZ 트랙과 일반 라이트, V-Ray Light `multiplier`의 셀 색을 확인하고, 선택된 셀을 비트맵으로 그려 해당 배경 픽셀의 RGB 값까지 검사했습니다.

키가 없는 트랙의 제외와 전통 On/Off의 미지원 키 API 제외도 확인했습니다. Integer는 파서만 시험했으며 실제 Integer 컨트롤러, V-Ray 키 편집/tyFlow 및 사용자 시각 승인은 미검증입니다. V-Ray Light multiplier 셀의 색상은 실물 테스트 노드에서 검증했습니다. UI 속성의 프로그램 검사는 실제 사용자 시각 승인과 별개입니다.

성공/실패의 기준은 `tests/runtime_report.txt`입니다. `palette_final_console.log`에는 `Task Completed Successfully`가 기록됐습니다. 이후 플러그인 종료 단계에 남아 있던 테스트용 Batch 호스트만 종료했고 런처 종료 코드는 **1**이므로 정상 프로세스 종료를 확인한 결과로 해석하지 않습니다. 사용자 Max 인스턴스는 종료하지 않았습니다.

```powershell
& 'C:\Program Files\Autodesk\3ds Max 2027\3dsmaxbatch.exe' `
  'C:\Users\user\Documents\MAXSCRIPT\UniversalSelectedKeyEditor\tests\run_runtime_tests.ms' `
  -listenerlog 'C:\Users\user\Documents\MAXSCRIPT\UniversalSelectedKeyEditor\tests\palette_final_listener.log' `
  -log 'C:\Users\user\Documents\MAXSCRIPT\UniversalSelectedKeyEditor\tests\palette_final.log'
```

API 근거: [Controller Key Functions](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Animation-Controllers/Controller-Common-Properties/GUID-B1700B1D-B1EA-4A6C-B4A3-A29DB26C8C02.html), [theHold](https://help.autodesk.com/cloudhelp/2025/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Miscellaneous-Functions/GUID-17BFEAAF-3395-4FFB-9F98-54767481AB08.html).
