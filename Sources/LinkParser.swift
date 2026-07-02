import Foundation

struct Profile: Codable {
    let name: String
    let protocolName: String
    let address: String
    let port: Int
    let uuid: String?
    let password: String?
    let sni: String?
}

class LinkParser {
    static func parse(link: String) -> Profile? {
        guard let url = URL(string: link) else { return nil }
        
        let protocolName = url.scheme ?? ""
        let address = url.host ?? ""
        let port = url.port ?? 443
        let name = url.fragment ?? url.host ?? "Unknown"
        
        var uuid: String? = nil
        var password: String? = nil
        var sni: String? = nil
        
        if protocolName == "vless" {
            uuid = url.user
            sni = getQueryItemValue(url: url, name: "sni")
        } else if protocolName.hasPrefix("hysteria") {
            password = url.user
            sni = getQueryItemValue(url: url, name: "sni")
        } else if protocolName == "trojan" {
            password = url.user
            sni = getQueryItemValue(url: url, name: "sni")
        } else {
            return nil
        }
        
        return Profile(
            name: name,
            protocolName: protocolName,
            address: address,
            port: port,
            uuid: uuid,
            password: password,
            sni: sni
        )
    }
    
    private static func getQueryItemValue(url: URL, name: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == name })?.value
    }
}
