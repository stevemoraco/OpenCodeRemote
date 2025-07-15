import SwiftUI

struct SettingsView: View {
    @ObservedObject var connectionManager: HybridConnectionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var connectionMode: ConnectionMode = .auto
    @State private var serverURL = ""
    @State private var relayURL = ""
    @State private var roomCode = ""
    @State private var showRelayURLField = false
    
    enum ConnectionMode: String, CaseIterable {
        case auto = "Automatic"
        case direct = "Direct Connection"
        case relay = "Relay Connection"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Connection Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(UIColor.systemBackground))
            #endif
            
            Divider()
            
            // Settings content
            Form {
                Section("Connection Mode") {
                    Picker("Mode", selection: $connectionMode) {
                        ForEach(ConnectionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("Automatic mode will try direct connection first, then fall back to relay if needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Direct Connection") {
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                    
                    Button("Test Direct Connection") {
                        connectionManager.disconnect()
                        connectionManager.connectDirect(urlString: serverURL)
                    }
                    .disabled(serverURL.isEmpty)
                }
                
                Section("Relay Connection") {
                    // Relay URL configuration
                    HStack {
                        if showRelayURLField {
                            TextField("Relay URL", text: $relayURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                #if os(iOS)
                                .autocapitalization(.none)
                                #endif
                                .disableAutocorrection(true)
                            
                            Button("Save") {
                                connectionManager.updateRelayURL(relayURL)
                                showRelayURLField = false
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("Relay Server: \(connectionManager.getCurrentRelayURL())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Button("Edit") {
                                relayURL = connectionManager.getCurrentRelayURL()
                                showRelayURLField = true
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                        }
                    }
                    
                    #if os(macOS)
                    Button("Start Relay Server") {
                        connectionManager.disconnect()
                        connectionManager.startRelayServer()
                    }
                    
                    if let code = connectionManager.roomCode {
                        VStack(spacing: 5) {
                            Text("Room Code:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(code)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .monospaced()
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    #else
                    TextField("Room Code (e.g. ABCD-1234)", text: $roomCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .autocapitalization(.allCharacters)
                        #endif
                        .disableAutocorrection(true)
                    
                    Button("Join Room") {
                        connectionManager.disconnect()
                        connectionManager.joinRelayRoom(code: roomCode)
                    }
                    .disabled(roomCode.isEmpty)
                    #endif
                }
                
                Section("Current Status") {
                    HStack {
                        Text("Connection:")
                        Spacer()
                        Text(connectionManager.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(connectionManager.isConnected ? .green : .red)
                    }
                    
                    if connectionManager.isConnected {
                        HStack {
                            Text("Mode:")
                            Spacer()
                            Text(connectionManager.connectionMode == .direct ? "Direct" : "Relay")
                        }
                        
                        if let url = connectionManager.serverURL {
                            HStack {
                                Text("Server:")
                                Spacer()
                                Text(url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if connectionManager.isConnected {
                        Button("Disconnect") {
                            connectionManager.disconnect()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 600)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.systemBackground))
        #endif
        .onAppear {
            // Load saved settings
            serverURL = UserDefaults.standard.string(forKey: "DirectServerURL") ?? "http://localhost:5173"
            relayURL = connectionManager.getCurrentRelayURL()
            
            // Determine current mode
            if connectionManager.connectionMode == .direct {
                connectionMode = .direct
            } else if connectionManager.connectionMode == .relay {
                connectionMode = .relay
            } else {
                connectionMode = .auto
            }
        }
    }
}

#Preview {
    SettingsView(connectionManager: HybridConnectionManager())
}