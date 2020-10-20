//
// Copyright © 2020 Backbase R&D B.V. All rights reserved.
//

import Foundation

struct Bash {
    var command: String
    var arguments: [String]
    
    init(_ command: String, arguments: String...) {
        self.command = command
        self.arguments = arguments
    }
    
    func run() throws -> String? {
        guard var bashCommand = try execute(command: "/bin/bash" , arguments: ["-l", "-c", "which \(command)"]) else {
            throw RuntimeError("\(command) not found")
        }
        bashCommand = bashCommand.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        let output = try execute(command: bashCommand, arguments: arguments)
        if (output != nil)
        {
            return String(output!.dropLast())
        }
        return nil
    }
    
    // MARK: - Private
    
    private func execute(command: String, arguments: [String] = []) throws -> String? {
        let process = Process()
        let pipe = Pipe()
        process.arguments = arguments
        process.standardOutput = pipe
        
        if #available(OSX 10.13, *) {
            process.executableURL = URL(fileURLWithPath: command)
            try process.run()
        } else {
            process.launchPath = command
            process.launch()
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        return output
    }
}
