import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Installer Errors

enum PluginInstallerError: LocalizedError {
    case downloadFailed(String)
    case extractionFailed(String)
    case installationFailed(String)
    case authenticationCancelled

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let detail): return AppMessages.text(.installerDownloadFailed, detail)
        case .extractionFailed(let detail): return AppMessages.text(.installerExtractionFailed, detail)
        case .installationFailed(let detail): return AppMessages.text(.installerInstallationFailed, detail)
        case .authenticationCancelled: return AppMessages.text(.installerAuthenticationCancelled)
        }
    }
}

struct PluginInstallTransaction: Codable, Sendable {
    let id: UUID
    let licenseID: UUID?
    let bundleName: String
    let targetPath: String
    let backupRoot: String
    let backupPath: String
    let hadOriginal: Bool
}

// MARK: - Plugin Installer

actor PluginInstaller {
    private let fileManager = FileManager.default

    /// /Library/OFX/Plugins/ — shared, requires admin
    private let systemPluginPath = "/Library/OFX/Plugins"

    /// Temporary directory for downloads and extraction
    private var workingDirectory: URL {
        fileManager.temporaryDirectory.appendingPathComponent("MCAppsTools", isDirectory: true)
    }

    private var applicationSupportDirectory: URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseDirectory.appendingPathComponent("MCNexus", isDirectory: true)
    }

    private var transactionJournalURL: URL {
        applicationSupportDirectory.appendingPathComponent("InstallTransactions.json")
    }

    private func loadPendingTransactions() throws -> [PluginInstallTransaction] {
        guard fileManager.fileExists(atPath: transactionJournalURL.path) else { return [] }
        let data = try Data(contentsOf: transactionJournalURL)
        return try JSONDecoder().decode([PluginInstallTransaction].self, from: data)
    }

    private func savePendingTransactions(_ transactions: [PluginInstallTransaction]) throws {
        if transactions.isEmpty {
            if fileManager.fileExists(atPath: transactionJournalURL.path) {
                try fileManager.removeItem(at: transactionJournalURL)
            }
            return
        }

        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(transactions)
        try data.write(to: transactionJournalURL, options: .atomic)
    }

    private func recordPendingTransaction(_ transaction: PluginInstallTransaction) throws {
        var transactions = try loadPendingTransactions()
        transactions.removeAll { $0.id == transaction.id }
        transactions.append(transaction)
        try savePendingTransactions(transactions)
    }

    private func removePendingTransactions(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        let transactions = try loadPendingTransactions().filter { !ids.contains($0.id) }
        try savePendingTransactions(transactions)
    }

    // MARK: - Public API

    /// Extract a release archive or expand a macOS installer package to the working directory.
    func extractArchive(at archiveURL: URL) async throws -> URL {
        let extractDir = workingDirectory.appendingPathComponent("extracted-\(UUID().uuidString)")
        let isInstallerPackage = archiveURL.pathExtension.caseInsensitiveCompare("pkg") == .orderedSame
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        if !isInstallerPackage {
            try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
        }

        #if DEBUG
        print("[Installer] extractArchive archive=\(archiveURL.path) size=\(fileSize(at: archiveURL))")
        #endif

        let process = Process()
        if isInstallerPackage {
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/pkgutil")
            process.arguments = ["--expand-full", archiveURL.path, extractDir.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", archiveURL.path, extractDir.path]
        }

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            try? fileManager.removeItem(at: extractDir)
            #if DEBUG
            print("[Installer] archive extraction failed status=\(process.terminationStatus) error=\(errorMessage)")
            #endif
            throw PluginInstallerError.extractionFailed(errorMessage)
        }

        #if DEBUG
        print("[Installer] extractArchive output=\(extractDir.path) summary=\(directorySummary(at: extractDir))")
        debugDirectorySnapshot(extractDir, label: "extracted root")
        #endif

        return extractDir
    }

    /// Install OFX bundle to the system-wide plugin folder (requires admin)
    func installOFXBundle(from bundlePath: URL, bundleName: String) async throws {
        let transaction = try await installOFXBundleTransactional(from: bundlePath, bundleName: bundleName)
        commitInstallTransactions([transaction])
    }

    /// Install OFX bundle while keeping enough local state to roll back if a later step fails.
    func installOFXBundleTransactional(
        from bundlePath: URL,
        bundleName: String,
        licenseID: UUID? = nil
    ) async throws -> PluginInstallTransaction {
        let safeBundleName = try validatedOFXBundleName(bundleName)
        try validateInstallSource(bundlePath)
        let destination = "\(systemPluginPath)/\(safeBundleName)"
        let backupRoot = try applicationSupportDirectory
            .appendingPathComponent("InstallBackups", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path
        let backupPath = URL(fileURLWithPath: backupRoot)
            .appendingPathComponent("\(safeBundleName).bak", isDirectory: true)
            .path
        let transaction = PluginInstallTransaction(
            id: UUID(),
            licenseID: licenseID,
            bundleName: safeBundleName,
            targetPath: destination,
            backupRoot: backupRoot,
            backupPath: backupPath,
            hadOriginal: fileManager.fileExists(atPath: destination)
        )

        #if DEBUG
        print("[Installer] installOFXBundle source=\(bundlePath.path) destination=\(destination)")
        debugOFXBundle(bundlePath, label: "source")
        #endif

        #if os(macOS)
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: backupRoot).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try recordPendingTransaction(transaction)
        do {
            try await installWithPrivileges(
                source: bundlePath.path,
                destination: destination,
                backupRoot: backupRoot,
                backupPath: backupPath
            )
        } catch {
            if case PluginInstallerError.authenticationCancelled = error {
                try removePendingTransactions(ids: [transaction.id])
                throw error
            }
            do {
                try await rollbackWithPrivileges(transaction)
                try removePendingTransactions(ids: [transaction.id])
            } catch {
                throw PluginInstallerError.installationFailed(
                    "Installation failed and recovery is pending: \(error.localizedDescription)"
                )
            }
            throw error
        }
        #if DEBUG
        debugOFXBundle(URL(fileURLWithPath: destination), label: "installed destination")
        #endif
        #endif

        return transaction
    }

    func commitInstallTransactions(_ transactions: [PluginInstallTransaction]) {
        do {
            try removePendingTransactions(ids: Set(transactions.map(\.id)))
        } catch {
            #if DEBUG
            print("[Installer] could not commit transaction journal: \(error.localizedDescription)")
            #endif
            return
        }
        for transaction in transactions {
            try? fileManager.removeItem(atPath: transaction.backupRoot)
        }
    }

    func rollbackInstallTransactions(_ transactions: [PluginInstallTransaction]) async throws {
        for transaction in transactions.reversed() {
            try await rollbackWithPrivileges(transaction)
            try removePendingTransactions(ids: [transaction.id])
        }
    }

    func recoverPendingInstallTransactions(for licenseID: UUID) async throws {
        let transactions = try loadPendingTransactions()
            .filter { $0.licenseID == licenseID }
        for transaction in transactions.reversed() {
            try await rollbackWithPrivileges(transaction)
            try removePendingTransactions(ids: [transaction.id])
        }
    }

    /// Clean up temporary files
    func cleanup() {
        try? fileManager.removeItem(at: workingDirectory)
    }

    /// Find .ofx.bundle files in a directory
    func findOFXBundles(in directory: URL) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        var bundles: [URL] = []
        for item in contents {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { continue }

            if item.lastPathComponent.hasSuffix(".ofx.bundle") {
                try validateInstallSource(item)
                #if DEBUG
                print("[Installer] found OFX bundle=\(item.path)")
                debugOFXBundle(item, label: "found")
                #endif
                bundles.append(item)
            } else if values.isDirectory == true {
                bundles.append(contentsOf: try findOFXBundles(in: item))
            }
        }
        return bundles
    }

    private func validatedOFXBundleName(_ bundleName: String) throws -> String {
        let name = URL(fileURLWithPath: bundleName).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard name == bundleName,
              !name.isEmpty,
              name != ".",
              name != "..",
              name.hasSuffix(".ofx.bundle") else {
            throw PluginInstallerError.installationFailed("Invalid OFX bundle")
        }
        return name
    }

    private func fileSize(at url: URL) -> Int64 {
        let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        return size ?? -1
    }

    private func directorySummary(at url: URL) -> String {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return "unreadable"
        }

        var fileCount = 0
        var directoryCount = 0
        var byteCount: Int64 = 0

        for case let itemURL as URL in enumerator {
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
            if values?.isDirectory == true {
                directoryCount += 1
            }
            if values?.isRegularFile == true {
                fileCount += 1
                byteCount += Int64(values?.fileSize ?? 0)
            }
        }

        return "files=\(fileCount) directories=\(directoryCount) bytes=\(byteCount)"
    }

    #if DEBUG
    private func debugDirectorySnapshot(_ url: URL, label: String, limit: Int = 30) {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("[Installer] \(label) snapshot unreadable path=\(url.path)")
            return
        }

        var printed = 0
        for case let itemURL as URL in enumerator {
            guard printed < limit else {
                print("[Installer] \(label) snapshot truncated after \(limit) items")
                return
            }
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
            let relativePath = itemURL.path.replacingOccurrences(of: url.path + "/", with: "")
            let kind = values?.isDirectory == true ? "dir" : "file"
            let size = values?.isRegularFile == true ? (values?.fileSize ?? -1) : -1
            print("[Installer] \(label) item \(kind) \(relativePath) size=\(size)")
            printed += 1
        }
    }

    private func debugOFXBundle(_ bundleURL: URL, label: String) {
        let infoURL = bundleURL.appendingPathComponent("Contents/Info.plist", isDirectory: false)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = bundleURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let executableName = bundleExecutableName(from: infoURL)
        let executableURL = executableName.map { macOSURL.appendingPathComponent($0, isDirectory: false) }
        let executableSize = executableURL.map { fileSize(at: $0) } ?? -1

        print("[Installer] OFX \(label) path=\(bundleURL.path)")
        print("[Installer] OFX \(label) summary=\(directorySummary(at: bundleURL))")
        print("[Installer] OFX \(label) Contents exists=\(fileManager.fileExists(atPath: contentsURL.path)) Info.plist size=\(fileSize(at: infoURL)) CFBundleExecutable=\(executableName ?? "-") executableSize=\(executableSize)")
        debugDirectorySnapshot(bundleURL, label: "OFX \(label)", limit: 40)
    }

    private func bundleExecutableName(from infoURL: URL) -> String? {
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any] else {
            return nil
        }
        return dictionary["CFBundleExecutable"] as? String
    }
    #endif

    private func validateInstallSource(_ bundleURL: URL) throws {
        let values = try bundleURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true,
              values.isSymbolicLink != true,
              bundleURL.lastPathComponent.hasSuffix(".ofx.bundle") else {
            throw PluginInstallerError.installationFailed("Invalid OFX bundle")
        }
    }

    // MARK: - Privileged Installation (macOS)

    #if os(macOS)
    private func appleScriptStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func installWithPrivileges(source: String, destination: String, backupRoot: String, backupPath: String) async throws {
        let escapedPluginPath = appleScriptStringLiteral(systemPluginPath)
        let escapedSource = appleScriptStringLiteral(source)
        let escapedDestination = appleScriptStringLiteral(destination)
        let escapedBackupRoot = appleScriptStringLiteral(backupRoot)
        let escapedBackupPath = appleScriptStringLiteral(backupPath)
        let script = """
        set pluginPath to "\(escapedPluginPath)"
        set sourcePath to "\(escapedSource)"
        set destinationPath to "\(escapedDestination)"
        set backupRootPath to "\(escapedBackupRoot)"
        set backupPath to "\(escapedBackupPath)"
        set commandText to "echo '[PrivilegedInstall] user='$(id -un)' uid='$(id -u); " & ¬
            "echo '[PrivilegedInstall] source before'; " & ¬
            "/usr/bin/stat -f '%HT %z %N' " & quoted form of sourcePath & " 2>&1; " & ¬
            "/usr/bin/find " & quoted form of sourcePath & " -maxdepth 4 -print 2>&1; " & ¬
            "/bin/mkdir -p " & quoted form of pluginPath & " && " & ¬
            "/bin/mkdir -p " & quoted form of backupRootPath & " && " & ¬
            "if [ -e " & quoted form of destinationPath & " ]; then /bin/rm -rf " & quoted form of backupPath & " && /bin/mv " & quoted form of destinationPath & " " & quoted form of backupPath & "; fi; " & ¬
            "/usr/bin/ditto --noqtn " & quoted form of sourcePath & " " & quoted form of destinationPath & "; " & ¬
            "status=$?; " & ¬
            "if [ $status -eq 0 ]; then /bin/chmod -R 755 " & quoted form of destinationPath & " 2>/dev/null; /usr/sbin/chown -R root:wheel " & quoted form of destinationPath & " 2>/dev/null; fi; " & ¬
            "if [ $status -ne 0 ]; then /bin/rm -rf " & quoted form of destinationPath & "; if [ -e " & quoted form of backupPath & " ]; then /bin/mv " & quoted form of backupPath & " " & quoted form of destinationPath & "; fi; /bin/rm -rf " & quoted form of backupRootPath & "; exit $status; fi; " & ¬
            "consoleUser=$(/usr/bin/stat -f %Su /dev/console 2>/dev/null); if [ x$consoleUser != x ] && [ x$consoleUser != xroot ]; then /usr/sbin/chown -R $consoleUser:staff " & quoted form of backupRootPath & " 2>/dev/null || true; fi; " & ¬
            "echo '[PrivilegedInstall] ditto status='$status; " & ¬
            "echo '[PrivilegedInstall] destination after'; " & ¬
            "if [ -e " & quoted form of destinationPath & " ]; then /usr/bin/stat -f '%HT %z %N' " & quoted form of destinationPath & " 2>&1; /usr/bin/find " & quoted form of destinationPath & " -maxdepth 4 -print 2>&1; else echo '[PrivilegedInstall] destination missing'; fi; " & ¬
            "exit $status"
        do shell script commandText with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorDict)
        #if DEBUG
        let output = result?.stringValue ?? ""
        if !output.isEmpty {
            print("[Installer] privileged output:\n\(output)")
        }
        #endif

        if let error = errorDict {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
            #if DEBUG
            print("[Installer] privileged error number=\(errorNumber) message=\(errorMessage)")
            #endif

            if errorNumber == -128 {
                throw PluginInstallerError.authenticationCancelled
            }
            throw PluginInstallerError.installationFailed(errorMessage)
        }
    }

    private func rollbackWithPrivileges(_ transaction: PluginInstallTransaction) async throws {
        let escapedDestination = appleScriptStringLiteral(transaction.targetPath)
        let escapedBackupRoot = appleScriptStringLiteral(transaction.backupRoot)
        let escapedBackupPath = appleScriptStringLiteral(transaction.backupPath)
        let hadOriginal = transaction.hadOriginal ? "true" : "false"
        let script = """
        set destinationPath to "\(escapedDestination)"
        set backupRootPath to "\(escapedBackupRoot)"
        set backupPath to "\(escapedBackupPath)"
        set commandText to "if [ -e " & quoted form of backupPath & " ]; then /bin/rm -rf " & quoted form of destinationPath & " && /bin/mv " & quoted form of backupPath & " " & quoted form of destinationPath & " && /usr/sbin/chown -R root:wheel " & quoted form of destinationPath & "; " & ¬
            "elif [ ! \(hadOriginal) ]; then /bin/rm -rf " & quoted form of destinationPath & "; fi; " & ¬
            "/bin/rm -rf " & quoted form of backupRootPath
        do shell script commandText with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        appleScript?.executeAndReturnError(&errorDict)

        if let error = errorDict {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1

            if errorNumber == -128 {
                throw PluginInstallerError.authenticationCancelled
            }
            throw PluginInstallerError.installationFailed(errorMessage)
        }
    }
    #endif

    // MARK: - Uninstall

    /// Remove an OFX bundle from the system-wide folder (requires admin)
    func uninstallOFXBundle(bundleName: String) async throws {
        let safeBundleName = try validatedOFXBundleName(bundleName)
        let path = "\(systemPluginPath)/\(safeBundleName)"

        guard fileManager.fileExists(atPath: path) else {
            return
        }

        #if os(macOS)
        let escapedPath = appleScriptStringLiteral(path)
        let script = """
        set bundlePath to "\(escapedPath)"
        do shell script "rm -rf " & quoted form of bundlePath with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var errorDict: NSDictionary?
        appleScript?.executeAndReturnError(&errorDict)

        if let error = errorDict {
            let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1

            if errorNumber == -128 {
                throw PluginInstallerError.authenticationCancelled
            }
            throw PluginInstallerError.installationFailed(errorMessage)
        }
        #endif
    }
}
