import AppKit
import Foundation

enum CharacterImageLoader {
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
            character.assetNamePrefix
        ]

        for baseName in baseNames {
            if let image = image(named: baseName, externalRootPath: character.assetRootPath) {
                return image
            }
        }

        return nil
    }

    private static func image(named assetPath: String) -> NSImage? {
        image(named: assetPath, externalRootPath: nil)
    }

    private static func image(named assetPath: String, externalRootPath: String?) -> NSImage? {
        let parts = assetPath.split(separator: "/").map(String.init)
        guard let fileName = parts.last else { return nil }
        let nestedDirectory = parts.dropLast().joined(separator: "/")
        let subdirectory = nestedDirectory.isEmpty ? "Characters" : "Characters/\(nestedDirectory)"

        for fileExtension in ["png", "jpg", "jpeg"] {
            for directoryURL in externalSearchDirectories(rootPath: externalRootPath, nestedDirectory: nestedDirectory) {
                let candidateURL = directoryURL
                    .appendingPathComponent(fileName)
                    .appendingPathExtension(fileExtension)
                if let image = NSImage(contentsOf: candidateURL) {
                    return image
                }
            }

            if let url = Bundle.module.url(
                forResource: fileName,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ), let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
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
}
