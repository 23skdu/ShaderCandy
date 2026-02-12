//
//  ShaderCandyInstaller.swift
//  ShaderCandy Installer
//
//  Installation backend logic
//

import Foundation

enum InstallLocation {
    case user
    case system
}

struct InstallOptions {
    var createDesktopShortcut: Bool = false
    var installLaunchAgent: Bool = false
    var openPreferences: Bool = true
}

class ShaderCandyInstaller {
    let location: InstallLocation
    let options: InstallOptions
    var progressHandler: ((Double, String) -> Void)?
    
    private var sourcePath: String
    private var destinationPath: String
    
    init(location: InstallLocation, options: InstallOptions) {
        self.location = location
        self.options = options
        
        // Determine paths
        if let bundlePath = Bundle.main.resourcePath {
            self.sourcePath = bundlePath + "/ShaderCandy.saver"
        } else {
            self.sourcePath = FileManager.default.currentDirectoryPath + "/ShaderCandy.saver"
        }
        
        switch location {
        case .user:
            self.destinationPath = NSHomeDirectory() + "/Library/Screen Savers/ShaderCandy.saver"
        case .system:
            self.destinationPath = "/Library/Screen Savers/ShaderCandy.saver"
        }
    }
    
    func install() throws {
        var progress: Double = 0
        
        // Step 1: Validate source
        progressHandler?(progress, "Validating installation package...")
        try validateSource()
        progress = 0.1
        
        // Step 2: Create destination directory
        progressHandler?(progress, "Creating destination directory...")
        try createDestination()
        progress = 0.2
        
        // Step 3: Copy screensaver bundle
        progressHandler?(progress, "Installing ShaderCandy...")
        try copyBundle()
        progress = 0.6
        
        // Step 4: Set permissions
        progressHandler?(progress, "Setting permissions...")
        try setPermissions()
        progress = 0.7
        
        // Step 5: Create desktop shortcut
        if options.createDesktopShortcut {
            progressHandler?(progress, "Creating desktop shortcut...")
            try createDesktopShortcut()
        }
        progress = 0.8
        
        // Step 6: Install LaunchAgent
        if options.installLaunchAgent {
            progressHandler?(progress, "Installing LaunchAgent...")
            try installLaunchAgent()
        }
        progress = 0.9
        
        // Step 7: Complete
        progressHandler?(1.0, "Installation complete!")
        progress = 1.0
        
        // Step 8: Open preferences if requested
        if options.openPreferences {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-ScreenSaver")!)
            }
        }
    }
    
    private func validateSource() throws {
        let fileManager = FileManager.default
        
        // Check if source exists
        if !fileManager.fileExists(atPath: sourcePath) {
            throw InstallerError.sourceNotFound(sourcePath)
        }
        
        // Check if it's a valid bundle
        let infoPlistPath = sourcePath + "/Contents/Info.plist"
        if !fileManager.fileExists(atPath: infoPlistPath) {
            throw InstallerError.invalidBundle
        }
    }
    
    private func createDestination() throws {
        let fileManager = FileManager.default
        
        switch location {
        case .user:
            let userSaversPath = NSHomeDirectory() + "/Library/Screen Savers"
            if !fileManager.fileExists(atPath: userSaversPath) {
                try fileManager.createDirectory(atPath: userSaversPath, withIntermediateDirectories: true)
            }
            
        case .system:
            let systemSaversPath = "/Library/Screen Savers"
            
            // Check if we have permission
            if !fileManager.isWritableFile(atPath: systemSaversPath) {
                // Need to use admin privileges
                let script = """
                do shell script "mkdir -p \\"/Library/Screen Savers\\"" with administrator privileges
                """
                let process = Process()
                process.launchPath = "/usr/bin/osascript"
                process.arguments = ["-e", script]
                try process.run()
                process.waitUntilExit()
            }
        }
    }
    
    private func copyBundle() throws {
        let fileManager = FileManager.default
        
        // Remove existing installation
        if fileManager.fileExists(atPath: destinationPath) {
            try fileManager.removeItem(atPath: destinationPath)
        }
        
        // Copy bundle
        try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
    }
    
    private func setPermissions() throws {
        let fileManager = FileManager.default
        let bundlePath = destinationPath
        
        // Set permissions on the bundle
        let permissionsScript = """
        chmod -R a+rX \"\(bundlePath)\"
        chown -R \\(id -un):staff \"\(bundlePath)\"
        """
        
        if location == .system {
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = ["-c", permissionsScript]
            try process.run()
            process.waitUntilExit()
        }
    }
    
    private func createDesktopShortcut() throws {
        let fileManager = FileManager.default
        let desktopPath = NSHomeDirectory() + "/Desktop/ShaderCandy.saver"
        
        if fileManager.fileExists(atPath: desktopPath) {
            try fileManager.removeItem(atPath: desktopPath)
        }
        
        // Create alias
        let bookmarkData = try destinationPath.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let aliasFile = desktopPath + " Alias"
        try fileManager.createSymlink(atPath: aliasFile, withDestinationPath: destinationPath)
    }
    
    private func installLaunchAgent() throws {
        let fileManager = FileManager.default
        let launchAgentsPath = NSHomeDirectory() + "/Library/LaunchAgents"
        
        // Create LaunchAgents directory if needed
        if !fileManager.fileExists(atPath: launchAgentsPath) {
            try fileManager.createDirectory(atPath: launchAgentsPath, withIntermediateDirectories: true)
        }
        
        let plistPath = launchAgentsPath + "/com.shadercandy.screensaver.plist"
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.shadercandy.screensaver</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>-a</string>
                <string>ScreenSaverEngine</string>
            </array>
            <key>RunAtLoad</key>
            <false/>
            <key>StartInterval</key>
            <integer>300</integer>
        </dict>
        </plist>
        """
        
        try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Error Types

enum InstallerError: Error, LocalizedError {
    case sourceNotFound(String)
    case invalidBundle
    case copyFailed(String)
    case permissionDenied(String)
    case installationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sourceNotFound(let path):
            return "Installation package not found at: \(path)"
        case .invalidBundle:
            return "The installation package is corrupted or invalid."
        case .copyFailed(let message):
            return "Failed to copy files: \(message)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .installationFailed(let message):
            return "Installation failed: \(message)"
        }
    }
}
