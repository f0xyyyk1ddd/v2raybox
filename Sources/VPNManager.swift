import Foundation
import Cocoa

class VPNManager {
    static let shared = VPNManager()
    
    private var process: Process?
    
    // Generates sing-box config JSON string
    private func generateConfig(for profile: Profile) -> String {
        let tunInbound = """
        {
            "type": "tun",
            "tag": "tun-in",
            "interface_name": "utun233",
            "inet4_address": "172.19.0.1/30",
            "auto_route": true,
            "strict_route": true,
            "stack": "system",
            "sniff": true
        }
        """
        
        var outbounds = ""
        
        if profile.protocolName == "vless" {
            outbounds = """
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
        } else if profile.protocolName.hasPrefix("hysteria") {
            outbounds = """
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
        } else if profile.protocolName == "trojan" {
            outbounds = """
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
        }
        
        let config = """
        {
            "log": {
                "level": "info"
            },
            "dns": {
                "servers": [
                    {
                        "address": "8.8.8.8",
                        "detour": "direct"
                    }
                ]
            },
            "inbounds": [
                \(tunInbound)
            ],
            "outbounds": [
                \(outbounds),
                {
                    "type": "direct",
                    "tag": "direct"
                }
            ],
            "route": {
                "rules": [
                    {
                        "protocol": "dns",
                        "outbound": "direct"
                    }
                ],
                "auto_detect_interface": true
            }
        }
        """
        
        return config
    }
    
    func startVPN(profile: Profile) {
        let configString = generateConfig(for: profile)
        let configPath = "/tmp/v2raybox_config.json"
        
        do {
            try configString.write(toFile: configPath, atomically: true, encoding: .utf8)
            
            let corePath = Bundle.main.path(forResource: "sing-box", ofType: nil) ?? "/usr/local/bin/sing-box"
            
            // Снимаем карантин, даем права на исполнение и запускаем через nohup отвязанным от shell-сессии
            let script = "do shell script \"xattr -cr '\(corePath)'; chmod +x '\(corePath)'; nohup '\(corePath)' run -c '\(configPath)' > /tmp/sing-box.log 2>&1 </dev/null &\" with administrator privileges"
            
            DispatchQueue.global(qos: .background).async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&error)
                    if let err = error {
                        print("Failed to start VPN: \(err)")
                    }
                }
            }
            
        } catch {
            print("Failed to write config: \(error)")
        }
    }
    
    func stopVPN() {
        // Убиваем процесс
        let script = "do shell script \"killall sing-box\" with administrator privileges"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}
