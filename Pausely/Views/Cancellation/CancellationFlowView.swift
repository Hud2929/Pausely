//
//  CancellationFlowView.swift
//  Pausely
//
//  4-Step Cancellation Concierge
//

import SwiftUI
import SafariServices
import MessageUI


// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

