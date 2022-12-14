//
//  Variants
//
//  Copyright (c) Backbase B.V. - https://www.backbase.com
//  Created by Giuseppe Deraco
//

import Foundation
import PathKit
import Stencil

protocol GradleFactory {
    func createScript(with configuration: AndroidConfiguration, variant: AndroidVariant) throws
    func render(with configuration: AndroidConfiguration, variant: AndroidVariant) throws -> Data?
    func write(_ data: Data, using gradleScriptFolder: Path) throws
}

class GradleScriptFactory: GradleFactory {
    init(templatePath: Path? = try? TemplateDirectory().path) {
        self.templatePath = templatePath
    }
    
    /// Create `gradleScripts/variants.gradle` file inside project's path
    /// - Parameters:
    ///   - configuration: Android configuration from `variants.yml`
    ///   - variant: Desired project variant.
    func createScript(with configuration: AndroidConfiguration, variant: AndroidVariant) throws {
        let variantsScriptPath = try Path(configuration.path).safeJoin(path: Path("gradleScripts/"))
        if !variantsScriptPath.exists {
            try variantsScriptPath.mkpath()
        }
        guard let data = try render(with: configuration, variant: variant) else { return }
        try write(data, using: variantsScriptPath)
    }
    
    func render(with configuration: AndroidConfiguration, variant: AndroidVariant) throws -> Data? {
        var context = [
            "variant": variant,
            "configuration": configuration
        ] as [String: Any]

        /*
         * `Stencil` doesn't support computed properties.
         *
         * For this reason, `variant.configIdSuffix` and `variant.configName` won't be added
         * to the template.
         *
         * ISSUE: https://github.com/stencilproject/Stencil/issues/219
         *
         * WORKAROUND:
         * We'll pass both values directly to the context dictionary.
         *
         */
        context["variantIdSuffix"] = variant.configIdSuffix
        context["variantName"] = variant.configName
        
        if let variantProperties = variant.custom?.literal() {
            context["variant_properties"] = variantProperties
        }
        
        if let variantEnvVars = variant.custom?.envVars()  {
            context["variant_env_vars"] = variantEnvVars
        }
        
        if let globalProperties = configuration.custom?.literal() {
            context["global_properties"] = globalProperties
        }
        
        if let globalEnvVars = configuration.custom?.envVars() {
            context["global_env_vars"] = globalEnvVars
        }
        
        guard
            let path = templatePath,
            let androidTemplatePath = try? path.safeJoin(path: Path("android/"))
        else { return nil }
        let environment = Environment(loader: FileSystemLoader(paths: [androidTemplatePath.absolute()]))
        let rendered = try environment.renderTemplate(name: StaticPath.Template.variantsScriptFileName,
                                                      context: context)
        
        // Replace multiple empty lines by one only
        let lines = rendered.split(whereSeparator: \.isNewline)
        let content = lines.joined(separator: "\n")
        
        return Data(content.utf8)
    }
    
    func write(_ data: Data, using gradleScriptFolder: Path) throws {
            if gradleScriptFolder.isDirectory, gradleScriptFolder.exists {
                let fastlaneParametersFile = Path(gradleScriptFolder.string+StaticPath
                                                    .Gradle.variantsScriptFileName)
                
                // Only proceed to write to file if such doesn't yet exist
                // Or does exist and 'isWritable'
                guard !fastlaneParametersFile.exists
                        || fastlaneParametersFile.isWritable else {
                    throw TemplateDoesNotExist(templateNames: [gradleScriptFolder.string])
                }
                
                // Write to file
                try fastlaneParametersFile.write(data)
                
                if
                    let fileContent = try? fastlaneParametersFile.read(),
                    fileContent == data {
                    Logger.shared.logInfo("??????  ", item: """
                        '\(fastlaneParametersFile.abbreviate().string)' has been generated with success
                        """, color: .green)
                }
            } else {
                throw TemplateDoesNotExist(templateNames: [gradleScriptFolder.string])
            }
    }
    
    private let templatePath: Path?
}

fileprivate extension Sequence where Iterator.Element == CustomProperty {
    func envVars() -> [CustomProperty] {
        return self
            .filter({ $0.destination == .project && $0.isEnvironmentVariable })
            .map { (property) -> CustomProperty in
                return CustomProperty(name: property.name,
                                      value: "System.getenv('"+property.environmentValue+"')",
                                      destination: property.destination)
            }
    }
    
    func literal() -> [CustomProperty] {
        return self
            .filter({ $0.destination == .project && !$0.isEnvironmentVariable })
    }
}
