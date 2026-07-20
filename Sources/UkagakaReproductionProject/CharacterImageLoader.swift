import AppKit
import Foundation
import ImageIO

enum CharacterImageLoader {
    private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 96 * 1_024 * 1_024
        return cache
    }()
    private static let cacheLock = NSLock()
    private static let decodeLock = NSLock()
    private static var missingAssetKeys: Set<String> = []
    private static let maximumDecodedPixelSize = 720

    static func sprite(
        for character: CompanionCharacter,
        expression: CharacterExpression,
        gesture: CharacterGesture
    ) -> CharacterSprite? {
        if let layered = layeredSprite(for: character, expression: expression, gesture: gesture) {
            return layered
        }

        if let legacy = legacyImage(for: character, expression: expression) {
            return CharacterSprite(images: [legacy])
        }

        return nil
    }

    static func preload(characters: [CompanionCharacter]) {
        let descriptors = characters.map { ($0.assetNamePrefix, $0.assetRootPath) }
        DispatchQueue.global(qos: .utility).async {
            for (prefix, rootPath) in descriptors {
                for expression in CharacterExpression.allCases {
                    _ = image(named: "\(prefix)_\(expression.rawValue)", externalRootPath: rootPath)
                    _ = image(named: "\(prefix)/face_\(expression.rawValue)", externalRootPath: rootPath)
                    _ = image(named: "\(prefix)/icon_\(expression.rawValue)", externalRootPath: rootPath)
                }
                _ = image(named: "\(prefix)/base", externalRootPath: rootPath)
                for gesture in CharacterGesture.allCases {
                    _ = image(named: "\(prefix)/hand_\(gesture.rawValue)", externalRootPath: rootPath)
                }
            }
        }
    }

    static func clearCache() {
        decodeLock.lock()
        imageCache.removeAllObjects()
        decodeLock.unlock()
        cacheLock.lock()
        missingAssetKeys.removeAll()
        cacheLock.unlock()
    }

    static func missingAssets() -> [String] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return missingAssetKeys.sorted()
    }

    private static func layeredSprite(
        for character: CompanionCharacter,
        expression: CharacterExpression,
        gesture: CharacterGesture
    ) -> CharacterSprite? {
        guard let base = image(
            named: "\(character.assetNamePrefix)/base",
            externalRootPath: character.assetRootPath
        ) else {
            return nil
        }

        var images = [base]
        for layerName in [
            "\(character.assetNamePrefix)/hand_\(gesture.rawValue)",
            "\(character.assetNamePrefix)/face_\(expression.rawValue)",
            "\(character.assetNamePrefix)/icon_\(expression.rawValue)"
        ] {
            if let layerImage = image(named: layerName, externalRootPath: character.assetRootPath) {
                images.append(layerImage)
            }
        }

        return CharacterSprite(images: images)
    }

    private static func legacyImage(for character: CompanionCharacter, expression: CharacterExpression) -> NSImage? {
        let baseNames = [
            "\(character.assetNamePrefix)_\(expression.rawValue)",
            "\(character.assetNamePrefix)_happy",
            character.assetNamePrefix
        ]

        for baseName in baseNames {
            if let image = image(named: baseName, externalRootPath: character.assetRootPath) {
                return image
            }
        }

        return nil
    }

    private static func image(named assetPath: String, externalRootPath: String?) -> NSImage? {
        let lookupKey = "\(externalRootPath ?? "bundled")|\(assetPath)"
        if isKnownMissing(lookupKey) {
            return nil
        }

        let parts = assetPath.split(separator: "/").map(String.init)
        guard let fileName = parts.last else { return nil }
        let nestedDirectory = parts.dropLast().joined(separator: "/")
        let subdirectory = nestedDirectory.isEmpty ? "Characters" : "Characters/\(nestedDirectory)"

        for fileExtension in ["png", "jpg", "jpeg"] {
            for directoryURL in externalSearchDirectories(rootPath: externalRootPath, nestedDirectory: nestedDirectory) {
                let candidateURL = directoryURL
                    .appendingPathComponent(fileName)
                    .appendingPathExtension(fileExtension)
                if let image = decodedImage(at: candidateURL) {
                    return image
                }
            }

            if let url = Bundle.main.url(
                forResource: fileName,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ), let image = decodedImage(at: url) {
                return image
            }

            if let url = swiftPackageResourceBundle?.url(
                forResource: fileName,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ), let image = decodedImage(at: url) {
                return image
            }
        }

        markMissing(lookupKey)
        return nil
    }

    private static func decodedImage(at url: URL) -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let timestamp = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let fileSize = values?.fileSize ?? 0
        let cacheKey = "\(url.path)|\(timestamp)|\(fileSize)|\(maximumDecodedPixelSize)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        decodeLock.lock()
        defer { decodeLock.unlock() }
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumDecodedPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else {
            return nil
        }

        let decoded = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageCache.setObject(decoded, forKey: cacheKey, cost: image.bytesPerRow * image.height)
        return decoded
    }

    private static func externalSearchDirectories(rootPath: String?, nestedDirectory: String) -> [URL] {
        guard let rootPath, !rootPath.isEmpty else { return [] }

        let expandedPath = NSString(string: rootPath).expandingTildeInPath
        let rootURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        let nestedPath = nestedDirectory.isEmpty ? "" : nestedDirectory

        return [
            rootURL.appendingPathComponent(nestedPath, isDirectory: true),
            rootURL.appendingPathComponent("Characters").appendingPathComponent(nestedPath, isDirectory: true)
        ]
    }

    private static func isKnownMissing(_ key: String) -> Bool {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return missingAssetKeys.contains(key)
    }

    private static func markMissing(_ key: String) {
        cacheLock.lock()
        missingAssetKeys.insert(key)
        cacheLock.unlock()
    }

    private static var swiftPackageResourceBundle: Bundle? {
        guard let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() else {
            return nil
        }
        let bundleURL = executableDirectory.appendingPathComponent(
            "UkagakaReproductionProject_UkagakaReproductionProject.bundle",
            isDirectory: true
        )
        return Bundle(url: bundleURL)
    }
}
