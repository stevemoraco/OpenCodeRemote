import SwiftUI

struct SettingsView: View {
    @AppStorage("DirectServerURL") private var serverURL = "http://localhost:5173"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("OpenCode Server") {
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Enter the URL of your OpenCode server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}