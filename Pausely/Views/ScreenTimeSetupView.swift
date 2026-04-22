//
//  ScreenTimeSetupView.swift
//  Pausely
//
//  Guided setup flow for Screen Time subscription auto-detection
//

import SwiftUI
import FamilyControls

/// Guided setup view for Screen Time subscription auto-detection
/// Walks users through: Welcome -> Authorization -> App Selection -> Detection -> Complete
struct ScreenTimeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ScreenTimeSetupViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Content based on current step
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeStepView(onContinue: viewModel.nextStep)
                case .authorization:
                    AuthorizationStepView(viewModel: viewModel)
                case .appSelection:
                    AppSelectionStepView(viewModel: viewModel)
                case .detection:
                    DetectionStepView(viewModel: viewModel)
                case .complete:
                    CompleteStepView(viewModel: viewModel, onDismiss: { dismiss() })
                }

                // Navigation dots
                VStack {
                    Spacer()
                    StepIndicatorView(
                        currentStep: viewModel.currentStep.rawValue,
                        totalSteps: 5
                    )
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Usage Tracking Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            viewModel.checkCurrentStatus()
        }
    }
}

// MARK: - View Model

@MainActor
final class ScreenTimeSetupViewModel: ObservableObject {
    @Published var currentStep: SetupStep = .welcome
    @Published var isRequesting = false
    @Published var authorizationError: String?
    @Published var detectedSubscriptions: [DetectedSubscription] = []
    @Published var isDetecting = false
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var hasCompletedSetup = false

    private let familyControlsManager = ScreenTimeManager.shared
    private let detectionEngine = SubscriptionDetectionEngine.shared

    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case authorization = 1
        case appSelection = 2
        case detection = 3
        case complete = 4
    }

    func checkCurrentStatus() {
        if familyControlsManager.authorizationStatus == .authorized {
            // Already authorized, go to app selection
            if familyControlsManager.hasSelectedApps {
                currentStep = .complete
                hasCompletedSetup = true
            } else {
                currentStep = .appSelection
            }
        }
    }

    func nextStep() {
        guard let nextIndex = SetupStep.allCases.firstIndex(of: currentStep)?.advanced(by: 1),
              nextIndex < SetupStep.allCases.count else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = SetupStep.allCases[nextIndex]
        }
    }

    func previousStep() {
        guard let prevIndex = SetupStep.allCases.firstIndex(of: currentStep)?.advanced(by: -1),
              prevIndex >= 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = SetupStep.allCases[prevIndex]
        }
    }

    func requestAuthorization() {
        isRequesting = true
        authorizationError = nil

        Task {
            do {
                try await familyControlsManager.requestAuthorization()
                isRequesting = false
                nextStep()
            } catch {
                isRequesting = false
                authorizationError = error.localizedDescription
            }
        }
    }

    func saveAppSelection() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.pausely.app.shared")
        sharedDefaults?.set(true, forKey: "user_has_selected_apps")
        sharedDefaults?.set(selectedApps.applicationTokens.count, forKey: "user_selected_apps_count")

        // Notify that selection changed
        NotificationCenter.default.post(name: .appSelectionChanged, object: nil)

        // Proceed to detection
        nextStep()
    }

    func runDetection() {
        isDetecting = true

        Task {
            detectedSubscriptions = await detectionEngine.detectSubscriptions()
            isDetecting = false
            nextStep()
        }
    }

    func addSubscription(_ subscription: DetectedSubscription) async {
        await detectionEngine.addToTrackedSubscriptions(subscription)
    }

    func skipDetection() {
        nextStep()
    }
}

// MARK: - Step Indicator

struct StepIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.luxuryPurple : Color.gray.opacity(0.3))
                    .frame(width: step == currentStep ? 10 : 8, height: step == currentStep ? 10 : 8)
            }
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.luxuryPurple, .luxuryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                        .opacity(0.3 - Double(i) * 0.1)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.luxuryPurple, .luxuryPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }

            // Title
            Text("Smart Usage Tracking")
                .font(.title.bold())
                .foregroundColor(.white)

            // Description
            Text("Automatically detect your subscriptions by tracking how often you use apps. No manual entry needed.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "eye.fill", text: "Detects app usage patterns", color: .blue)
                FeatureRow(icon: "dollarsign.circle.fill", text: "Shows cost per hour of use", color: .green)
                FeatureRow(icon: "wand.and.stars", text: "Suggests subscriptions to review", color: .purple)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient.premium
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
    }
}

// MARK: - Authorization Step

struct AuthorizationStepView: View {
    @ObservedObject var viewModel: ScreenTimeSetupViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.shield.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
            }

            // Title
            Text("Enable Screen Time")
                .font(.title.bold())
                .foregroundColor(.white)

            // Description
            Text("Pausely needs Screen Time access to track which apps you use. Your data stays on your device.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Privacy note
            VStack(alignment: .leading, spacing: 12) {
                SetupPrivacyRow(icon: "lock.fill", text: "All data stays on your device")
                SetupPrivacyRow(icon: "eye.slash.fill", text: "We never see your activity")
                SetupPrivacyRow(icon: "xmark.circle.fill", text: "Stop tracking anytime")
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            // Error message
            if let error = viewModel.authorizationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: viewModel.requestAuthorization) {
                    HStack {
                        if viewModel.isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                        }
                        Text("Enable Screen Time")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.blue)
                    .cornerRadius(16)
                }
                .disabled(viewModel.isRequesting)
                .accessibilityHint(viewModel.isRequesting ? "Please wait, requesting authorization" : "")

                Button(action: viewModel.skipDetection) {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
}

