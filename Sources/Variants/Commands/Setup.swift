//
//  Variants
//
//  Copyright (c) Backbase B.V. - https://www.backbase.com
//  Created by Arthur Alves
//

import Foundation
import ArgumentParser
import PathKit
import Yams

struct Setup: ParsableCommand, VerboseLogger {
    static var configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Setup deployment variants (alongside Fastlane)"
    )
    
    // --------------
    // MARK: Configuration Properties
    
    @Option()
    var platform: Platform
    
    @Option(name: .shortAndLong, default: "variants.yml", help: "Use a different yaml configuration spec")
    var spec: String
    
    @Flag(help: "Skip fastlane setup")
    var skipFastlane: Bool
    
    mutating func run() throws {
        Logger.shared.logSection("$ ", item: "variants setup \(platform)", color: .ios)
        
        do {
            let configurationHelper = ConfigurationHelper()
            guard let configuration = try configurationHelper.loadConfiguration(spec, platform: platform) else {
                throw RuntimeError("Unable to load spec '\(spec)'")
            }
            
            createVariants(with: configuration)
            setupFastlane(skipFastlane)
        } catch {
            throw RuntimeError("Sorry! Something is wrong with your YAML spec")
        }
    }
    
    // MARK: Private methods
    
    private func createVariants(with configuration: Configuration) {
        switch platform {
        case .ios:
            configuration.ios?.targets
                .map { (key: $0.key, value: $0.value) }
                .forEach { result in
                    try? createConfig(with: result,
                                      variants: configuration.ios?.variants,
                                      xcodeProj: configuration.ios?.xcodeproj)
            }
        case .android:
            break
        default:
            break
        }
    }
    
    // MARK: - iOS
    
    private func createConfig(with target: NamedTarget, variants: [Variant]?, xcodeProj: String?) throws {
        guard
            let variants = variants,
            !variants.isEmpty,
            let defaultVariant = variants.first(where: { $0.name == "default" })
        else {
            throw ValidationError("Missing mandatory variant: 'default'")
        }
        
        let configPath = Path(spec).absolute().parent()
        let factory = XCConfigFactory()
        factory.createConfig(with: target, variant: defaultVariant, xcodeProj: xcodeProj, configPath: configPath)
    }
    
    // MARK: - Setup Fastlane
    
    private func setupFastlane(_ skip: Bool) {
        if skip {
            logger.logInfo("Skipped Fastlane setup", item: "")
        } else {
            logger.logInfo("Setting up Fastlane", item: "")
            
            let result = XCConfigFactory().doesTemplateExist()
            guard result.exists, let path = result.path else { return }
            do {
                try Task.run(bash: "cp -R \(path.absolute())/\(platform)/_fastlane/* .", directory: nil)
                Logger.shared.logInfo("🚀 ", item: "Fastlane setup with success", color: .green)
                
                let setupCompleteMessage = """

                                            Your setup is complete, congratulations! 🎉
                                            
                                            However, you still need to provide some parameters in order for fastlane to run correctly.
                                            
                                            ⚠️  Check the files in 'fastlane/parameters/', change the parameters accordingly, provide environment variables when applicable.
                                            ⚠️  If you use Cocoapods-art, enable it in 'fastlane/Cocoapods'
                                            ⚠️  Change your signing configuration in 'fastlane/Match' and potentially 'fastlane/Deploy'

                                            That is all.
                                            """
                
                Logger.shared.logInfo("👇  Next steps ", item: "", color: .yellow)
                setupCompleteMessage.enumerateLines { (line, _) in
                    Logger.shared.logInfo("", item: line, color: .yellow)
                }
                
            } catch {
                fail(with: "Could not setup Fastlane - Not found in '\(path.abbreviate())'")
            }
        }
    }
}

extension Setup {
    private func loadConfiguration(_ path: String?) throws -> Configuration? {
        guard let path = path else {
            throw ValidationError("Error: Use '-s' to specify the configuration file")
        }
        
        let configurationPath = Path(path)
        guard !configurationPath.isDirectory else {
            throw ValidationError("Error: \(configurationPath) is a directory path")
        }
        
        let configuration = decode(configuration: path)
        return configuration
    }
}

extension Setup: YamlParser {
    private func decode(configuration: String) -> Configuration? {
        return extractConfiguration(from: configuration, platform: platform)
    }
}
