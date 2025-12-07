//
//  RSIShareViewController.swift
//  receive_sharing_intent
//
//  Created by Kasem Mohamed on 2024-01-25.
//

import AVFoundation
import MobileCoreServices
import Photos
import Social
import UIKit

@available(swift, introduced: 5.0)
open class RSIShareViewController: SLComposeServiceViewController {
    var hostAppBundleIdentifier = ""
    var appGroupId = ""
    var sharedMedia: [SharedMediaFile] = []

    /// Override this method to return false if you don't want to redirect to host app automatically
    /// Default is true
    open func shouldAutoRedirect() -> Bool {
        return true
    }

    open override func isContentValid() -> Bool {
        return true
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        // load group and app id from build info
        loadIds()
    }

    // Redirect to host app when user click on Post
    open override func didSelectPost() {
        saveAndRedirect(message: contentText)
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
        if let content = extensionContext!.inputItems[0] as? NSExtensionItem {
            if let contents = content.attachments {
                for (index, attachment) in contents.enumerated() {
                    if let nsItemProvider = attachment as? NSItemProvider {
                        handleAttachment(nsItemProvider, index: index, content: content)
                    }
                }
            }
        }
    }

    private func handleAttachment(_ nsItemProvider: NSItemProvider, index: Int, content: NSExtensionItem) {
        // Check for image first (most common from Photos app)
        if nsItemProvider.hasItemConformingToTypeIdentifier(SharedMediaType.image.toUTTypeIdentifier) {
            nsItemProvider.loadItem(
                forTypeIdentifier: SharedMediaType.image.toUTTypeIdentifier, options: nil
            ) { [weak self] (data, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("[RSI] Error loading image: \(error.localizedDescription)")
                    self.checkAndRedirect(index: index, content: content)
                    return
                }
                
                if let url = data as? URL {
                    self.handleMedia(forFile: url, type: .image, index: index, content: content)
                } else if let image = data as? UIImage {
                    self.handleMedia(forUIImage: image, type: .image, index: index, content: content)
                } else {
                    print("[RSI] Unknown image data type: \(String(describing: data))")
                    self.checkAndRedirect(index: index, content: content)
                }
            }
        }
        // Check for video
        else if nsItemProvider.hasItemConformingToTypeIdentifier(SharedMediaType.video.toUTTypeIdentifier) {
            nsItemProvider.loadItem(
                forTypeIdentifier: SharedMediaType.video.toUTTypeIdentifier, options: nil
            ) { [weak self] (data, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("[RSI] Error loading video: \(error.localizedDescription)")
                    self.checkAndRedirect(index: index, content: content)
                    return
                }
                
                if let url = data as? URL {
                    self.handleMedia(forFile: url, type: .video, index: index, content: content)
                } else {
                    print("[RSI] Unknown video data type: \(String(describing: data))")
                    self.checkAndRedirect(index: index, content: content)
                }
            }
        }
        // Check for PDF
        else if nsItemProvider.hasItemConformingToTypeIdentifier(SharedMediaType.pdf.toUTTypeIdentifier) {
            nsItemProvider.loadItem(
                forTypeIdentifier: SharedMediaType.pdf.toUTTypeIdentifier, options: nil
            ) { [weak self] (data, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("[RSI] Error loading pdf: \(error.localizedDescription)")
                    self.checkAndRedirect(index: index, content: content)
                    return
                }
                
                if let url = data as? URL {
                    self.handleMedia(forFile: url, type: .pdf, index: index, content: content)
                } else {
                    print("[RSI] Unknown pdf data type: \(String(describing: data))")
                    self.checkAndRedirect(index: index, content: content)
                }
            }
        }
        // Check for URL
        else if nsItemProvider.hasItemConformingToTypeIdentifier(SharedMediaType.url.toUTTypeIdentifier) {
            nsItemProvider.loadItem(
                forTypeIdentifier: SharedMediaType.url.toUTTypeIdentifier, options: nil
            ) { [weak self] (data, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("[RSI] Error loading url: \(error.localizedDescription)")
                    self.checkAndRedirect(index: index, content: content)
                    return
                }
                
                if let url = data as? URL {
                    self.handleMedia(forLiteral: url.absoluteString, type: .url, index: index, content: content)
                } else {
                    print("[RSI] Unknown url data type: \(String(describing: data))")
                    self.checkAndRedirect(index: index, content: content)
                }
            }
        }
        // Check for text
        else if nsItemProvider.hasItemConformingToTypeIdentifier(SharedMediaType.text.toUTTypeIdentifier) {
            nsItemProvider.loadItem(
                forTypeIdentifier: SharedMediaType.text.toUTTypeIdentifier, options: nil
            ) { [weak self] (data, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("[RSI] Error loading text: \(error.localizedDescription)")
                    self.checkAndRedirect(index: index, content: content)
                    return
                }
                
                if let text = data as? String {
                    self.handleMedia(forLiteral: text, type: .text, index: index, content: content)
                } else {
                    print("[RSI] Unknown text data type: \(String(describing: data))")
                    self.checkAndRedirect(index: index, content: content)
                }
            }
        }
        // Check for file
        else if nsItemProvider.hasItemConformingToTypeIdentifier(SharedMediaType.file.toUTTypeIdentifier) {
            nsItemProvider.loadItem(
                forTypeIdentifier: SharedMediaType.file.toUTTypeIdentifier, options: nil
            ) { [weak self] (data, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    print("[RSI] Error loading file: \(error.localizedDescription)")
                    self.checkAndRedirect(index: index, content: content)
                    return
                }
                
                if let url = data as? URL {
                    self.handleMedia(forFile: url, type: .file, index: index, content: content)
                } else {
                    print("[RSI] Unknown file data type: \(String(describing: data))")
                    self.checkAndRedirect(index: index, content: content)
                }
            }
        }
        else {
            print("[RSI] No matching type identifier found for attachment")
            self.checkAndRedirect(index: index, content: content)
        }
    }

