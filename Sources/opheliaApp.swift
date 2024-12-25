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

    init() {
        // Appearance changes are lightweight and can remain here
        setupAppearance()
        setupDebugging()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appInitializer.isInitialized {
                    // The main view of your app, now displayed after initialization is complete
                    ChatView()
                        .tint(.blue)
                        // .preferredColorScheme(.light)
                } else {
                    // A lightweight loading view shown until the app finishes background setup
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
/// Handles background initialization of expensive resources or services without blocking the main thread.
@MainActor
final class AppInitializer: ObservableObject {
    @Published var isInitialized = false

    func initialize() async {
        // Perform non-UI tasks in a background priority to prevent blocking the main thread.
        // Example tasks:
        // - Pre-warm network requests or caches
        // - Load large configuration files
        // - Initialize services that do not need to block the UI

        await Task(priority: .background) {
            // Simulate a small delay to represent fetching/initializing resources
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Here you might load AppSettings from disk or initialize services.
            // For example:
            // await ServiceManager.shared.initialize()
            // or load cached messages/settings:
            // await AppDataLoader.shared.loadData()
        }.value

        // Once everything is ready, update the UI
        isInitialized = true
    }
}

// MARK: - Setup Extensions
private extension opheliaApp {
    func setupDebugging() {
        #if DEBUG
        // Enable debugging for layout issues
        UserDefaults.standard.set(true, forKey: "UIViewLayoutConstraintEnableLog")
        // Enable backtrace for numeric errors
        setenv("CG_NUMERICS_SHOW_BACKTRACE", "1", 1)
        // Suppress common warnings or workaround environment issues if needed
        UserDefaults.standard.setValue(false, forKey: "UIKeyboardLayoutStar_wantsWKWebView")
        #endif
    }

    func setupAppearance() {
        // MARK: Navigation Bar Appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = UIColor.systemGroupedBackground
        navigationBarAppearance.backgroundEffect = nil   // remove any blur
        navigationBarAppearance.shadowColor = .clear     // removes bottom hairline

        // Customize button text color if desired
        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        navigationBarAppearance.buttonAppearance = buttonAppearance

        // Also use the same for scroll edge (large titles) and compact appearances
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navigationBarAppearance

        // MARK: Toolbar Appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = UIColor.systemGroupedBackground
        toolbarAppearance.backgroundEffect = nil  // remove any blur
        toolbarAppearance.shadowColor = .clear    // removes bottom hairline

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
}

// MARK: - Preview
#Preview {
    ChatView()
}
