from threading import Semaphore

from flask import Blueprint, jsonify, request

from analyze_game_service import analyze as analyze_match

analyze_bp = Blueprint('analyze', __name__)
sem = Semaphore(5)


@analyze_bp.route("", methods=["POST"])
def analyze():
    try:
        body = request.get_json()
        sem.acquire(timeout=10)
        return jsonify(analyze_match(body))
    finally:
        sem.release()
