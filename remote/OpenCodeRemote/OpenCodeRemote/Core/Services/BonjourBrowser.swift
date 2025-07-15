import Foundation

protocol BonjourBrowserDelegate: AnyObject {
    func bonjourBrowser(_ browser: BonjourBrowser, didFindService service: NetService)
    func bonjourBrowser(_ browser: BonjourBrowser, didRemoveService service: NetService)
}

class BonjourBrowser: NSObject {
    weak var delegate: BonjourBrowserDelegate?
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    
    override init() {
        super.init()
        browser.delegate = self
    }
    
    func startBrowsing() {
        browser.searchForServices(ofType: "_opencode._tcp", inDomain: "")
    }
    
    func stopBrowsing() {
        browser.stop()
    }
}

extension BonjourBrowser: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        delegate?.bonjourBrowser(self, didRemoveService: service)
    }
}

extension BonjourBrowser: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        delegate?.bonjourBrowser(self, didFindService: sender)
    }
}