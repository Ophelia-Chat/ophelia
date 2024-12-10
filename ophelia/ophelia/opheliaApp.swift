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
    init() {
        setupAppearance()
        setupDebugging()
    }
    
    var body: some Scene {
        WindowGroup {
            ChatView()
                .preferredColorScheme(.light)  // Force light mode for now
                .tint(.blue)                   // Set app tint color
        }
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
        // Suppress common warnings
        UserDefaults.standard.setValue(false, forKey: "UIKeyboardLayoutStar_wantsWKWebView")
        #endif
    }
    
    func setupAppearance() {
        // Navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        
        // Add slight blur effect
        navigationBarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        
        // Configure navigation items appearance
        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        navigationBarAppearance.buttonAppearance = buttonAppearance
        
        // Apply navigation appearance
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        
        // Toolbar appearance
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithDefaultBackground()
        toolbarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        
        // Apply toolbar appearance
        UIToolbar.appearance().standardAppearance = toolbarAppearance
        UIToolbar.appearance().compactAppearance = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance
        
        // General UI appearance
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = .systemBlue
        
        // Keyboard appearance
        UITextField.appearance().tintColor = .systemBlue
        
        #if !targetEnvironment(macCatalyst)
        // Additional iOS-specific appearance settings
        if #available(iOS 15.0, *) {
            // Add any iOS 15+ specific appearances here
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
