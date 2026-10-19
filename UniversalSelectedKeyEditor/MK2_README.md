# Universal Selected Key Editor MK2

실행 파일: `Universal_Selected_Key_Editor_MK2.ms`. 기존 `Universal_Selected_Key_Editor_v0_1.ms`는 유지합니다. 창 제목은 **MK2**입니다.

## Object / Track 범주 필터

`Object / Track (SubAnim)`의 데이터 셀을 우클릭합니다. 경로를 이루는 각 단계가 범주로 나타납니다. 예를 들어 `Peel_Move_1 > Slow > slowVelX`에서 `Peel_Move_1`을 고르면 그 하위 트랙을 함께 대상으로 삼고, `slowVelX`를 고르면 해당 트랙의 키만 대상으로 삼습니다.

- **ONLY: 범주명**: 그 범주와 하위 범주만 표시합니다.
- **HIDE: 범주명**: 그 범주와 하위 범주를 목록에서 숨깁니다.
- **UNHIDE: 범주 경로**: 숨긴 범주를 복구합니다.
- **SHOW ALL CATEGORIES**: 범주 숨김과 단독 표시를 모두 해제합니다. 초기 기본값입니다.

목록이 비어 있어도 빈 영역을 우클릭해 UNHIDE 또는 SHOW ALL을 사용할 수 있습니다. 필터는 창을 사용하는 동안 자동 Refresh와 모드 전환 뒤에도 유지됩니다. 창을 다시 열면 기본값으로 시작합니다. 범주는 해당 오브젝트와 SubAnim 인덱스 경로를 기준으로 구분하므로 다른 오브젝트의 같은 이름 범주와 섞이지 않습니다. 구조를 바꾸어 인덱스가 달라진 경우 SHOW ALL로 초기화하십시오.

이 기능은 도구의 목록만 필터링합니다. 씬의 Hide/Unhide, 오브젝트 선택, 실제 키 선택, 키 데이터는 바꾸지 않습니다. SELECT는 현재 프레임 키 중 필터를 통과한 항목만, ALL은 전체 프레임 키 중 필터를 통과한 항목만 표시합니다.

## Value 셀 직접 편집

Value 셀을 **더블클릭**하면 셀 위에 입력창이 열립니다.

- **Enter**: 해당 행의 원본 키 값을 적용합니다.
- **Esc**, 다른 곳 클릭, Refresh, 범주 변경: 미적용 입력을 취소합니다.
- 타입에 맞지 않는 입력: 적용하지 않고 수정할 수 있도록 입력창을 유지합니다.

ALL 모드에서는 현재 `sliderTime`과 다른 프레임의 키도 직접 수정할 수 있습니다. 타임 슬라이더를 해당 키로 옮기거나 키 시간을 바꾸지 않습니다. 가로 스크롤 때문에 Value 셀이 가려졌다면 먼저 해당 열이 보이게 스크롤합니다.

기존 Float/Integer/Boolean/Point3 등의 타입 검사, 원시 값 단위, 연결된 트랙 재확인, 원본 값 외부 변경 거부, Undo/Redo와 실패 시 복구를 그대로 사용합니다. 값 입력은 임의의 `execute`로 평가하지 않습니다. 첫 키 생성은 여전히 지원하지 않습니다.

2026-10-19 Enter 입력 수정: 기존 중첩 TextBox에서는 Windows Enter 메시지가 KeyDown에 도달하지 않아 값이 적용되지 않았습니다. Enter를 입력 키로 받도록 설정하고, 편집 중에는 Max 단축키를 잠시 비활성화합니다. 적용·취소·포커스 변경·창 닫기 때 이전 단축키 상태를 복원합니다. 수정본 `.ms` 파일을 다시 실행해야 열린 창에 반영됩니다. 키 처리 방식은 [Microsoft PreviewKeyDown 문서](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.control.previewkeydown)와 [Autodesk 키보드 단축키 문서](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Creating-MAXScript-Tools/ActiveX-Controls-in-MAXScript/GUID-F9BDCDFD-5C2D-42ED-A840-184795A2E057.html)를 참고했습니다.

