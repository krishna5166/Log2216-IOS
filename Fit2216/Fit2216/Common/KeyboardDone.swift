import SwiftUI
import UIKit

extension View {
    /// A Done button above the keyboard. Number keypads have no return key, so without it there is no way to close them.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
    }
}
