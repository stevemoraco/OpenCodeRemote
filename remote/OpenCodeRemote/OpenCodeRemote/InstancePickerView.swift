import SwiftUI

struct InstancePickerView: View {
    @ObservedObject var connectionManager: HybridConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var manualURL = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Discovered Instances") {
                    if connectionManager.discoveredInstances.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Scanning for OpenCode instances...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(connectionManager.discoveredInstances, id: \.port) { instance in
                            Button(action: {
                                Task {
                                    await connectionManager.connectToInstance(instance)
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Port \(instance.port)")
                                            .font(.headline)
                                        Text(instance.url)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if instance.pid > 0 {
                                        Text("PID: \(instance.pid)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section("Manual Connection") {
                    HStack {
                        TextField("http://localhost:5173", text: $manualURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disableAutocorrection(true)
                        
                        Button("Connect") {
                            Task {
                                connectionManager.baseURL = manualURL.isEmpty ? "http://localhost:5173" : manualURL
                                await connectionManager.connect()
                                dismiss()
                            }
                        }
                        .disabled(manualURL.isEmpty)
                    }
                }
                
                Section {
                    Button("Refresh") {
                        Task {
                            await connectionManager.discoverInstances()
                        }
                    }
                }
            }
            .navigationTitle("OpenCode Instances")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}