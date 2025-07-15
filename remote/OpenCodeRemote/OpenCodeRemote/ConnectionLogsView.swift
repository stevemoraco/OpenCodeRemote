import SwiftUI

struct ConnectionLogsView: View {
    @ObservedObject var connectionManager: HybridConnectionManager
    @Environment(\.dismiss) var dismiss
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Connection Logs")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                
                Button("Clear") {
                    connectionManager.clearLogs()
                }
                .buttonStyle(.bordered)
                
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
            
            // Logs
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(connectionManager.connectionLogs) { log in
                            LogEntryView(log: log)
                                .id(log.id)
                        }
                    }
                    .padding()
                }
                #if os(macOS)
                .background(Color(NSColor.textBackgroundColor))
                #else
                .background(Color(UIColor.secondarySystemBackground))
                #endif
                .onChange(of: connectionManager.connectionLogs.count) { _ in
                    if autoScroll, let lastLog = connectionManager.connectionLogs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.systemBackground))
        #endif
    }
}

struct LogEntryView: View {
    let log: HybridConnectionManager.ConnectionLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(log.timestamp, style: .time)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            // Level indicator
            Circle()
                .fill(log.level.color)
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            
            // Message
            Text(log.message)
                .font(.caption.monospaced())
                .foregroundColor(log.level == .error ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}



#Preview {
    ConnectionLogsView(connectionManager: HybridConnectionManager())
}