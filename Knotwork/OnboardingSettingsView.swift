import SwiftUI

// MARK: - OnboardingView
// First-launch screen. User enters server URL + API key (not a password).
// The API key is created via the dashboard Settings → API Keys page.

struct OnboardingView: View {
    @ObservedObject var store: TodoStore

    @State private var serverURL = ""
    @State private var apiKey    = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Logo ────────────────────────────────────────────
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.rectangle.stack.fill")
                            .font(.system(size: 64))
                        Text("TO DO LIST")
                            .font(.largeTitle.bold())
                        Text("Connect to your Kaslo dashboard")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // ── Form card ────────────────────────────────────────
                    VStack(spacing: 0) {
                        FieldRow(label: "Server URL", placeholder: "https://knotwork.ca") {
                            TextField("https://knotwork.ca", text: $serverURL)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        Divider().padding(.leading, 16)
                        FieldRow(label: "API Key", placeholder: "kw_…") {
                            SecureField("kw_…", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)

                    // ── How to get a key ─────────────────────────────────
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("How to get an API key", systemImage: "key.fill")
                                .font(.footnote.weight(.semibold))
                            Text("1. Open the dashboard in a browser and log in.\n2. Go to Settings → API Keys.\n3. Tap \"New Key\", enter a device name, and copy the key shown.\n4. The key is shown once — paste it here immediately.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    // ── Error ────────────────────────────────────────────
                    if let err = errorMsg {
                        Text(err)
                            .font(.footnote).foregroundStyle(.red)
                            .padding(.horizontal, 24).multilineTextAlignment(.center)
                    }

                    // ── Connect button ───────────────────────────────────
                    Button {
                        Task { await connect() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView().tint(.white) }
                            Text(isLoading ? "Verifying…" : "Connect")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canConnect ? Color.black : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canConnect || isLoading)
                    .padding(.horizontal, 20)

                    Text("Your API key is stored securely in the iOS Keychain.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 28)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var canConnect: Bool { !serverURL.isEmpty && apiKey.hasPrefix("kw_") }

    private func connect() async {
        isLoading = true
        errorMsg = nil
        
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespaces)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        
        do {
            try await store.configure(serverURL: trimmedURL, apiKey: trimmedKey)
        } catch {
            errorMsg = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var store: TodoStore
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirm = false
    @State private var showRotateKey     = false
    @State private var newKey            = ""
    @State private var rotateError: String?
    @State private var rotateSuccess     = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    LabeledContent("URL", value: store.serverURL)
                    LabeledContent("API Key") {
                        Text("kw_" + String(store.apiKey.dropFirst(3).prefix(6)) + "…")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Replace API Key") {
                    Text("To rotate your key, create a new one in the dashboard (Settings → API Keys), paste it below, then tap Save.")
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField("kw_…", text: $newKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                    Button("Save New Key") {
                        Task { await saveNewKey() }
                    }
                    .disabled(!newKey.hasPrefix("kw_") || newKey.count < 10)
                    if let err = rotateError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                    if rotateSuccess {
                        Text("✓ Key updated").font(.caption).foregroundStyle(.green)
                    }
                }

                Section {
                    Button("Disconnect & Log Out", role: .destructive) {
                        showLogoutConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Disconnect?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive) { store.logout(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the saved API key from this device.")
            }
        }
    }

    private func saveNewKey() async {
        rotateError = nil; rotateSuccess = false
        let trimmed = newKey.trimmingCharacters(in: .whitespaces)
        do {
            // Verify new key works before saving
            _ = try await APIClient.fetchTodos(serverURL: store.serverURL, apiKey: trimmed)
            store.apiKey = trimmed
            newKey = ""
            rotateSuccess = true
        } catch {
            rotateError = error.localizedDescription
        }
    }
}

// MARK: - Shared form row

struct FieldRow<Content: View>: View {
    let label: String
    let placeholder: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(.subheadline.weight(.medium)).frame(width: 80, alignment: .leading)
            content.font(.subheadline)
        }
        .padding(14)
    }
}
