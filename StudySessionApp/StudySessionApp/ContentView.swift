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

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            Text("Study Session")
                .font(.title)
                .bold()

            Text(session.rawValue)
                .font(.headline)

            Text(formatTime(secondsRemaining))
                .font(.system(size: 48, weight: .bold, design: .monospaced))

            ProgressView(value: progress)
                .frame(width: 320)

            HStack(spacing: 12) {
                Button(isRunning ? "Pause" : "Start") {
                    isRunning.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Reset") {
                    resetCurrentSession()
                    isRunning = false
                }

                Button("Skip") {
                    switchSession()
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
        .padding(24)
        .frame(minWidth: 420, minHeight: 360)
        .onAppear {
            workMinutesText = String(workMinutes)
            breakMinutesText = String(breakMinutes)
            resetCurrentSession()
        }
        .onChange(of: workMinutes) { _, newValue in
            // Keep the text field synced to stepper changes
            let s = String(newValue)
            if workMinutesText != s { workMinutesText = s }

            if !isRunning && session == .work { resetCurrentSession() }
        }
        .onChange(of: breakMinutes) { _, newValue in
            // Keep the text field synced to stepper changes
            let s = String(newValue)
            if breakMinutesText != s { breakMinutesText = s }

            if !isRunning && session == .breakTime { resetCurrentSession() }
        }
        .onReceive(tick) { _ in
            guard isRunning else { return }

            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                switchSession()
            }
        }
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
    }

    private func switchSession() {
        session = (session == .work) ? .breakTime : .work
        resetCurrentSession()
        isRunning = true
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    ContentView()
}
