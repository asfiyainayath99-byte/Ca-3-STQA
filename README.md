# Student Attendance API — CA3

## Project overview

A locally hosted Flask REST API with an in-memory student and attendance store,
tested over HTTP with Robot Framework and RequestsLibrary. Data is intentionally
not persistent and is cleared when the API process exits.

## Team

| Student | Role |
| --- | --- |
| Student A: Rabiya Banu | Lead Tool Architect & Framework Specialist |
| Student B: Asfiya | Lead Test Designer & SUT Engineer |

**Section:** 5ISE01

## Prerequisites and setup

Use Python 3.10 or newer. From the project root, install the dependencies:

```console
python -m pip install -r requirements.txt
```

Open two terminals in the project root. Start the API in the first terminal:

```console
python src/app.py
```

When Flask reports that it is serving on `http://127.0.0.1:5000`, run the
acceptance suite from the second terminal:

```console
robot --outputdir results tests/attendance_tests.robot
```

The Robot suite creates and closes its RequestsLibrary HTTP session through
suite setup and teardown. It uses unique roll numbers so repeated runs do not
depend on earlier in-memory data. The API process must be running before the
suite starts.

## API endpoints

All request and response bodies use JSON except for the empty response to a
successful student deletion.

| Method and path | Behavior |
| --- | --- |
| `POST /students` | Add a student from `{"name": "...", "roll_no": "..."}`; returns `201`, or `400` for invalid/duplicate input. |
| `GET /students` | Return the student list (`200`). |
| `GET /students/{id}` | Return one student (`200`) or `404`. |
| `DELETE /students/{id}` | Delete a student and their attendance records (`204`) or return `404`. |
| `POST /attendance` | Add a record from `{"student_id": 1, "status": "Present", "date": "2026-01-01"}`; returns `201`, `400` for invalid input, or `404` for an unknown student. `student_id` must be a JSON integer. |
| `GET /attendance/{id}` | Return a student's attendance records (`200`) or `404` for an unknown student. |
| `GET /attendance/{id}/percentage` | Return `student_id`, `total_days`, `present_days`, and `percentage` (`200`), or `404`. A student with no attendance has `0.0` percent. |

Attendance status is case-sensitive and accepts only `Present` and `Absent`.
Dates must be valid `YYYY-MM-DD` calendar dates. The attendance percentage is
the number of present records divided by all records, multiplied by 100.

## Test cases

`tests/attendance_tests.robot` covers:

| Case | Expected behavior |
| --- | --- |
| TC01 | Create a valid student (`201`) and find it in the student list (`200`). |
| TC02 | Reject an empty name (`400`). |
| TC03 | Retrieve a created student (`200`). |
| TC04 | Return `404` for an unknown student ID. |
| TC05 | Mark attendance as `Present` (`201`). |
| TC06 | Reject `Late` as an attendance status (`400`). |
| TC07 | Return `404` when marking attendance for an unknown student. |
| TC08 | Retrieve two records and calculate a `50.0%` present rate. |
| TC09 | Delete a student (`204`), then confirm student and attendance lookups return `404`. |

The shared `Mark Attendance` keyword explicitly converts the supplied student
ID to an integer before creating the JSON request. This prevents defect D1,
where a numeric-looking ID serialized as a string was rejected by the API.

## Defect log

The assignment specification identifies D1; the remaining entries below
document the corresponding validation and result-handling defects exercised
by this implementation.

| ID | Defect | Resolution / regression coverage |
| --- | --- | --- |
| D1 | Attendance request carries `student_id` as a string instead of an integer. | Convert the ID in `Mark Attendance`; the API rejects non-integer JSON IDs. Covered by TC05 and TC08. |
| D2 | Missing or whitespace-only student name can be registered. | Require a non-empty trimmed name. Covered by TC02. |
| D3 | Unsupported attendance values (for example, `Late`) are accepted. | Restrict status to `Present` or `Absent`. Covered by TC06. |
| D4 | Unknown student IDs are not handled consistently, or deletion leaves attendance behind. | Return `404` for unknown IDs and cascade deletion of attendance records. Covered by TC04, TC07, and TC09. |

## Coverage

The suite has **9 acceptance test cases** across student registration, listing,
retrieval, validation, attendance creation/retrieval, percentage calculation,
unknown IDs, and deletion. This is functional endpoint coverage, not a
statement-coverage percentage.

The assignment's **approximately 87.5% statement-coverage target** was checked
against the nine-test suite: the API recorded **88% statement coverage (86 of
98 statements)** in the validation run. Coverage can vary if the code or
environment changes. The `coverage` package is included in `requirements.txt`;
because the API and Robot runner execute in separate processes, collect API
coverage by launching Flask under Coverage.py, running the Robot command above
in another terminal, and stopping Flask with Ctrl+C before reporting:

```console
coverage run --source=src src/app.py
coverage report -m
```

Coverage results depend on which branches the tests exercise and are not
guaranteed to equal 87.5%.
