import Foundation
import Cocoa

class VPNManager {
    static let shared = VPNManager()

    private let configPath   = "/tmp/v2raybox_config.json"
    private let tmpPlistPath = "/tmp/com.v2raybox.singbox.plist"
    private let sysPlistPath = "/Library/LaunchDaemons/com.v2raybox.singbox.plist"

    private func generateConfig(for profile: Profile) -> String {
        var outbound = ""
        switch profile.protocolName {
        case "vless":
            outbound = """
            {
                "type": "vless", "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "uuid": "\(profile.uuid ?? "")",
                "tls": { "enabled": true, "server_name": "\(profile.sni ?? profile.address)" }
            }
            """
        case "trojan":
            outbound = """
            {
                "type": "trojan", "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "password": "\(profile.password ?? "")",
                "tls": { "enabled": true, "server_name": "\(profile.sni ?? profile.address)" }
            }
            """
        default:
            outbound = """
            {
                "type": "\(profile.protocolName)", "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "up_mbps": 100, "down_mbps": 100,
                "auth_str": "\(profile.password ?? "")",
                "tls": { "enabled": true, "server_name": "\(profile.sni ?? profile.address)", "insecure": false }
            }
            """
        }
        return """
        {
            "log": { "level": "info" },
            "dns": { "servers": [{ "address": "8.8.8.8", "detour": "direct" }] },
            "inbounds": [{
                "type": "tun", "tag": "tun-in",
                "interface_name": "utun233",
                "inet4_address": "172.19.0.1/30",
                "auto_route": true, "strict_route": true,
                "stack": "system", "sniff": true
            }],
            "outbounds": [
                \(outbound),
                { "type": "direct", "tag": "direct" }
            ],
            "route": {
                "rules": [{ "protocol": "dns", "outbound": "direct" }],
                "auto_detect_interface": true
            }
        }
        """
    }

    private func generatePlist(corePath: String) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.v2raybox.singbox</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(corePath)</string>
                <string>run</string>
                <string>-c</string>
                <string>\(configPath)</string>
            </array>
            <key>RunAtLoad</key>
            <false/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/sing-box.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/sing-box.log</string>
        </dict>
        </plist>
        """
    }

    func startVPN(profile: Profile) {
        guard let corePath = Bundle.main.path(forResource: "sing-box", ofType: nil) else {
            showAlert("sing-box не найден в пакете!\nПуть: \(Bundle.main.bundlePath)"); return
        }

        // Swift пишет файлы в /tmp — никаких прав root не нужно
        do {
            try generateConfig(for: profile).write(toFile: configPath, atomically: true, encoding: .utf8)
            try generatePlist(corePath: corePath).write(toFile: tmpPlistPath, atomically: true, encoding: .utf8)
        } catch {
            showAlert("Ошибка записи файлов: \(error)"); return
        }

        // AppleScript выполняет ТОЛЬКО простые команды — никакого экранирования!
        let script = """
        do shell script "xattr -cr '\(corePath)' && chmod +x '\(corePath)' && launchctl unload '\(sysPlistPath)' 2>/dev/null; cp '\(tmpPlistPath)' '\(sysPlistPath)' && launchctl load '\(sysPlistPath)'" with administrator privileges
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let s = NSAppleScript(source: script) {
                s.executeAndReturnError(&error)
                if let err = error {
                    let msg = (err["NSAppleScriptErrorMessage"] as? String) ?? "\(err)"
                    DispatchQueue.main.async { self.showAlert("Ошибка запуска:\n\(msg)") }
                }
            }
        }
    }

    func stopVPN() {
        let script = """
        do shell script "launchctl unload '\(sysPlistPath)' 2>/dev/null; rm -f '\(sysPlistPath)'" with administrator privileges
        """
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }

    private func showAlert(_ msg: String) {
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "V2RayBox"
            a.informativeText = msg
            a.runModal()
        }
    }
}
