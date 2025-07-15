import Foundation
import Network

class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var pathUpdateHandler: ((NWPath) -> Void)?
    
    func start() {
        monitor.pathUpdateHandler = pathUpdateHandler
        monitor.start(queue: queue)
    }
    
    func stop() {
        monitor.cancel()
    }
}