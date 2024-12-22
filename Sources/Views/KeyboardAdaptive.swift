import SwiftUI
import Combine

struct KeyboardAdaptive: ViewModifier {
    @State private var currentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                // Apply bottom padding equal to the computed keyboard offset
                .padding(.bottom, currentHeight)
                // Animate layout changes for a smoother transition
                .animation(.easeOut(duration: 0.25), value: currentHeight)
                // Listen for keyboard changes
                .onReceive(Publishers.keyboardHeightChange) { newHeight in
                    // Add a small delay so SwiftUI finishes layout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        // Subtract the bottom safe-area from the raw keyboard height
                        // to avoid a too-big offset if SwiftUI is already accounting for that space.
                        let safeBottom = geometry.safeAreaInsets.bottom
                        let adjusted = max(newHeight - safeBottom, 0)
                        currentHeight = adjusted
                    }
                }
        }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}

// MARK: - KeyboardHeight Publisher
extension Publishers {
    /// Publishes keyboard height changes based on `keyboardWillChangeFrameNotification` (and hides on `keyboardWillHideNotification`).
    static var keyboardHeightChange: AnyPublisher<CGFloat, Never> {
        let keyboardFrameChanges = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { notification -> CGRect? in
                notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            }
            .map(\.height)

        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        // Merge them, so we get a single stream:
        // - The new keyboard frame height whenever it changes
        // - 0 when the keyboard hides
        return keyboardFrameChanges
            .merge(with: willHide)
            .eraseToAnyPublisher()
    }
}
