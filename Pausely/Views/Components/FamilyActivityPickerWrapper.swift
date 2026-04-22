//
//  FamilyActivityPickerWrapper.swift
//  Pausely
//
//  SwiftUI wrapper for FamilyActivityPicker (UIKit only)
//

import SwiftUI
import FamilyControls
import UIKit

/// SwiftUI wrapper for FamilyActivityPicker
/// Since FamilyActivityPicker is UIKit-only, we wrap it in UIViewControllerRepresentable
struct FamilyActivityPickerWrapper: UIViewControllerRepresentable {
    @Binding var selection: FamilyActivitySelection
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = FamilyActivityPicker(selection: $selection)
        let hostingController = UIHostingController(rootView: picker)

        let nav = UINavigationController(rootViewController: hostingController)

        // Add close button
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: context.coordinator,
            action: #selector(Coordinator.dismissPicker)
        )
        if #available(iOS 16.0, *) {
            hostingController.navigationItem.leadingItemGroups = [
                UIBarButtonItemGroup(barButtonItems: [closeButton], representativeItem: nil)
            ]
        } else {
            hostingController.navigationItem.leftBarButtonItem = closeButton
        }

        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // Updates handled via binding
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    @MainActor
    final class Coordinator: NSObject, ObservableObject {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        @objc func dismissPicker() {
            onDismiss()
        }
    }
}
