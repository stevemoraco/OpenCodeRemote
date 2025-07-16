import SwiftUI

struct ContentView: View {
    @StateObject private var connectionManager = HybridConnectionManager()
    @State private var selectedInstance: OpenCodeInstance?
    @State private var isDiscovering = false
    @State private var discoveredInstances: [OpenCodeInstance] = []
    @State private var manualPort = "51330"
    @State private var showManualConnect = false
    
    var body: some View {
        VStack {
            if connectionManager.isConnected {
                // Use the new comprehensive connected view
                ConnectedView(connectionManager: connectionManager)
            } else {
                // Not connected view
                VStack(spacing: 20) {
                    Text("OpenCode Remote")
                        .font(.largeTitle)
                        .padding()
                    
                    if isDiscovering {
                        ProgressView("Discovering OpenCode instances...")
                            .padding()
                    } else if !discoveredInstances.isEmpty {
                        VStack {
                            Text("Found \(discoveredInstances.count) instance(s)")
                                .font(.headline)
                            ForEach(discoveredInstances, id: \.port) { instance in
                                Button(action: {
                                    Task {
                                        connectionManager.baseURL = instance.url
                                        await connectionManager.connect()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "server.rack")
                                        Text("Port \(instance.port)")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    } else {
                        Text("No OpenCode instances found")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    HStack {
                        Button("Scan for Instances") {
                            Task {
                                await discoverInstances()
                            }
                        }
                        .disabled(isDiscovering)
                        
                        Button("Manual Connect") {
                            showManualConnect.toggle()
                        }
                    }
                    .padding()
                    
                    if showManualConnect {
                        HStack {
                            Text("Port:")
                            TextField("Port", text: $manualPort)
                                .frame(width: 100)
                            Button("Connect") {
                                if let port = Int(manualPort) {
                                    Task {
                                        await connectToPort(port)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .task {
            // Try to connect to the default port first
            await connectToPort(51330)
        }
    }
    
    private func connectToPort(_ port: Int) async {
        isDiscovering = true
        if let instance = await OpenCodeDiscovery.checkSpecificPort(port) {
            discoveredInstances = [instance]
            selectedInstance = instance
            connectionManager.baseURL = instance.url
            await connectionManager.connect()
        }
        isDiscovering = false
    }
    
    private func discoverInstances() async {
        isDiscovering = true
        discoveredInstances = await OpenCodeDiscovery.discoverRunningInstances()
        isDiscovering = false
        
        // Auto-connect if only one instance found
        if discoveredInstances.count == 1 {
            selectedInstance = discoveredInstances[0]
            connectionManager.baseURL = discoveredInstances[0].url
            await connectionManager.connect()
        }
    }
}