//
//  opheliaApp.swift
//  ophelia
//
//  Created by rob on 2024-11-27.
//

import SwiftUI
import UIKit

@main
struct opheliaApp: App {
    @StateObject private var appInitializer = AppInitializer()
    @StateObject private var appSettings = AppSettings()  // Must contain `themeMode`

    init() {
        setupAppearance()
        setupDebugging()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appInitializer.isInitialized {
                    ChatView()
                        .tint(.blue)
                        // Provide `appSettings` to all child views
                        .environmentObject(appSettings)
                        // 1) When this screen appears, apply the chosen theme
                        .onAppear {
                            applyGlobalAppearance(for: appSettings.themeMode)
                        }
                        // 2) If user changes theme mode in Settings, re-apply
                        .onChange(of: appSettings.themeMode) { _, newValue in
                            applyGlobalAppearance(for: newValue)
                        }

                } else {
                    // A lightweight loading view shown until initialization finishes
                    ProgressView("Loading...")
                        .task {
                            await appInitializer.initialize()
                        }
                }
            }
        }
    }
}

// MARK: - Background Initializer
@MainActor
final class AppInitializer: ObservableObject {
    @Published var isInitialized = false

    func initialize() async {
        await Task(priority: .background) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            // Potentially load app settings or do other setup here.
        }.value

        isInitialized = true
    }
}

// MARK: - Setup Extensions
private extension opheliaApp {

    /// Toggles debug/experimental features if needed
    func setupDebugging() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: "UIViewLayoutConstraintEnableLog")
        setenv("CG_NUMERICS_SHOW_BACKTRACE", "1", 1)
        UserDefaults.standard.setValue(false, forKey: "UIKeyboardLayoutStar_wantsWKWebView")
        #endif
    }

    /// Applies a “base” UI appearance to nav bars, toolbars, tab bars, etc.
    func setupAppearance() {
        // MARK: Navigation Bar Appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor.systemBackground
        navigationBarAppearance.backgroundEffect = nil
        navigationBarAppearance.shadowColor = .clear

        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        navigationBarAppearance.buttonAppearance = buttonAppearance

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navigationBarAppearance

        // MARK: Toolbar Appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        // For a “true black” effect in dark mode, you could switch to .black or .systemBackground
        toolbarAppearance.backgroundColor = UIColor.systemGroupedBackground
        toolbarAppearance.backgroundEffect = nil
        toolbarAppearance.shadowColor = .clear

        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance

        // MARK: General UI Appearance
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .systemBlue
        UITextField.appearance().tintColor = .systemBlue

        // MARK: Tab Bar Appearance (iOS 15+)
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 15.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemGroupedBackground
            tabBarAppearance.backgroundEffect = nil
            tabBarAppearance.shadowColor = .clear

            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        #endif
    }

    /// Override iOS’s interface style if user sets `.light` or `.dark`;
    /// use `.unspecified` to respect the system’s current theme if `.system`.
    func applyGlobalAppearance(for themeMode: ThemeMode) {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    switch themeMode {
                    case .system:
                        // “Unspecified” means we do NOT override iOS’s normal behavior
                        window.overrideUserInterfaceStyle = .unspecified
                    case .light:
                        window.overrideUserInterfaceStyle = .light
                    case .dark:
                        window.overrideUserInterfaceStyle = .dark
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ChatView()
}
