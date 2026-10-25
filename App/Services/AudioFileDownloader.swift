import Foundation

/// One native session with delegate-driven downloads. A per-task delegate on
/// async download(for:) did not deliver the live progress needed by our bound
/// in the iOS integration probes. Keep native disk streaming and cancellation.
final class AudioFileDownloader: @unchecked Sendable {
    private let router = AudioDownloadRouter()
    private let session: URLSession

    init(configuration: URLSessionConfiguration) {
        session = URLSession(configuration: configuration, delegate: router, delegateQueue: nil)
    }

    func download(for request: URLRequest, delegate: any URLSessionTaskDelegate) async throws -> (URL, URLResponse) {
        let transfer = AudioDownloadTransfer(observer: delegate)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                transfer.start(request: request, session: session, router: router, continuation: continuation)
            }
        } onCancel: {
            transfer.cancel()
        }
    }

    func invalidateAndCancel() { session.invalidateAndCancel() }
    deinit { session.invalidateAndCancel() }
}

private final class AudioDownloadRouter: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var transfers: [Int: AudioDownloadTransfer] = [:]

    func register(_ transfer: AudioDownloadTransfer, task: URLSessionDownloadTask) {
        lock.lock()
        transfers[task.taskIdentifier] = transfer
        lock.unlock()
    }

    private func transfer(for task: URLSessionTask, removing: Bool = false) -> AudioDownloadTransfer? {
        lock.lock()
        defer { lock.unlock() }
        return removing ? transfers.removeValue(forKey: task.taskIdentifier) : transfers[task.taskIdentifier]
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let transfer = transfer(for: downloadTask),
              let observer = transfer.observer as? any URLSessionDownloadDelegate else { return }
        observer.urlSession?(session, downloadTask: downloadTask, didWriteData: bytesWritten,
                             totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let transfer = transfer(for: downloadTask) else { return }
        // Foundation removes its temporary URL when this callback returns.
        // Move it while valid, before resuming the caller on another executor.
        let owned = FileManager.default.temporaryDirectory
            .appendingPathComponent("sakina-download-\(UUID().uuidString).tmp")
        do {
            guard let response = downloadTask.response else { throw URLError(.badServerResponse) }
            try FileManager.default.moveItem(at: location, to: owned)
            transfer.received(file: owned, response: response)
        } catch {
            try? FileManager.default.removeItem(at: owned)
            transfer.failed(error)
            downloadTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        transfer(for: task, removing: true)?.complete(error: error)
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        lock.lock()
        let pending = Array(transfers.values)
        transfers.removeAll()
        lock.unlock()
        for transfer in pending { transfer.complete(error: error ?? URLError(.cancelled)) }
    }
}

/// Cancellation may happen before task registration or after file delivery.
/// Protect ownership and the continuation; never resume under the router lock.
private final class AudioDownloadTransfer: @unchecked Sendable {
    let observer: any URLSessionTaskDelegate
    private let lock = NSLock()
    private var cancelled = false
    private var finished = false
    private var task: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var saved: (URL, URLResponse)?
    private var storageError: Error?

    init(observer: any URLSessionTaskDelegate) { self.observer = observer }

    func start(request: URLRequest, session: URLSession, router: AudioDownloadRouter,
               continuation: CheckedContinuation<(URL, URLResponse), Error>) {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        let task = session.downloadTask(with: request)
        self.task = task
        // Register before cancellation can expose the task to its callbacks.
        router.register(self, task: task)
        lock.unlock()
        task.resume()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let pending = task
        lock.unlock()
        pending?.cancel()
    }

    func received(file: URL, response: URLResponse) {
        lock.lock()
        let alreadyFinished = finished
        if !alreadyFinished { saved = (file, response) }
        lock.unlock()
        if alreadyFinished { try? FileManager.default.removeItem(at: file) }
    }

    func failed(_ error: Error) {
        lock.lock()
        storageError = error
        lock.unlock()
    }

    func complete(error: Error?) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let waiter = continuation
        let file = saved
        let failure: Error? = cancelled ? CancellationError() : (storageError ?? error)
        continuation = nil
        task = nil
        saved = nil
        lock.unlock()

        if let failure {
            if let file { try? FileManager.default.removeItem(at: file.0) }
            waiter?.resume(throwing: failure)
        } else if let file {
            // The caller now owns this URL and must move or remove it.
            waiter?.resume(returning: file)
        } else {
            waiter?.resume(throwing: URLError(.cannotDecodeContentData))
        }
    }
}
