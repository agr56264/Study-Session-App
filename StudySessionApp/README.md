# ClockedIn  
If you’re not focused, you’re clocked out.

ClockedIn is a macOS study timer that enforces real accountability. Unlike traditional Pomodoro timers, time only progresses when the user is present and focused.

## What It Does
- Timed work and break sessions
- Real-time focus detection using the device camera
- Lives-based accountability system
- Automatic work-to-break transitions
- Daily lockout after repeated loss of focus

## How It Works
- Work sessions only count down when focus is detected
- Losing focus pauses the timer
- Users must restart or lose a life after continued distraction
- Break sessions run automatically without focus enforcement

## Privacy
- Camera used only to detect presence
- No images, video, or biometric data stored
- All processing happens locally

## Running the App
**Requirements:** macOS 13+, webcam

1. Download and unzip the app
2. Right-click → Open → Open anyway
3. Allow camera access when prompted

• Implemented as a native macOS application using SwiftUI’s declarative, state-driven UI architecture
• Managed core application state including session type, timer countdown, focus status, lives, and lockout logic using SwiftUI property wrappers such as @State, @StateObject, and @AppStorage
• Implemented time-based session updates using Combine’s Timer publisher to drive reactive countdown behavior
• Integrated camera access and real-time presence detection using AVFoundation, gating timer progression based on focus state
• Coordinated work and break session transitions through centralized session management logic
• Ensured all processing occurs locally on the device with no external data storage or transmission