struct SetupPrivacyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()
        }
    }
}

// MARK: - App Selection Step

struct AppSelectionStepView: View {
    @ObservedObject var viewModel: ScreenTimeSetupViewModel
    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Select Apps to Track")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Choose which subscription apps you want to monitor. You can change this later.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 20)

            // Info banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("Note: Apple Screen Time API provides session counts, not exact minutes. Usage shown is estimated based on session frequency.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 24)

            // App count
            if viewModel.selectedApps.applicationTokens.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "apps.iphone")
                        .font(.largeTitle)
                        .foregroundColor(.gray)

                    Text("No apps selected")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Button(action: { showingPicker = true }) {
                        Text("Select Apps")
                            .font(.headline)
                            .foregroundColor(.luxuryPurple)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Text("\(viewModel.selectedApps.applicationTokens.count) apps selected")
                        .font(.headline)
                        .foregroundColor(.white)

                    Button(action: { showingPicker = true }) {
                        Text("Change Selection")
                            .font(.subheadline)
                            .foregroundColor(.luxuryPurple)
                    }
                }
                .frame(maxHeight: .infinity)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(action: viewModel.saveAppSelection) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient.premium
                        )
                        .cornerRadius(16)
                }

                Button(action: viewModel.skipDetection) {
                    Text("Track All Known Apps")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .sheet(isPresented: $showingPicker) {
            FamilyActivityPickerWrapper(
                selection: $viewModel.selectedApps,
                onDismiss: {
                    showingPicker = false
                }
            )
        }
    }
}

// MARK: - Detection Step

struct DetectionStepView: View {
    @ObservedObject var viewModel: ScreenTimeSetupViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if viewModel.isDetecting {
                // Loading state
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color.luxuryPurple.opacity(0.3), lineWidth: 2)
                            .frame(width: 80 + CGFloat(i * 30), height: 80 + CGFloat(i * 30))
                            .scaleEffect(viewModel.isDetecting ? 1.2 : 1.0)
                            .animation(
                                UIAccessibility.isReduceMotionEnabled
                                    ? .none
                                    : Animation.easeInOut(duration: 1.0)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.3),
                                value: viewModel.isDetecting
                            )
                    }

                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.luxuryPurple)
                }

                Text("Analyzing your app usage...")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text("This takes a few seconds")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                // Results
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)

                Text("Detection Complete!")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                if viewModel.detectedSubscriptions.isEmpty {
                    Text("No new subscriptions detected.\nWe'll keep tracking your usage.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                } else {
                    Text("\(viewModel.detectedSubscriptions.count) potential subscriptions found")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Continue button
            Button(action: viewModel.skipDetection) {
                Text(viewModel.isDetecting ? "Please wait..." : "Continue")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient.premium
                    )
                    .cornerRadius(16)
            }
            .disabled(viewModel.isDetecting)
            .accessibilityHint(viewModel.isDetecting ? "Please wait, detection in progress" : "")
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
        .onAppear {
            if !viewModel.isDetecting && viewModel.detectedSubscriptions.isEmpty {
                viewModel.runDetection()
            }
        }
    }
}

// MARK: - Complete Step

struct CompleteStepView: View {
    @ObservedObject var viewModel: ScreenTimeSetupViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
            }

            // Title
            Text("You're All Set!")
                .font(.title.bold())
                .foregroundColor(.white)

            // Description
            Text("Usage tracking is now active. We'll monitor your app usage and suggest subscriptions we detect.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Detected subscriptions
            if !viewModel.detectedSubscriptions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Detected Subscriptions")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)

                    ForEach(viewModel.detectedSubscriptions.prefix(5)) { subscription in
                        DetectedSubscriptionRow(
                            subscription: subscription,
                            onAdd: {
                                Task {
                                    await viewModel.addSubscription(subscription)
                                }
                            }
                        )
                    }
                }
                .padding(.top, 20)
            }

            Spacer()

            // Done button
            Button(action: onDismiss) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient.premium
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
}

// MARK: - Detected Subscription Row

struct DetectedSubscriptionRow: View {
    let subscription: DetectedSubscription
    let onAdd: () -> Void
    @State private var isAdded = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: subscription.iconName)
                .font(.title2)
                .foregroundColor(.luxuryPurple)
                .frame(width: 44, height: 44)
                .background(Color.luxuryPurple.opacity(0.2))
                .cornerRadius(10)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Text("\(subscription.weeklySessions) sessions/week • \(subscription.confidencePercent)% confidence")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Add button
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button(action: {
                    onAdd()
                    isAdded = true
                }) {
                    Text("Add")
                        .font(.caption.bold())
                        .foregroundColor(.luxuryPurple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.luxuryPurple.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    ScreenTimeSetupView()
}
