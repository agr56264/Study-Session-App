from flask import Flask, jsonify
import os
import time

app = Flask(__name__)

# Simulated focus state (replace later if needed)
focused = True
last_toggle = time.time()
@app.route("/focus")
def focus_status():
    """
    Returns current focus state.
    """
    return jsonify({"focused": focused})


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/toggle")
def toggle_focus():
    """
    Demo-only endpoint to simulate losing/gaining focus.
    """
    global focused, last_toggle
    focused = not focused
    last_toggle = time.time()
    return jsonify({"focused": focused})


if __name__ == "__main__":
    # Render provides PORT via env variable
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)