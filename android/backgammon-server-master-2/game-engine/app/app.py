from flask import Flask

from analyze_controller import analyze_bp

app = Flask(__name__)
app.register_blueprint(analyze_bp, url_prefix='/game-engine/analyze')

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
