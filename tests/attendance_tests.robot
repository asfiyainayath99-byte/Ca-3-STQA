*** Settings ***
Library           RequestsLibrary
Library           Collections
Suite Setup       Open Attendance API Session
Suite Teardown    Close Attendance API Session
Test Tags         attendance    api

*** Variables ***
${BASE_URL}       http://127.0.0.1:5000
${SESSION_ALIAS}  attendance_api

*** Test Cases ***
TC01 - Add A Valid Student
    ${student}=    Create Test Student
    Should Be True    ${student}[id] > 0
    ${response}=    GET On Session    ${SESSION_ALIAS}    /students
    Status Should Be    200    ${response}
    Should Contain    ${response.json()}    ${student}

TC02 - Reject An Empty Student Name
    ${payload}=    Create Dictionary    name=${EMPTY}    roll_no=${EMPTY}
    ${response}=    POST On Session    ${SESSION_ALIAS}    /students    json=${payload}    expected_status=any
    Status Should Be    400    ${response}

TC03 - Retrieve An Existing Student
    ${created}=    Create Test Student
    ${response}=    GET On Session    ${SESSION_ALIAS}    /students/${created}[id]
    Status Should Be    200    ${response}
    Should Be Equal As Integers    ${response.json()}[id]    ${created}[id]
    Should Be Equal    ${response.json()}[name]    ${created}[name]

TC04 - Return Not Found For An Unknown Student
    ${response}=    GET On Session    ${SESSION_ALIAS}    /students/987654321    expected_status=any
    Status Should Be    404    ${response}

TC05 - Mark A Student Present
    ${student}=    Create Test Student
    ${response}=    Mark Attendance    ${student}[id]    Present    2026-01-01
    Status Should Be    201    ${response}
    Should Be Equal As Integers    ${response.json()}[student_id]    ${student}[id]
    Should Be Equal    ${response.json()}[status]    Present

TC06 - Reject An Invalid Attendance Status
    ${student}=    Create Test Student
    ${student_id}=    Convert To Integer    ${student}[id]
    ${payload}=    Create Dictionary    student_id=${student_id}    status=Late    date=2026-01-02
    ${response}=    POST On Session    ${SESSION_ALIAS}    /attendance    json=${payload}    expected_status=any
    Status Should Be    400    ${response}

TC07 - Reject Attendance For An Unknown Student
    ${payload}=    Create Dictionary    student_id=${987654321}    status=Present    date=2026-01-03
    ${response}=    POST On Session    ${SESSION_ALIAS}    /attendance    json=${payload}    expected_status=any
    Status Should Be    404    ${response}

TC08 - Calculate The Present Percentage
    ${student}=    Create Test Student
    ${student_id}=    Convert To Integer    ${student}[id]
    ${present}=    Mark Attendance    ${student_id}    Present    2026-01-04
    Status Should Be    201    ${present}
    ${absent}=    Mark Attendance    ${student_id}    Absent    2026-01-05
    Status Should Be    201    ${absent}
    ${records}=    GET On Session    ${SESSION_ALIAS}    /attendance/${student_id}
    Status Should Be    200    ${records}
    Length Should Be    ${records.json()}    2
    ${response}=    GET On Session    ${SESSION_ALIAS}    /attendance/${student_id}/percentage
    Status Should Be    200    ${response}
    Should Be Equal As Numbers    ${response.json()}[percentage]    50.0

TC09 - Delete A Student And Its Attendance
    ${student}=    Create Test Student
    ${student_id}=    Convert To Integer    ${student}[id]
    ${marked}=    Mark Attendance    ${student_id}    Present    2026-01-06
    Status Should Be    201    ${marked}
    ${deleted}=    DELETE On Session    ${SESSION_ALIAS}    /students/${student_id}    expected_status=any
    Status Should Be    204    ${deleted}
    ${missing_student}=    GET On Session    ${SESSION_ALIAS}    /students/${student_id}    expected_status=any
    Status Should Be    404    ${missing_student}
    ${missing_records}=    GET On Session    ${SESSION_ALIAS}    /attendance/${student_id}    expected_status=any
    Status Should Be    404    ${missing_records}

*** Keywords ***
Open Attendance API Session
    Create Session    ${SESSION_ALIAS}    ${BASE_URL}

Close Attendance API Session
    Delete All Sessions

Create Test Student
    ${suffix}=    Evaluate    __import__('uuid').uuid4().hex
    ${payload}=    Create Dictionary    name=Robot Test Student    roll_no=RF-${suffix}
    ${response}=    POST On Session    ${SESSION_ALIAS}    /students    json=${payload}
    Status Should Be    201    ${response}
    RETURN    ${response.json()}

Mark Attendance
    [Arguments]    ${student_id}    ${status}    ${attendance_date}
    ${integer_student_id}=    Convert To Integer    ${student_id}
    ${payload}=    Create Dictionary    student_id=${integer_student_id}    status=${status}    date=${attendance_date}
    ${response}=    POST On Session    ${SESSION_ALIAS}    /attendance    json=${payload}    expected_status=any
    RETURN    ${response}
