import UIKit
import Social
import UniformTypeIdentifiers

/// Share extension view controller that receives shared content from other apps.
///
/// When the user shares text, a URL, or an image from any app, iOS presents
/// this extension. The shared content is extracted and stored in shared
/// UserDefaults (App Group: group.com.anynote.app). After processing, the
/// main app is opened via the `anynote://` URL scheme so the Flutter side
/// can read and handle the pending share.
///
/// The Flutter side reads the data via MethodChannel `com.anynote.app/share`.
class ShareViewController: UIViewController {

    /// Shared UserDefaults suite for the App Group.
    private let sharedDefaults = UserDefaults(suiteName: "group.com.anynote.app")

    private let kPendingShareKey = "pending_share"
    private let kPendingShareTimestampKey = "pending_share_timestamp"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        processSharedItem()
    }

    // MARK: - Processing

    /// Extract shared content from the extension context and persist it.
    private func processSharedItem() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem],
              let firstItem = extensionItems.first else {
            closeExtension()
            return
        }

        // Try to extract text first.
        if let textProvider = firstItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }) {
            textProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) {
                [weak self] (data, error) in
                guard let self = self else { return }
                if let text = data as? String {
                    self.persistAndOpenMainApp(type: "text", text: text)
                } else {
                    self.closeExtension()
                }
            }
            return
        }

        // Try to extract a URL.
        if let urlProvider = firstItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) {
                [weak self] (data, error) in
                guard let self = self else { return }
                if let url = data as? URL {
                    self.persistAndOpenMainApp(type: "text", text: url.absoluteString)
                } else {
                    self.closeExtension()
                }
            }
            return
        }

        // Try to extract an image.
        if let imageProvider = firstItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) {
            imageProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) {
                [weak self] (data, error) in
                guard let self = self else { return }
                if let url = data as? URL {
                    // Copy the image to the shared group container so the
                    // main app can access it.
                    let localPath = self.copyToSharedContainer(sourceURL: url)
                    if let path = localPath {
                        self.persistAndOpenMainApp(type: "image", path: path)
                    } else {
                        self.closeExtension()
                    }
                } else if let image = data as? UIImage,
                          let jpegData = image.jpegData(compressionQuality: 0.9) {
                    let fileName = "share_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
                    let containerURL = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier: "group.com.anynote.app"
                    )
                    let fileURL = containerURL!.appendingPathComponent(fileName)
                    do {
                        try jpegData.write(to: fileURL)
                        self.persistAndOpenMainApp(type: "image", path: fileURL.path)
                    } catch {
                        self.closeExtension()
                    }
                } else {
                    self.closeExtension()
                }
            }
            return
        }

        // Try to extract a file / data.
        if let fileProvider = firstItem.attachments?.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.data.identifier)
        }) {
            fileProvider.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) {
                [weak self] (data, error) in
                guard let self = self else { return }
                if let url = data as? URL {
                    let localPath = self.copyToSharedContainer(sourceURL: url)
                    if let path = localPath {
                        self.persistAndOpenMainApp(type: "file", path: path)
                    } else {
                        self.closeExtension()
                    }
                } else {
                    self.closeExtension()
                }
            }
            return
        }

        // Nothing we can handle.
        closeExtension()
    }

    // MARK: - Persistence

    /// Store the shared data in shared UserDefaults and open the main app.
    ///
    /// - Parameters:
    ///   - type: "text", "image", or "file"
    ///   - text: shared text (for text type)
    ///   - path: local file path (for image/file type)
    private func persistAndOpenMainApp(type: String, text: String? = nil, path: String? = nil) {
        var json = "{\"type\":\"\(type)\""
        if let t = text {
            let escaped = t
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            json += ",\"text\":\"\(escaped)\""
        }
        if let p = path {
            let escaped = p.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            json += ",\"path\":\"\(escaped)\""
        }
        json += "}"

        sharedDefaults?.set(json, forKey: kPendingShareKey)
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: kPendingShareTimestampKey)
        sharedDefaults?.synchronize()

        openMainApp()
    }

    // MARK: - Navigation

    /// Open the main app via the custom URL scheme so Flutter can handle the share.
    private func openMainApp() {
        // Use a URL scheme to signal the main app that a share is pending.
        var responder: UIResponder? = self as UIResponder
        let selector = #selector(openURL(_:))
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: URL(string: "anynote://share/received")!)
                break
            }
            responder = responder?.next
        }
        closeExtension()
    }

    @objc private func openURL(_ url: URL) {
        // Overridden by responder chain above.
    }

    /// Close this share extension.
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    // MARK: - File Helpers

    /// Copy a file from the source URL to the shared App Group container.
    private func copyToSharedContainer(sourceURL: URL) -> String? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.anynote.app"
        ) else { return nil }

        let fileName = "share_\(Int(Date().timeIntervalSince1970 * 1000))_\(sourceURL.lastPathComponent)"
        let destURL = containerURL.appendingPathComponent(fileName)

        do {
            // Security-scoped resource access for iCloud / sandbox files.
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL.path
        } catch {
            return nil
        }
    }
}
