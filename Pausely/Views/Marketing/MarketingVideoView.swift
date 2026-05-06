//
//  MarketingVideoView.swift
//  Pausely
//
//  Marketing video scene player for Instagram Reels
//  Screen-record this view and post directly
//

import SwiftUI

// MARK: - Scene Definition
enum MVScene: CaseIterable {
    case hook
    case problem
    case dashboard
    case features
    case outro

    var duration: Double {
        switch self {
        case .hook:      return 15.0
        case .problem:   return 4.0
        case .dashboard: return 4.0
        case .features:  return 4.0
        case .outro:     return 4.0
        }
    }

    var backgroundColor: Color {
        Color(hex: "0A0A14")
    }
}

// MARK: - Main Orchestrator
struct MarketingVideoView: View {
    @State private var currentSceneIndex: Int = 0
    @State private var activeScene: MVScene = .hook
    @State private var isPlaying = false

    private let allScenes = MVScene.allCases

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(allScenes.enumerated()), id: \.offset) { index, scene in
                    sceneView(scene: scene, isActive: activeScene == scene)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(y: CGFloat(index - currentSceneIndex) * geo.size.height)
                        .opacity(abs(index - currentSceneIndex) <= 1 ? 1 : 0)
                }
            }
        }
        .onAppear(perform: start)
    }

    @ViewBuilder
    private func sceneView(scene: MVScene, isActive: Bool) -> some View {
        switch scene {
        case .hook:
            MVIntroScene(isActive: isActive)
        case .problem:
            MVProblemScene(isActive: isActive)
        case .dashboard:
            MVDashboardScene(isActive: isActive)
        case .features:
            MVFeaturesScene(isActive: isActive)
        case .outro:
            MVOutroScene(isActive: isActive)
        }
    }

    private func start() {
        isPlaying = true
        currentSceneIndex = 0
        activeScene = .hook
        scheduleNextScene()
    }

    private func scheduleNextScene() {
        guard isPlaying else { return }

        let currentDuration = allScenes[currentSceneIndex].duration
        DispatchQueue.main.asyncAfter(deadline: .now() + currentDuration) {
            guard isPlaying else { return }

            if currentSceneIndex < allScenes.count - 1 {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    currentSceneIndex += 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    activeScene = allScenes[currentSceneIndex]
                }
                scheduleNextScene()
            } else {
                isPlaying = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MarketingVideoView()
}
