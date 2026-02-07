//
//  ContentView.swift
//  StudySessionApp
//
//  Created by Max Finch on 2/6/26.
//

import SwiftUI
import Combine

final class FocusService: ObservableObject {
    @Published var focused: Bool = true

    private var timer: AnyCancellable?
    private let url: URL

    init(urlString: String) {
        self.url = URL(string: urlString)!
    }

    func startPolling(every seconds: TimeInterval = 0.5) {
        stopPolling()
        timer = Timer.publish(every: seconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetch()
            }
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
    }

    private func fetch() {
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2)
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data else { return }

            var newValue: Bool? = nil

            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let b = obj["focused"] as? Bool {
                    newValue = b
                } else if let i = obj["focused"] as? Int {
                    newValue = (i != 0)
                } else if let s = obj["focused"] as? String {
                    let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    newValue = (lower == "true" || lower == "1" || lower == "yes" || lower == "y")
                }
            }

            DispatchQueue.main.async {
                // If we can't decode or connect, treat as not focused so the UI clearly shows the failure.
                self.focused = newValue ?? false
            }
            return
        }.resume()
    }
}

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

    // Unfocused warning
    @State private var showLockInAlert: Bool = false
    @State private var unfocusedWorkItem: DispatchWorkItem?

    // Local focus status from Python server
    @StateObject private var focusService = FocusService(urlString: "http://127.0.0.1:5000/focus")

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Image("study table")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Study Session")
                    .font(.title)
                    .bold()
                    .padding(.vertical, 10)

                Text(session.rawValue)
                    .font(.headline)

                Text(formatTime(secondsRemaining))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))

                HStack(spacing: 8) {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(focusService.focused ? .green : .red)
                    Text(focusService.focused ? "Focused" : "Not Focused")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

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
            .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.5)))
            .padding(24)
            .frame(minWidth: 420, minHeight: 360)
        }
        .onAppear {
            workMinutesText = String(workMinutes)
            breakMinutesText = String(breakMinutes)
            resetCurrentSession()
            focusService.startPolling()
        }
        .onChange(of: focusService.focused) { _, newValue in
            if newValue == false {
                // Stop the timer immediately when unfocused.
                isRunning = false

                // Cancel any pending warning and schedule a new one.
                unfocusedWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    // Only show if still unfocused after 10 seconds.
                    if focusService.focused == false {
                        showLockInAlert = true
                    }
                }
                unfocusedWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
            } else {
                // Focus returned: cancel pending warning and dismiss alert if showing.
                unfocusedWorkItem?.cancel()
                unfocusedWorkItem = nil
                showLockInAlert = false
            }
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
            guard isRunning && focusService.focused else { return }

            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                switchSession()
            }
        }
        .alert("LOCK IN!!", isPresented: $showLockInAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You’ve been unfocused for 10 seconds. Get back on it.")
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
