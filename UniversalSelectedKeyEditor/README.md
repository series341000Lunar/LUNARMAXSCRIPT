# Universal Selected Key Editor

3ds Max 2027용 기존 키 편집기입니다. 실행 파일명은 기존 호출 경로를 유지하기 위해 `Universal_Selected_Key_Editor_v0_1.ms`이며, 내부 버전은 0.2입니다.

## 사용

1. Max에서 대상 오브젝트와 키를 선택한 뒤 `.ms` 파일을 실행합니다.
2. 기본 **SELECT — Selected keys** 모드는 선택한 오브젝트에 속한 선택된 키만 표시합니다.
3. **ALL — All keys** 모드는 선택한 오브젝트에 속한 모든 키를 표시합니다. 모드를 바꾸면 즉시 다시 검색합니다.
4. 외부에서 키 선택이나 트랙을 바꿨다면 **REFRESH / SCAN**을 누릅니다.
5. 목록에서 한 키를 고르고 값을 수정하거나 정수 TARGET FRAME을 입력합니다.

두 모드 모두 선택한 오브젝트 범위입니다. 오브젝트 선택과 무관한 씬 전체/Track View 전역 키 검색은 지원하지 않습니다. 키가 없는 트랙은 목록에 나오지 않으며, 최초 키 생성은 이번 변경 범위에서 제외했습니다.

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

2026-10-19, 3ds Max 2027.2에서 **39 PASS / 0 FAIL**입니다. 두 검색 모드, Float/Point3/Boolean, Bend Angle, 표준 라이트 강도, 키 생성/충돌/이동, 이동 Undo/Redo, 외부 값·컨트롤러 변경 감지, 행 Tag 매핑을 확인했습니다. 실제 삽입 및 중간 키를 넘는 이동 직후 오류를 주입해 복구도 확인했습니다. 오류 주입은 메모리 안의 테스트용 사본에만 존재합니다.

키가 없는 트랙의 제외와 전통 On/Off의 미지원 키 API 제외도 확인했습니다. Integer는 파서만 시험했으며 실제 Integer 컨트롤러, V-Ray/tyFlow 및 사용자 시각 승인은 미검증입니다. UI 속성의 프로그램 검사는 실제 사용자 시각 승인과 별개입니다.

성공/실패의 기준은 `tests/runtime_report.txt`입니다. `acceptance_console.log`에는 `Task Completed Successfully`가 기록됐습니다. 이후 플러그인 종료 단계에 남아 있던 테스트용 Batch 호스트만 종료했고 런처 종료 코드는 **1**이므로 정상 프로세스 종료를 확인한 결과로 해석하지 않습니다. 사용자 Max 인스턴스는 종료하지 않았습니다.

```powershell
& 'C:\Program Files\Autodesk\3ds Max 2027\3dsmaxbatch.exe' `
  'C:\Users\user\Documents\MAXSCRIPT\UniversalSelectedKeyEditor\tests\run_runtime_tests.ms' `
  -listenerlog 'C:\Users\user\Documents\MAXSCRIPT\UniversalSelectedKeyEditor\tests\acceptance_listener.log' `
  -log 'C:\Users\user\Documents\MAXSCRIPT\UniversalSelectedKeyEditor\tests\acceptance.log'
```

API 근거: [Controller Key Functions](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Animation-Controllers/Controller-Common-Properties/GUID-B1700B1D-B1EA-4A6C-B4A3-A29DB26C8C02.html), [theHold](https://help.autodesk.com/cloudhelp/2025/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Miscellaneous-Functions/GUID-17BFEAAF-3395-4FFB-9F98-54767481AB08.html).
