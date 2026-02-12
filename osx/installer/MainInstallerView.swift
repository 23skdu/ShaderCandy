//
//  MainInstallerView.swift
//  ShaderCandy Installer
//
//  GUI installer with installation options
//

import SwiftUI
import UniformTypeIdentifiers

struct MainInstallerView: View {
    @State private var selectedTab = 0
    @State private var installLocation: InstallLocation = .user
    @State private var installOptions: InstallOptions = InstallOptions()
    @State private var isInstalling = false
    @State private var installProgress: Double = 0
    @State private var installStatus: String = ""
    @State private var showCompletion = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
            
            // Content
            if isInstalling {
                InstallingView(progress: $installProgress, status: $installStatus)
            } else if showCompletion {
                CompletionView(location: installLocation)
            } else {
                // Tab selection
                HStack(spacing: 0) {
                    TabButton(title: "Welcome", icon: "sparkles", number: 0, selected: $selectedTab)
                    TabButton(title: "Options", icon: "slider.horizontal.3", number: 1, selected: $selectedTab)
                    TabButton(title: "Readme", icon: "doc.text", number: 2, selected: $selectedTab)
                    TabButton(title: "License", icon: "doc.plaintext", number: 3, selected: $selectedTab)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Divider()
                
                // Tab content
                TabView(selection: $selectedTab) {
                    WelcomeView()
                        .tag(0)
                    OptionsView(location: $installLocation, options: $installOptions)
                        .tag(1)
                    ReadmeView()
                        .tag(2)
                    LicenseView()
                        .tag(3)
                }
                .frame(maxHeight: 300)
                
                Divider()
                
                // Footer with actions
                FooterView(
                    selectedTab: selectedTab,
                    isInstalling: isInstalling,
                    onInstall: startInstallation,
                    onQuit: NSApplication.shared.terminate
                )
            }
        }
        .frame(width: 600, height: 500)
        .alert("Installation Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startInstallation() {
        isInstalling = true
        installProgress = 0
        installStatus = "Preparing installation..."
        
        // Run installation in background
        DispatchQueue.global(qos: .userInitiated).async {
            let installer = ShaderCandyInstaller(
                location: installLocation,
                options: installOptions
            )
            
            installer.progressHandler = { progress, status in
                DispatchQueue.main.async {
                    self.installProgress = progress
                    self.installStatus = status
                }
            }
            
            do {
                try installer.install()
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.showCompletion = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let number: Int
    @Binding var selected: Int
    
    var body: some View {
        Button(action: { selected = number }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selected == number ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected == number ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header View

struct HeaderView: View {
    var body: some View {
        HStack(spacing: 16) {
            // App icon
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 64, height: 64)
                .scaledToFit()
                .shadow(radius: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ShaderCandy Installer")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 48))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .pink, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Welcome to ShaderCandy")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("ShaderCandy is a collection of stunning visual shaders for your macOS screensaver. This installer will help you set it up on your system.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            HStack(spacing: 24) {
                FeatureItem(icon: "star.fill", title: "Beautiful Shaders", color: .yellow)
                FeatureItem(icon: "bolt.fill", title: "GPU Accelerated", color: .blue)
                FeatureItem(icon: "checkmark.shield.fill", title: "Safe & Secure", color: .green)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Options View

struct OptionsView: View {
    @Binding var location: InstallLocation
    @Binding var options: InstallOptions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Installation Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Installation Location")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    LocationOption(
                        title: "Just for Me",
                        subtitle: "Install in your user folder",
                        isSelected: location == .user,
                        action: { location = .user }
                    )
                    
                    LocationOption(
                        title: "All Users",
                        subtitle: "Install system-wide (requires admin)",
                        isSelected: location == .system,
                        action: { location = .system }
                    )
                }
            }
            
            // Additional Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    ToggleOption(
                        title: "Create Desktop Shortcut",
                        isOn: $options.createDesktopShortcut
                    )
                    
                    ToggleOption(
                        title: "Install LaunchAgent for Auto-Start",
                        subtitle: "Automatically start screensaver at login",
                        isOn: $options.installLaunchAgent
                    )
                    
                    ToggleOption(
                        title: "Open System Preferences After Installation",
                        isOn: $options.openPreferences
                    )
                }
            }
            
            Spacer()
        }
        .padding(20)
    }
}

struct LocationOption: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .fill(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct ToggleOption: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Readme View

struct ReadmeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("About ShaderCandy")
                    .font(.headline)
                
                Text("ShaderCandy provides a collection of beautiful, GPU-accelerated shaders for your macOS screensaver. Each shader is hand-crafted to provide stunning visual effects.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Features")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "cpu", text: "GPU-accelerated rendering using Apple Metal")
                    FeatureRow(icon: "paintpalette", text: "20+ unique shader effects")
                    FeatureRow(icon: "slider.horizontal.3", text: "Customizable parameters (speed, intensity, colors)")
                    FeatureRow(icon: "bolt.fill", text: "Optimized for Apple Silicon")
                }
                
                Text("Getting Started")
                    .font(.headline)
                
                Text("After installation, open System Preferences > Desktop & Screen Saver and select ShaderCandy from the list of screensavers.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - License View

struct LicenseView: View {
    var body: some View {
        ScrollView {
            Text("""
                MIT License
                
                Copyright (c) 2024 ShaderCandy Contributors
                
                Permission is hereby granted, free of charge, to any person obtaining a copy
                of this software and associated documentation files (the "Software"), to deal
                in the Software without restriction, including without limitation the rights
                to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                copies of the Software, and to permit persons to whom the Software is
                furnished to do so, subject to the following conditions:
                
                The above copyright notice and this permission notice shall be included in all
                copies or substantial portions of the Software.
                
                THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
                SOFTWARE.
                """)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(20)
        }
    }
}

// MARK: - Installing View

struct InstallingView: View {
    @Binding var progress: Double
    @Binding var status: String
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .scaleEffect(y: 2)
            
            Text(status)
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("\(Int(progress * 100))%")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(40)
    }
}

// MARK: - Completion View

struct CompletionView: View {
    let location: InstallLocation
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Installation Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("ShaderCandy has been installed \(location == .user ? "for your user account" : "system-wide").")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button(action: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/Library/Screen Savers"))
                }) {
                    Label("Open Screensavers", systemImage: "folder")
                }
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-ScreenSaver")!)
                }) {
                    Label("System Preferences", systemImage: "gear")
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
        .padding(40)
    }
}

// MARK: - Footer View

struct FooterView: View {
    let selectedTab: Int
    let isInstalling: Bool
    let onInstall: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onQuit) {
                Text("Quit")
            }
            .keyboardShortcut(.escape, modifiers: [])
            
            Spacer()
            
            if selectedTab < 3 {
                Button(action: onInstall) {
                    Text("Install")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.returnKey, modifiers: [])
            }
        }
        .padding(16)
        .background(
            Color(NSColor.windowBackgroundColor)
        )
    }
}

// MARK: - App Entry Point

@main
struct ShaderCandyInstallerApp: App {
    var body: some Scene {
        WindowGroup {
            MainInstallerView()
                .windowStyle(.hiddenTitleBar)
                .fixedSize(600, 500)
        }
        .windowResizability(.contentSize)
    }
}
