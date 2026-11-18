"""In-memory student and attendance API for the CA3 testing project."""

from datetime import date
from threading import Lock
from typing import Any

from flask import Flask, jsonify, request

app = Flask(__name__)

_students: dict[int, dict[str, Any]] = {}
_attendance: dict[int, list[dict[str, Any]]] = {}
_next_student_id = 1
_store_lock = Lock()


def _json_object() -> dict[str, Any] | None:
    """Return a JSON object request body, or None for invalid/non-object JSON."""
    body = request.get_json(silent=True)
    return body if isinstance(body, dict) else None


def _valid_date(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return date.fromisoformat(value).isoformat() == value
    except ValueError:
        return False


@app.post("/students")
def create_student():
    global _next_student_id

    body = _json_object()
    if body is None:
        return jsonify(error="Request body must be a JSON object."), 400

    name = body.get("name")
    roll_no = body.get("roll_no")
    if not isinstance(name, str) or not name.strip():
        return jsonify(error="name must be a non-empty string."), 400
    if not isinstance(roll_no, str) or not roll_no.strip():
        return jsonify(error="roll_no must be a non-empty string."), 400

    normalized_roll_no = roll_no.strip()
    with _store_lock:
        if any(student["roll_no"] == normalized_roll_no for student in _students.values()):
            return jsonify(error="roll_no already exists."), 400

        student = {
            "id": _next_student_id,
            "name": name.strip(),
            "roll_no": normalized_roll_no,
        }
        _students[_next_student_id] = student
        _attendance[_next_student_id] = []
        _next_student_id += 1

    return jsonify(student), 201


@app.get("/students")
def list_students():
    with _store_lock:
        students = [student.copy() for student in _students.values()]
    return jsonify(students), 200


@app.get("/students/<int:student_id>")
def get_student(student_id: int):
    with _store_lock:
        student = _students.get(student_id)
        if student is None:
            return jsonify(error="Student not found."), 404
        return jsonify(student.copy()), 200


@app.delete("/students/<int:student_id>")
def delete_student(student_id: int):
    with _store_lock:
        if student_id not in _students:
            return jsonify(error="Student not found."), 404
        del _students[student_id]
        _attendance.pop(student_id, None)
    return "", 204


@app.post("/attendance")
def create_attendance():
    body = _json_object()
    if body is None:
        return jsonify(error="Request body must be a JSON object."), 400

    student_id = body.get("student_id")
    status = body.get("status")
    attendance_date = body.get("date")

    # bool is an int subclass in Python, so require the exact JSON integer type.
    if type(student_id) is not int:
        return jsonify(error="student_id must be an integer."), 400
    if status not in ("Present", "Absent"):
        return jsonify(error="status must be Present or Absent."), 400
    if not _valid_date(attendance_date):
        return jsonify(error="date must be a valid YYYY-MM-DD date."), 400

    with _store_lock:
        if student_id not in _students:
            return jsonify(error="Student not found."), 404

        record = {
            "student_id": student_id,
            "status": status,
            "date": attendance_date,
        }
        _attendance[student_id].append(record)

    return jsonify(record), 201


@app.get("/attendance/<int:student_id>")
def get_attendance(student_id: int):
    with _store_lock:
        if student_id not in _students:
            return jsonify(error="Student not found."), 404
        records = [record.copy() for record in _attendance[student_id]]
    return jsonify(records), 200


@app.get("/attendance/<int:student_id>/percentage")
def get_attendance_percentage(student_id: int):
    with _store_lock:
        if student_id not in _students:
            return jsonify(error="Student not found."), 404
        records = _attendance[student_id]
        total_days = len(records)
        present_days = sum(record["status"] == "Present" for record in records)

    percentage = (present_days / total_days * 100.0) if total_days else 0.0
    return jsonify(
        student_id=student_id,
        total_days=total_days,
        present_days=present_days,
        percentage=percentage,
    ), 200


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)
