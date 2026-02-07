import cv2
import mediapipe as mp
from flask import Flask, jsonify
import threading
import time

app = Flask(__name__)

# MediaPipe face detection
mp_face = mp.solutions.face_detection
face_detection = mp_face.FaceDetection(
    model_selection=0,
    min_detection_confidence=0.5
)

# Camera (macOS)
cap = cv2.VideoCapture(0, cv2.CAP_AVFOUNDATION)

focused = True
last_seen = time.time()
GRACE_PERIOD = 3 


def run_flask():
    app.run(host="127.0.0.1", port=5000, debug=False, use_reloader=False)


@app.route("/focus")
def focus_status():
    return jsonify({"focused": focused})


def camera_loop():
    global focused, last_seen

    while True:
        success, frame = cap.read()
        if not success:
            continue

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_detection.process(rgb)

        current_time = time.time()

        if results.detections:
            focused = True
            last_seen = current_time
        else:
            if current_time - last_seen > GRACE_PERIOD:
                focused = False

        if focused:
            color = (0, 255, 0)
            status_text = "FOCUSED"
        else:
            color = (0, 0, 255)
            status_text = "NOT FOCUSED"

        cv2.circle(frame, (40, 40), 15, color, -1)
        cv2.putText(
            frame,
            status_text,
            (70, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            color,
            2
        )

        cv2.imshow("Study Session Camera", frame)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    # Start Flask in background thread
    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()

    # Run camera loop on MAIN thread (required on macOS)
    camera_loop()