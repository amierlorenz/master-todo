import SwiftUI
import TodoKit

/// Canvas address and access token. The token goes straight to the Keychain and is never shown again.
struct CanvasAccountSection: View {
    @Environment(SyncService.self) private var sync
    @AppStorage(CanvasConnection.baseURLKey) private var baseURL = ""
    @State private var address = ""
    @State private var token = ""
    @State private var message: String?

    private var normalizedAddress: URL? {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), url.scheme == "https", url.host() != nil else { return nil }
        return url
    }

    var body: some View {
        Section {
            TextField("Canvas address", text: $address, prompt: Text("school.instructure.com"))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            SecureField(sync.hasCanvasAccount ? "Replace access token" : "Access token", text: $token)
            Button("Save", action: save)
                .disabled(normalizedAddress == nil || (token.isEmpty && !sync.hasCanvasAccount))
            if sync.hasCanvasAccount {
                Button("Remove token", role: .destructive, action: removeToken)
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Canvas")
        } footer: {
            Text("Create a token in Canvas under Account → Settings → New Access Token. It's stored in your iCloud Keychain.")
        }
        .onAppear { address = baseURL }
    }

    private func save() {
        guard let url = normalizedAddress else { return }
        do {
            if !token.isEmpty { try KeychainStore.canvasToken.save(token) }
            baseURL = url.absoluteString
            address = baseURL
            token = ""
            message = "Saved."
            sync.accountChanged()
            Task { await sync.refreshCourses() }
        } catch {
            message = "Couldn't save the token to the Keychain."
        }
    }

    private func removeToken() {
        try? KeychainStore.canvasToken.delete()
        message = "Token removed."
        sync.accountChanged()
    }
}
