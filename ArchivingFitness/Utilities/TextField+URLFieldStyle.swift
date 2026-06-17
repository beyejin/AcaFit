import SwiftUI

extension TextField {
    @ViewBuilder
    func urlFieldStyle() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
#else
        self
            .autocorrectionDisabled()
#endif
    }
}