같은 날 입력창 표시 수정: 열린 Max에서 입력창의 부모가 숨겨진 ListView인 상태를 확인했습니다 (`tests/host_MK2_before_report.txt`). Max 컨트롤 프록시로 되돌아가지 않도록 실제 핸들 검색·부모 연결·표시·포커스를 .NET 안에서 처리합니다. 작은 보조 어셈블리는 `.ms` 안에 포함되어 별도 DLL 설치가 필요 없으며, 원본은 `support/MK2InlineHost.cs`입니다. 더블클릭의 MouseDown/MouseUp 처리가 끝난 뒤 입력창을 열고, 네이티브 대화상자가 키 누름을 소비하는 경우 키 놓음에서 Enter/Esc를 처리합니다. 이미 적용된 편집은 다시 적용하지 않습니다.

## 기존 동작

SELECT는 현재 프레임의 키만 표시하고 빈 프레임에서 목록과 편집란을 비웁니다. ALL은 모든 키를 표시합니다. 자동 Refresh 뒤 현재 프레임 행 선택·스크롤, XYZ 트랙 셀의 적·녹·청, 라이트 트랙 셀의 노란색도 유지합니다. 자세한 기존 편집 동작과 지원 제한은 `README.md`를 참고하십시오.

## 검증

`tests/run_MK2_tests.ms`는 MK2 소스를 별도 접두사의 테스트 사본으로 실행합니다. 결과는 `tests/runtime_MK2_report.txt`입니다. 이전 버전의 소스와 테스트 파일은 수정하지 않습니다. 테스트는 임시 오브젝트를 만들고 정리하며 선택과 시간을 복원합니다. 저장·리셋·Undo 버퍼 삭제를 하지 않으며 테스트 이력은 Undo에 남을 수 있습니다.

키 API와 UI 속성의 프로그램 검증은 사용자 시각·마우스 사용 승인과 별개입니다. V-Ray 셀 색상 검증을 V-Ray/tyFlow 전체 키 편집 호환성으로 해석하지 않습니다.

2026-10-19 / 3ds Max 2027.2, 표시 수정 후 재검증: 기존 **101/0** (`tests/runtime_MK2_report.txt`), 키 메시지 **8/0** (`tests/keyboard_MK2_report.txt`), 마우스부터 입력까지 **10/0** (`tests/mouse_MK2_report.txt`), 합계 **119 passed, 0 failed**입니다. `tests/run_MK2_validation.ms`로 세 검증을 실행합니다. 마지막 검증은 WM_LBUTTONDOWN/UP/DBLCLK으로 편집을 시작하고, 메시지 처리 뒤 Visible/Focused 및 부모 핸들을 확인한 다음 WM_CHAR로 입력하고 Enter로 임시 원본 키를 수정합니다. Undo/Redo와 편집 직전 단축키 상태 복원도 검사합니다. 강제 MAXScript/.NET 가비지 수집 뒤 첫 편집도 확인합니다.

일반 Max의 실제 MK2 창에서도 더블클릭 후 Visible/Focused와 부모 핸들 일치를 확인했습니다 (`tests/live_host_MK2_report.txt`). 별도 UI 사본에서는 실제 씬 쓰기를 기록용 함수로 대체하여 더블클릭→문자 입력→Enter 전달을 확인하고 원본 값이 그대로임을 검증했습니다 (`tests/live_input_MK2_report.txt`). 사용자 씬에 테스트 값을 적용하거나 저장하지 않았습니다. 실제 마우스·물리 키보드 조작과 최종 시각 승인은 별도입니다.

Batch 로그 `tests/MK2_native_host_final_console.log`에는 `Task Completed Successfully`가 기록되었습니다. 이후 종료 단계에 남은 해당 테스트 전용 프로세스를 정리하여 실행기 종료 코드는 1입니다. 위 119/0 결과는 스크립트 보고서 기준이며 정상 프로세스 종료를 뜻하지 않습니다.
