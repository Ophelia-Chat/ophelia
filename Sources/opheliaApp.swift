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
                        //.preferredColorScheme(.light)
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
        // Navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        navigationBarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)

        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        navigationBarAppearance.buttonAppearance = buttonAppearance

        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance

        // Toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithDefaultBackground()
        toolbarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)

        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance

        // General UI appearance
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .systemBlue

        // Keyboard appearance
        UITextField.appearance().tintColor = .systemBlue

        #if !targetEnvironment(macCatalyst)
        if #available(iOS 15.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            UITabBar.appearance().standardAppearance = tabBarAppearance
        }
        #endif
    }
}

// MARK: - Preview
#Preview {
    ChatView()
}
