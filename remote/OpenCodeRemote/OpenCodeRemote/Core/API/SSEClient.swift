import Foundation

protocol SSEClientDelegate: AnyObject {
    func sseClient(_ client: SSEClient, didReceiveEvent event: SSEEvent)
    func sseClient(_ client: SSEClient, didFailWithError error: Error)
    func sseClientDidConnect(_ client: SSEClient)
    func sseClientDidDisconnect(_ client: SSEClient)
}

struct SSEEvent {
    let id: String?
    let event: String?
    let data: String
    let retry: TimeInterval?
}

class SSEClient: NSObject {
    weak var delegate: SSEClientDelegate?
    
    private let url: URL
    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var eventBuffer = ""
    private var lastEventId: String?
    private var reconnectTime: TimeInterval = 3.0
    private var isConnected = false
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    func connect() {
        disconnect()
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval.infinity
        configuration.timeoutIntervalForResource = TimeInterval.infinity
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        if let lastEventId = lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }
        
        task = session?.dataTask(with: request)
        task?.resume()
    }
    
    func disconnect() {
        isConnected = false
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        eventBuffer = ""
        
        DispatchQueue.main.async {
            self.delegate?.sseClientDidDisconnect(self)
        }
    }
    
    private func processEventBuffer() {
        let lines = eventBuffer.components(separatedBy: "\n")
        var remainingBuffer = ""
        
        var currentEvent = SSEEventBuilder()
        
        for (index, line) in lines.enumerated() {
            if index == lines.count - 1 && !eventBuffer.hasSuffix("\n") {
                remainingBuffer = line
                break
            }
            
            if line.isEmpty {
                if let event = currentEvent.build() {
                    handleEvent(event)
                }
                currentEvent = SSEEventBuilder()
            } else if line.hasPrefix(":") {
                // Comment, ignore
            } else if let colonIndex = line.firstIndex(of: ":") {
                let field = String(line[..<colonIndex])
                var value = String(line[line.index(after: colonIndex)...])
                if value.hasPrefix(" ") {
                    value = String(value.dropFirst())
                }
                
                switch field {
                case "id":
                    currentEvent.id = value
                    lastEventId = value
                case "event":
                    currentEvent.event = value
                case "data":
                    if currentEvent.data.isEmpty {
                        currentEvent.data = value
                    } else {
                        currentEvent.data += "\n" + value
                    }
                case "retry":
                    if let retryTime = TimeInterval(value) {
                        currentEvent.retry = retryTime
                        reconnectTime = retryTime / 1000.0
                    }
                default:
                    break
                }
            }
        }
        
        eventBuffer = remainingBuffer
    }
    
    private func handleEvent(_ event: SSEEvent) {
        DispatchQueue.main.async {
            self.delegate?.sseClient(self, didReceiveEvent: event)
        }
    }
    
    private func reconnect() {
        guard !isConnected else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectTime) { [weak self] in
            self?.connect()
        }
    }
}

// MARK: - URLSessionDataDelegate

extension SSEClient: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            completionHandler(.cancel)
            return
        }
        
        isConnected = true
        DispatchQueue.main.async {
            self.delegate?.sseClientDidConnect(self)
        }
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        
        eventBuffer += string
        processEventBuffer()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isConnected = false
        
        if let error = error {
            DispatchQueue.main.async {
                self.delegate?.sseClient(self, didFailWithError: error)
            }
            
            if (error as NSError).code != NSURLErrorCancelled {
                reconnect()
            }
        } else {
            reconnect()
        }
    }
}

// MARK: - SSEEventBuilder

private struct SSEEventBuilder {
    var id: String?
    var event: String?
    var data: String = ""
    var retry: TimeInterval?
    
    func build() -> SSEEvent? {
        guard !data.isEmpty else { return nil }
        
        return SSEEvent(
            id: id,
            event: event,
            data: data,
            retry: retry
        )
    }
}