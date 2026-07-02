import Foundation
import Cocoa

class VPNManager {
    static let shared = VPNManager()

    private let plistPath = "/Library/LaunchDaemons/com.v2raybox.singbox.plist"
    private let configPath = "/tmp/v2raybox_config.json"

    private func generateConfig(for profile: Profile) -> String {
        var outboundJson = ""
        switch profile.protocolName {
        case "vless":
            outboundJson = """
            {
                "type": "vless", "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "uuid": "\(profile.uuid ?? "")",
                "tls": { "enabled": true, "server_name": "\(profile.sni ?? profile.address)" }
            }
            """
        case "trojan":
            outboundJson = """
            {
                "type": "trojan", "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "password": "\(profile.password ?? "")",
                "tls": { "enabled": true, "server_name": "\(profile.sni ?? profile.address)" }
            }
            """
        default: // hysteria, hysteria2
            outboundJson = """
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
            "dns": {
                "servers": [{ "address": "8.8.8.8", "detour": "direct" }]
            },
            "inbounds": [{
                "type": "tun", "tag": "tun-in",
                "interface_name": "utun233",
                "inet4_address": "172.19.0.1/30",
                "auto_route": true, "strict_route": true,
                "stack": "system", "sniff": true
            }],
            "outbounds": [
                \(outboundJson),
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
            showAlert("Ядро sing-box не найдено в пакете приложения!")
            return
        }

        // Записываем конфиг
        try? generateConfig(for: profile).write(toFile: configPath, atomically: true, encoding: .utf8)

        // Формируем содержимое plist
        let plistContent = generatePlist(corePath: corePath)
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        // Один AppleScript делает всё:
        // 1. Снимает карантин и выдаёт права на исполнение
        // 2. Пишет plist в LaunchDaemons
        // 3. Выгружает старый (если был) и загружает новый
        let script = """
        do shell script "xattr -cr '\(corePath)'; chmod +x '\(corePath)'; printf '%s' \\"\(plistContent)\\" > '\(plistPath)'; launchctl unload '\(plistPath)' 2>/dev/null; launchctl load '\(plistPath)'" with administrator privileges
        """

        DispatchQueue.global(qos: .background).async {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if let err = error {
                    DispatchQueue.main.async {
                        self.showAlert("Ошибка запуска: \(err["NSAppleScriptErrorMessage"] ?? err)")
                    }
                }
            }
        }
    }

    func stopVPN() {
        let script = "do shell script \"launchctl unload '\(plistPath)' 2>/dev/null; rm -f '\(plistPath)'\" with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }

    private func showAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "V2RayBox"
        alert.informativeText = message
        alert.runModal()
    }
}
