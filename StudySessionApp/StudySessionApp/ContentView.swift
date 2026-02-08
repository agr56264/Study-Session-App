//
//  ContentView.swift
//  StudySessionApp
//
//  Created by Max Finch on 2/6/26.
//

import SwiftUI
import Combine

enum SessionType: String {
    case work = "Work"
    case breakTime = "Break"
}

struct ContentView: View {
    // Settings (minutes)
    @State private var workMinutes: Int = 25
    @State private var breakMinutes: Int = 5
    @State private var workMinutesText: String = "25"
    @State private var breakMinutesText: String = "5"

    // Timer state
    @State private var session: SessionType = .work
    @State private var secondsRemaining: Int = 25 * 60
    @State private var isRunning: Bool = false

    // Lives system
    @AppStorage("lives") private var lives: Int = 5
    @AppStorage("lockoutDate") private var lockoutDateString: String = ""
    @State private var isLockedOut: Bool = false
    
    // Focus tracking with camera
    @StateObject private var cameraManager = CameraManager()
    @State private var secondsUnfocused: Int = 0
    @State private var showUnfocusedAlert: Bool = false
    @State private var showPauseConfirmation: Bool = false
    @State private var unfocusedWorkItem: DispatchWorkItem?

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Image("study table")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .ignoresSafeArea()
                .clipped()

            if isLockedOut {
                // Lockout Screen
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                    
                    Text("App Locked")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("You've run out of lives for today.")
                        .font(.title3)
                    
                    Text("Come back tomorrow to continue studying!")
                        .foregroundColor(.secondary)
                    
                    Text("Resets at midnight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white.opacity(0.9))
                )
                .padding(24)
            } else {
                // Normal Study Interface
                VStack(spacing: 18) {
                    Text("Study Session")
                        .font(.title)
                        .bold()
                        .padding(.vertical, 10)

                    // Lives Display
                    HStack(spacing: 8) {
                        Text("Lives:")
                            .font(.headline)
                        
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < lives ? "heart.fill" : "heart")
                                .foregroundColor(index < lives ? .red : .gray)
                                .font(.title3)
                        }
                    }
                    .padding(.bottom, 4)

                    Text(session.rawValue)
                        .font(.headline)

