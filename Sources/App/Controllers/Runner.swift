import Foundation
import Vapor
import TSCBasic

struct Runner {
    private let parameter: Parameter

    init(parameter: ExecutionRequestParameter) throws {
        self.parameter = try Parameter(parameter: parameter)
    }

    func run(
        application app: Application,
        onComplete: @escaping (ExecutionResponse) -> Void,
        onTimeout: @escaping (ExecutionResponse) -> Void
    ) throws {
        let command = parameter.command
        let options = parameter.options
        let timeout = parameter.timeout
        let nonce = parameter.nonce
        let envVars = parameter.environment
        let code = parameter.code

        let sandboxPath = URL(fileURLWithPath: "\(app.directory.resourcesDirectory)Sandbox")
        let random = UUID().uuidString
        let directory = "\(nonce)_\(random)"
        let temporaryPath = URL(fileURLWithPath: "\(app.directory.resourcesDirectory)Temp/\(directory)")
        WorkingDirectoryRegistry.shared.register(prefix: nonce, path: temporaryPath)

        let fileManager = FileManager()
        do {
            try fileManager.copyItem(at: sandboxPath, to: temporaryPath)
            try """
                import Glibc
                setbuf(stdout, nil)

                /* Start user code. Do not edit comment generated here */
                \(code)
                /* End user code. Do not edit comment generated here */
                """
                .data(using: .utf8)?
                .write(to: temporaryPath.appendingPathComponent("main.swift"))

            let process = Process(
                arguments: [
                    "sh", temporaryPath.appendingPathComponent("run.sh").path, [command, options].joined(separator: " ")
                ],
                environment: envVars
            )
            try process.launch()
        } catch {
            WorkingDirectoryRegistry.shared.remove(path: temporaryPath)
            try? fileManager.removeItem(at: temporaryPath)
            throw error
        }

        observe(workspace: temporaryPath, timeout: timeout, onComplete: onComplete, onTimeout: onTimeout)
    }

    private func observe(
        workspace path: URL, timeout: Int,
        onComplete: @escaping (ExecutionResponse) -> Void,
        onTimeout: @escaping (ExecutionResponse) -> Void
    ) {
        let interval = 0.2
        var counter: Double = 0
        let timer = DispatchSource.makeTimerSource()

        let completedPath = path.appendingPathComponent("completed")
        let stdoutPath = path.appendingPathComponent("stdout")
        let stderrPath = path.appendingPathComponent("stderr")
        let versionPath = path.appendingPathComponent("version")

        let fileManager = FileManager()
        timer.setEventHandler {
            counter += 1
            if let completed = try? String(contentsOf: completedPath) {
                let stderr = (try? String(contentsOf: stderrPath)) ?? ""
                let version = (try? String(contentsOf: versionPath)) ?? "N/A"

                onComplete(ExecutionResponse(output: completed, errors: stderr, version: version))

                WorkingDirectoryRegistry.shared.remove(path: path);
                try? fileManager.removeItem(at: path)
                timer.cancel()
            } else if interval * counter < Double(timeout) {
                return
            } else {
                let stdout = (try? String(contentsOf: stdoutPath)) ?? ""

                let stderr = "\((try? String(contentsOf: stderrPath)) ?? "")Maximum execution time of \(timeout) seconds exceeded.\n"
                let version = (try? String(contentsOf: versionPath)) ?? "N/A"

                onTimeout(ExecutionResponse(output: stdout, errors: stderr, version: version))

                WorkingDirectoryRegistry.shared.remove(path: path);
                try? fileManager.removeItem(at: path)
                timer.cancel()
            }
        }
        timer.schedule(deadline: .now() + .milliseconds(200), repeating: .milliseconds(200))
        timer.resume()
    }

    private struct Parameter {
        let toolchainVersion: String
        let command: String
        let options: String
        let timeout: Int
        let environment: [String: String]
        let code: String
        let nonce: String

        init(parameter: ExecutionRequestParameter) throws {
            var toolchainVersion = parameter.toolchain_version ?? stableVersion()
            if (toolchainVersion == "latest") {
                toolchainVersion = try! latestVersion();
            } else if (toolchainVersion == "stable") {
                toolchainVersion = stableVersion();
            }
            let command = parameter.command ?? "swift"
            let options = parameter.options ??
                (toolchainVersion ==
                    "nightly-main" ? "-Xfrontend -enable-experimental-concurrency" :
                 toolchainVersion.compare("5.3", options: .numeric) != .orderedAscending ?
                    "-I /app/_Packages/.build/release/ -L /app/_Packages/.build/release/ -l_Packages" : ""
                )
            let timeout = parameter.timeout ?? 3480 // Default timeout is 3480 seconds
            let color = parameter._color ?? false
            let nonce = parameter._nonce ?? ""

            var environment = ProcessEnv.vars
            environment["_COLOR"] = "\(color)"

            guard try availableVersions().contains(toolchainVersion) else {
                throw Abort(.badRequest)
            }

            guard ["swift", "swiftc"].contains(command) else {
                throw Abort(.badRequest)
            }

            // Security check
            if [";", "&", "&&", "||", "`", "(", ")", "#"].contains(where: { options.contains($0) }) {
                throw Abort(.badRequest)
            }

            guard let code = parameter.code else {
                throw Abort(.badRequest)
            }

            self.toolchainVersion = toolchainVersion
            self.command = command
            self.options = options
            self.timeout = timeout
            self.nonce = nonce
            self.environment = environment
            self.code = code
        }
    }
}
