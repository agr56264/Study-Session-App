import cv2
import mediapipe as mp
from flask import Flask, jsonify
import threading
import time

app = Flask(__name__)

mp_face = mp.solutions.face_detection
face_detection = mp_face.FaceDetection(
model_selection=0,
min_detection_confidence=0.5
)

cap = cv2.VideoCapture(0)

focused = True
last_seen = time.time()
GRACE_PERIOD = 3 # seconds

def camera_loop():
global focused, last_seen
while True:
success, frame = cap.read()
if not success:
continue

rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
results = face_detection.process(rgb)

if results.detections:
focused = True
last_seen = time.time()
else:
if time.time() - last_seen > GRACE_PERIOD:
focused = False

@app.route("/focus")
def focus_status():
return jsonify({"focused": focused})

if __name__ == "__main__":
threading.Thread(target=camera_loop, daemon=True).start()
app.run(port=5000)