                    Text(formatTime(secondsRemaining))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))

                    // Camera Focus Status
                    HStack(spacing: 8) {
                        Circle()
                            .frame(width: 10, height: 10)
                            .foregroundStyle(cameraManager.faceDetected ? .green : .red)
                        Text(cameraManager.faceDetected ? "Focused" : "Not Focused")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Unfocused counter during work session
                    if secondsUnfocused > 0 && isRunning && session == .work {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Unfocused for \(secondsUnfocused)s")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }

                    ProgressView(value: progress)
                        .frame(width: 320)

                    HStack(spacing: 12) {
                        Button(isRunning ? "Pause" : "Start") {
                            if isRunning {
                                // Show confirmation before pausing
                                showPauseConfirmation = true
                            } else {
                                // Starting timer - no confirmation needed
                                isRunning = true
                            }
                        }
                        .keyboardShortcut(.space, modifiers: [])

                        Button("Reset") {
                            resetCurrentSession()
                            isRunning = false
                        }
                    }

                    Divider().frame(width: 360)

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Work (min)")

                            HStack(spacing: 8) {
                                TextField("25", text: $workMinutesText)
                                    .frame(width: 64)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: workMinutesText) { _, newValue in
                                        let digits = newValue.filter { $0.isNumber }
                                        if digits != newValue { workMinutesText = digits }

                                        if let v = Int(digits) {
                                            let clamped = min(max(v, 1), 120)
                                            if clamped != workMinutes { workMinutes = clamped }
                                        }
                                    }

                                Text("min")
                                    .foregroundStyle(.secondary)
                            }

                            Stepper(value: $workMinutes, in: 1...120) {
                                Text("\(workMinutes)")
                            }
                        }
                        .frame(width: 160)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Break (min)")

                            HStack(spacing: 8) {
                                TextField("5", text: $breakMinutesText)
                                    .frame(width: 64)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: breakMinutesText) { _, newValue in
                                        let digits = newValue.filter { $0.isNumber }
                                        if digits != newValue { breakMinutesText = digits }

                                        if let v = Int(digits) {
                                            let clamped = min(max(v, 1), 60)
                                            if clamped != breakMinutes { breakMinutes = clamped }
                                        }
                                    }

                                Text("min")
                                    .foregroundStyle(.secondary)
                            }

                            Stepper(value: $breakMinutes, in: 1...60) {
                                Text("\(breakMinutes)")
                            }
                        }
                        .frame(width: 160)
                    }
                    .disabled(isRunning)
                    .opacity(isRunning ? 0.6 : 1.0)

                    Spacer()
                }
                .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.5)))
                .padding(24)
                .frame(minWidth: 420, minHeight: 360)
            }
        }
        .onAppear {
            workMinutesText = String(workMinutes)
            breakMinutesText = String(breakMinutes)
            resetCurrentSession()
            checkLockoutStatus()
            cameraManager.start()
        }
        .onChange(of: workMinutes) { _, newValue in
            let s = String(newValue)
            if workMinutesText != s { workMinutesText = s }
            if !isRunning && session == .work { resetCurrentSession() }
        }
        .onChange(of: breakMinutes) { _, newValue in
            let s = String(newValue)
            if breakMinutesText != s { breakMinutesText = s }
            if !isRunning && session == .breakTime { resetCurrentSession() }
        }
        .onReceive(tick) { _ in
            // Track focus time during work sessions when timer is running
            if session == .work && isRunning {
                if !cameraManager.faceDetected {
                    secondsUnfocused += 1
                    print("Unfocused for \(secondsUnfocused) seconds")
                    
                    // After 3 seconds unfocused, show alert
                    if secondsUnfocused >= 30 {
                        print("Triggering unfocused alert!")
                        isRunning = false
                        showUnfocusedAlert = true
                        return
                    }
                } else {
                    // Reset counter when focused
                    if secondsUnfocused > 0 {
                        print("Back in focus, resetting counter")
                    }
                    secondsUnfocused = 0
                }
            }
            
            // Timer countdown only when running
            guard isRunning else { return }

            // Timer countdown (only runs when focused during work, always runs during breaks)
            let canCountDown = (session == .work && cameraManager.faceDetected) || session == .breakTime
            if canCountDown && secondsRemaining > 0 {
                secondsRemaining -= 1
            } else if secondsRemaining == 0 {
                handleSessionComplete()
            }
        }
        .alert(alertTitle, isPresented: Binding(
            get: { showUnfocusedAlert || showPauseConfirmation },
            set: { if !$0 { showUnfocusedAlert = false; showPauseConfirmation = false } }
        )) {
            if showUnfocusedAlert {
                Button("Restart Timer & Stay Focused") {
                    resetCurrentSession()
                    isRunning = true
                    secondsUnfocused = 0
                    showUnfocusedAlert = false
                }
                
                Button("Give Up (Lose Life)", role: .destructive) {
                    loseLife(reason: "Lost focus and chose not to restart")
                    resetCurrentSession()
                    secondsUnfocused = 0
                    showUnfocusedAlert = false
                }
            } else if showPauseConfirmation {
                Button("Cancel", role: .cancel) {
                    showPauseConfirmation = false
                }
                
                Button("Pause & Lose Life", role: .destructive) {
                    isRunning = false
                    loseLife(reason: "Paused timer")
                    showPauseConfirmation = false
                }
            }
        } message: {
            if showUnfocusedAlert {
                Text("You've been unfocused for 30+ seconds. Get back to work or lose a life!")
            } else if showPauseConfirmation {
                Text("Pausing will cost you a life. Are you sure?")
            }
        }
    }
    
    private var alertTitle: String {
        if showUnfocusedAlert {
            return "⚠️ LOCK IN!"
        } else if showPauseConfirmation {
            return "Pause Timer?"
        }
        return ""
    }

    private var totalSecondsForSession: Int {
        switch session {
        case .work: return workMinutes * 60
        case .breakTime: return breakMinutes * 60
        }
    }

    private var progress: Double {
        let total = Double(max(totalSecondsForSession, 1))
        let remaining = Double(secondsRemaining)
        return 1.0 - (remaining / total)
    }

    private func resetCurrentSession() {
        secondsRemaining = totalSecondsForSession
        secondsUnfocused = 0
    }

    private func switchSession() {
        session = (session == .work) ? .breakTime : .work
        resetCurrentSession()
        isRunning = true
    }

    private func handleSessionComplete() {
        if session == .work {
            // Completed a work session - gain a life!
            gainLife()
        }
        switchSession()
    }
    
    private func loseLife(reason: String) {
        if lives > 0 {
            lives -= 1
            print("Lost a life: \(reason). Lives remaining: \(lives)")
            
            if lives == 0 {
                lockoutApp()
            }
        }
    }
    
    private func gainLife() {
        if lives < 5 {
            lives += 1
            print("Gained a life! Lives: \(lives)")
        }
    }
    
    private func lockoutApp() {
        let today = Calendar.current.startOfDay(for: Date())
        lockoutDateString = ISO8601DateFormatter().string(from: today)
        isLockedOut = true
        isRunning = false
        print("App locked out for the day")
    }
    
    private func checkLockoutStatus() {
        guard !lockoutDateString.isEmpty else {
            isLockedOut = false
            return
        }
        
        if let lockoutDate = ISO8601DateFormatter().date(from: lockoutDateString) {
            let today = Calendar.current.startOfDay(for: Date())
            
            if lockoutDate < today {
                // It's a new day - reset
                lives = 5
                lockoutDateString = ""
                isLockedOut = false
                print("New day - lives reset to 5")
            } else {
                // Still locked out
                isLockedOut = true
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 600)
}