    private func checkAndRedirect(index: Int, content: NSExtensionItem) {
        // Check if this is the last attachment
        if index == (content.attachments?.count ?? 0) - 1 {
            if shouldAutoRedirect() {
                saveAndRedirect()
            }
        }
    }

    open override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }

    private func loadIds() {
        // loading Share extension App Id
        let shareExtensionAppBundleIdentifier = Bundle.main.bundleIdentifier!

        // extract host app bundle id from ShareExtension id
        // by default it's <hostAppBundleIdentifier>.<ShareExtension>
        // for example: "com.kasem.sharing.Share-Extension" -> com.kasem.sharing
        let lastIndexOfPoint = shareExtensionAppBundleIdentifier.lastIndex(of: ".")
        hostAppBundleIdentifier = String(shareExtensionAppBundleIdentifier[..<lastIndexOfPoint!])
        let defaultAppGroupId = "group.\(hostAppBundleIdentifier)"

        // loading custom AppGroupId from Build Settings or use group.<hostAppBundleIdentifier>
        let customAppGroupId = Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String

        appGroupId = customAppGroupId ?? defaultAppGroupId
    }

    private func handleMedia(
        forLiteral item: String, type: SharedMediaType, index: Int, content: NSExtensionItem
    ) {
        sharedMedia.append(
            SharedMediaFile(
                path: item,
                mimeType: type == .text ? "text/plain" : nil,
                type: type
            ))
        checkAndRedirect(index: index, content: content)
    }

    private func handleMedia(
        forUIImage image: UIImage, type: SharedMediaType, index: Int, content: NSExtensionItem
    ) {
        let tempPath = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId)!.appendingPathComponent(
                "TempImage.png")
        if self.writeTempFile(image, to: tempPath) {
            let newPathDecoded = tempPath.absoluteString.removingPercentEncoding!
            sharedMedia.append(
                SharedMediaFile(
                    path: newPathDecoded,
                    mimeType: type == .image ? "image/png" : nil,
                    type: type
                ))
        }
        checkAndRedirect(index: index, content: content)
    }

    private func handleMedia(
        forFile url: URL, type: SharedMediaType, index: Int, content: NSExtensionItem
    ) {
        let fileName = getFileName(from: url, type: type)
        let newPath = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId)!.appendingPathComponent(fileName)

        if copyFile(at: url, to: newPath) {
            // The path should be decoded because Flutter is not expecting url encoded file names
            let newPathDecoded = newPath.absoluteString.removingPercentEncoding!
            if type == .video {
                // Get video thumbnail and duration
                if let videoInfo = getVideoInfo(from: url) {
                    let thumbnailPathDecoded = videoInfo.thumbnail?.removingPercentEncoding
                    sharedMedia.append(
                        SharedMediaFile(
                            path: newPathDecoded,
                            mimeType: url.mimeType(),
                            thumbnail: thumbnailPathDecoded,
                            duration: videoInfo.duration,
                            type: type
                        ))
                }
            } else {
                sharedMedia.append(
                    SharedMediaFile(
                        path: newPathDecoded,
                        mimeType: url.mimeType(),
                        type: type
                    ))
            }
        }

        checkAndRedirect(index: index, content: content)
    }
                saveAndRedirect()
            }
        }
    }

    // Save shared media and redirect to host app
    private func saveAndRedirect(message: String? = nil) {
        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set(toData(data: sharedMedia), forKey: kUserDefaultsKey)
        userDefaults?.set(message, forKey: kUserDefaultsMessageKey)
        userDefaults?.synchronize()
        redirectToHostApp()
    }

    private func redirectToHostApp() {
        // ids may not loaded yet so we need loadIds here too
        loadIds()
        let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share")
        var responder = self as UIResponder?

        if #available(iOS 18.0, *) {
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url!, options: [:], completionHandler: nil)
                }
                responder = responder?.next
            }
        } else {
            let selectorOpenURL = sel_registerName("openURL:")

            while responder != nil {
                if (responder?.responds(to: selectorOpenURL))! {
                    _ = responder?.perform(selectorOpenURL, with: url)
                }
                responder = responder!.next
            }
        }

        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func dismissWithError() {
        print("[ERROR] Error loading data!")
        let alert = UIAlertController(
            title: "Error", message: "Error loading data", preferredStyle: .alert)

        let action = UIAlertAction(title: "Error", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }

        alert.addAction(action)
        present(alert, animated: true, completion: nil)
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func getFileName(from url: URL, type: SharedMediaType) -> String {
        var name = url.lastPathComponent
        if name.isEmpty {
            switch type {
            case .image:
                name = UUID().uuidString + ".png"
            case .video:
                name = UUID().uuidString + ".mp4"
            case .text:
                name = UUID().uuidString + ".txt"
            default:
                name = UUID().uuidString
            }
        }
        return name
    }

    private func writeTempFile(_ image: UIImage, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            if let pngData = image.pngData() {
                try pngData.write(to: dstURL)
                return true
            }
            return false
        } catch (let error) {
            print("Cannot write to temp file: \(error)")
            return false
        }
    }

    private func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch (let error) {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return false
        }
        return true
    }

    private func getVideoInfo(from url: URL) -> (thumbnail: String?, duration: Double)? {
        let asset = AVAsset(url: url)
        let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
        let thumbnailPath = getThumbnailPath(for: url)

        if FileManager.default.fileExists(atPath: thumbnailPath.path) {
            return (thumbnail: thumbnailPath.absoluteString, duration: duration)
        }

        var saved = false
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        //        let scale = UIScreen.main.scale
        assetImgGenerate.maximumSize = CGSize(width: 360, height: 360)
        do {
            let time = CMTimeMake(value: 600, timescale: 1)
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            if let pngData = UIImage(cgImage: img).pngData() {
                try pngData.write(to: thumbnailPath)
            }
            saved = true
        } catch {
            saved = false
        }

        return saved ? (thumbnail: thumbnailPath.absoluteString, duration: duration) : nil
    }

    private func getThumbnailPath(for url: URL) -> URL {
        let fileName = Data(url.lastPathComponent.utf8).base64EncodedString().replacingOccurrences(
            of: "==", with: "")
        let path = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent("\(fileName).jpg")
        return path
    }

    private func toData(data: [SharedMediaFile]) -> Data {
        let encodedData = try? JSONEncoder().encode(data)
        return encodedData!
    }
}

extension URL {
    public func mimeType() -> String {
        if #available(iOS 14.0, *) {
            if let mimeType = UTType(filenameExtension: self.pathExtension)?.preferredMIMEType {
                return mimeType
            }
        } else {
            if let uti = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension, self.pathExtension as NSString, nil)?
                .takeRetainedValue()
            {
                if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?
                    .takeRetainedValue()
                {
                    return mimetype as String
                }
            }
        }

        return "application/octet-stream"
    }
}
