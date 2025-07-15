import Foundation
import Network

struct OpenCodeInstance {
    let port: Int
    let pid: Int
    let url: String
}

class OpenCodeDiscovery {
    static func discoverRunningInstances() async -> [OpenCodeInstance] {
        var instances: [OpenCodeInstance] = []
        
        // Method 1: Scan a wider range of ports since OpenCode uses dynamic ports
        // OpenCode seems to use ports in the 50000+ range
        let portRanges = [
            // Common development ports
            3000...3010,
            4000...4010,
            5000...5010,
            8000...8010,
            // Higher port range where OpenCode typically runs
            50000...52000
        ]
        
        // Use concurrent checking for better performance
        await withTaskGroup(of: OpenCodeInstance?.self) { group in
            for range in portRanges {
                for port in range {
                    group.addTask {
                        if await isOpenCodeRunning(at: port) {
                            print("Found OpenCode instance on port \(port)")
                            return OpenCodeInstance(port: port, pid: 0, url: "http://localhost:\(port)")
                        }
                        return nil
                    }
                }
            }
            
            // Limit concurrent tasks to avoid overwhelming the system
            var taskCount = 0
            for await instance in group {
                if let instance = instance {
                    instances.append(instance)
                }
                taskCount += 1
                if taskCount % 100 == 0 {
                    // Small delay every 100 ports to avoid too many concurrent connections
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
        }
        
        // Remove duplicates and sort by port
        let uniqueInstances = Array(Set(instances.map { $0.port }))
            .sorted()
            .compactMap { port in
                instances.first { $0.port == port }
            }
        
        print("Discovery complete. Found \(uniqueInstances.count) OpenCode instances")
        return uniqueInstances
    }
    
    private static func isOpenCodeRunning(at port: Int) async -> Bool {
        // Try the /app endpoint which returns app info
        let url = URL(string: "http://localhost:\(port)/app")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5 // Faster timeout for port scanning
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // OpenCode's /app endpoint returns JSON with hostname, time, git, path fields
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["hostname"] != nil && json["path"] != nil {
                    return true
                }
            }
        } catch {
            // Connection failed - this is expected for most ports
        }
        
        return false
    }
    
    private static func scanForOpenCodeProcesses() async -> [OpenCodeInstance]? {
        // iOS apps can't use Process, so we'll just scan common ports
        return nil
    }
    
    // Quick check for a specific port
    static func checkSpecificPort(_ port: Int) async -> OpenCodeInstance? {
        if await isOpenCodeRunning(at: port) {
            return OpenCodeInstance(port: port, pid: 0, url: "http://localhost:\(port)")
        }
        return nil
    }
    
    // Alternative method using netstat
    static func scanPortRange(from startPort: Int = 3000, to endPort: Int = 9000) async -> [OpenCodeInstance] {
        var instances: [OpenCodeInstance] = []
        
        await withTaskGroup(of: OpenCodeInstance?.self) { group in
            for port in startPort...endPort {
                group.addTask {
                    if await self.isOpenCodeRunning(at: port) {
                        return OpenCodeInstance(port: port, pid: 0, url: "http://localhost:\(port)")
                    }
                    return nil
                }
            }
            
            for await instance in group {
                if let instance = instance {
                    instances.append(instance)
                }
            }
        }
        
        return instances
    }
}