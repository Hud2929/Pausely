//
//  CancellationFlowView.swift
//  Pausely
//
//  4-Step Cancellation Concierge
//

import SwiftUI
import SafariServices
import MessageUI


// MARK: - Supporting Types
enum CancellationMethod {
    case website
    case email
    case phone
    case inApp
}

struct CancellationEmail {
    let to: String
    let subject: String
    let body: String
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

