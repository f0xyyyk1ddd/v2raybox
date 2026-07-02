import Foundation
import Cocoa

class VPNManager {
    static let shared = VPNManager()

    private var process: Process?

    private func generateConfig(for profile: Profile) -> String {
        var outboundJson = ""

        switch profile.protocolName {
        case "vless":
            outboundJson = """
            {
                "type": "vless",
                "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "uuid": "\(profile.uuid ?? "")",
                "tls": {
                    "enabled": true,
                    "server_name": "\(profile.sni ?? profile.address)"
                }
            }
            """
        case "trojan":
            outboundJson = """
            {
                "type": "trojan",
                "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "password": "\(profile.password ?? "")",
                "tls": {
                    "enabled": true,
                    "server_name": "\(profile.sni ?? profile.address)"
                }
            }
            """
        default: // hysteria, hysteria2
            outboundJson = """
            {
                "type": "\(profile.protocolName)",
                "tag": "proxy",
                "server": "\(profile.address)",
                "server_port": \(profile.port),
                "up_mbps": 100,
                "down_mbps": 100,
                "auth_str": "\(profile.password ?? "")",
                "tls": {
                    "enabled": true,
                    "server_name": "\(profile.sni ?? profile.address)",
                    "insecure": false
                }
            }
            """
        }

        return """
        {
            "log": { "level": "info" },
            "dns": {
                "servers": [
                    { "address": "8.8.8.8", "detour": "direct" }
                ]
            },
            "inbounds": [{
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "utun233",
                "inet4_address": "172.19.0.1/30",
                "auto_route": true,
                "strict_route": true,
                "stack": "system",
                "sniff": true
            }],
            "outbounds": [
                \(outboundJson),
                { "type": "direct", "tag": "direct" }
            ],
            "route": {
                "rules": [
                    { "protocol": "dns", "outbound": "direct" }
                ],
                "auto_detect_interface": true
            }
        }
        """
    }

    func startVPN(profile: Profile) {
        stopVPN() // на всякий случай убиваем старый процесс

        let configString = generateConfig(for: profile)
        let configPath = "/tmp/v2raybox_config.json"

        guard let configData = configString.data(using: .utf8) else { return }
        guard FileManager.default.createFile(atPath: configPath, contents: configData) else { return }

        guard let corePath = Bundle.main.path(forResource: "sing-box", ofType: nil) else {
            showAlert("sing-box не найден в пакете приложения!")
            return
        }

        // Снимаем карантин и выдаём права один раз
        let setupScript = "xattr -cr '\(corePath)'; chmod +x '\(corePath)'"
        var setupError: NSDictionary?
        if let script = NSAppleScript(source: "do shell script \"\(setupScript)\" with administrator privileges") {
            script.executeAndReturnError(&setupError)
        }

        // Запускаем sing-box как дочерний процесс Swift (не через shell)
        // Он будет жить всё время работы нашего приложения
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: corePath)
        proc.arguments = ["run", "-c", configPath]

        // Логируем в файл
        let logUrl = URL(fileURLWithPath: "/tmp/sing-box.log")
        FileManager.default.createFile(atPath: logUrl.path, contents: nil)
        if let logHandle = try? FileHandle(forWritingTo: logUrl) {
            proc.standardOutput = logHandle
            proc.standardError = logHandle
        }
        proc.standardInput = FileHandle.nullDevice

        proc.terminationHandler = { p in
            DispatchQueue.main.async {
                print("sing-box exited with code: \(p.terminationStatus)")
            }
        }

        do {
            try proc.run()
            self.process = proc
            print("sing-box started with PID: \(proc.processIdentifier)")
        } catch {
            showAlert("Не удалось запустить sing-box: \(error.localizedDescription)")
        }
    }

    func stopVPN() {
        process?.terminate()
        process = nil
        // На случай если остался зомби от прошлого запуска
        let killScript = "killall sing-box 2>/dev/null; true"
        var err: NSDictionary?
        NSAppleScript(source: "do shell script \"\(killScript)\" with administrator privileges")?.executeAndReturnError(&err)
    }

    private func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "V2RayBox"
            alert.informativeText = message
            alert.runModal()
        }
    }
}
