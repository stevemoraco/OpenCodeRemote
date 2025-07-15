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
        
        // First check the most common OpenCode ports
        let priorityPorts = [51330, 51896, 4096, 5173]
        
        for port in priorityPorts {
            if let instance = await checkSpecificPort(port) {
                instances.append(instance)
            }
        }
        
        // If no instances found, scan a limited range
        if instances.isEmpty {
            // Scan a smaller range around common ports
            let portRanges = [
                51300...51400,  // Around where OpenCode typically runs
                5170...5180,
                4090...4100
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
                
                for await instance in group {
                    if let instance = instance {
                        instances.append(instance)
                    }
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
        request.timeoutInterval = 0.3 // Very fast timeout for port scanning
        
        // Create a custom session with shorter timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0.3
        config.timeoutIntervalForResource = 0.3
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
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