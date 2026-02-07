# This is going to be Flask API with all endpoints
# @app.route('/health', methods=['GET'])
# def health():
#     return {'status': 'ok'}
#
# This creates an endpoint at http://localhost:5000/health that returns {"status": "ok"}.
#
# How It Works
#
# 1. **iOS app makes a request** → "Hey, analyze this camera frame for me"
# 2. **Flask API receives it** → Opens the request
# 3. **Backend processes it** → Runs MediaPipe pose detection
# 4. **Sends response back** → "Your posture score is 85"
#
# Example Flow
# iOS App (Frontend)
#     ↓ (sends image)
# Flask API (Backend)
#     ↓ (processes with MediaPipe)
# Returns posture score
#     ↓
# iOS App shows result
