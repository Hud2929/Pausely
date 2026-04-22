//
//  AppSelectionView.swift
//  Pausely
//
//  Lets users select which apps to track via Screen Time
//

import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AppSelectionViewModel
    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: AppSelectionViewModel(onComplete: onComplete))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "apps.iphone")
                            .font(.largeTitle)
                            .foregroundColor(.mint)

                        Text("Select Apps to Track")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text("Choose which subscription apps you want to monitor with Screen Time. You can change this later.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Info banner
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)

                        Text("Screen Time tracks when you open apps, not the exact minutes. You'll see estimated usage based on session frequency.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .padding(.horizontal)

                    // FamilyActivityPicker
                    FamilyActivityPickerWrapper(
                        selection: $viewModel.selection,
                        onDismiss: {
                            // User dismissed without explicit save
                        }
                    )
                    .frame(height: 400)
                    .cornerRadius(16)
                    .padding(.horizontal)

                    Spacer()

                    // Continue button
                    Button {
                        viewModel.saveSelection()
                        dismiss()
                        onComplete()
                    } label: {
                        HStack {
                            if viewModel.selection.applicationTokens.isEmpty {
                                Text("Skip - Track Later")
                                    .font(.headline)
                            } else {
                                Text("Track \(viewModel.selection.applicationTokens.count) Apps")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.mint)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("App Selection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

@MainActor
final class AppSelectionViewModel: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        loadSavedSelection()
    }

    private func loadSavedSelection() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.pausely.app.shared")
        if let data = sharedDefaults?.data(forKey: "user_app_selection"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
    }

    func saveSelection() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.pausely.app.shared")

        // Store that apps have been selected (FamilyActivitySelection isn't directly serializable)
        // The selection is used with DeviceActivityCenter.startMonitoring() directly
        sharedDefaults?.set(true, forKey: "user_has_selected_apps")
        sharedDefaults?.set(selection.applicationTokens.count, forKey: "user_selected_apps_count")

        // Notify extension
        NotificationCenter.default.post(name: .appSelectionChanged, object: nil)

        // Update ScreenTimeManager
        Task {
            await ScreenTimeManager.shared.refreshFromExtension()
        }
    }
}

extension Notification.Name {
    static let appSelectionChanged = Notification.Name("appSelectionChanged")
}
