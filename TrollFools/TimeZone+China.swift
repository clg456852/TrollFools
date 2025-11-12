import Foundation

extension TimeZone {
    static let trollFoolsChina: TimeZone = {
        if let tz = TimeZone(identifier: "Asia/Shanghai") {
            return tz
        }
        return TimeZone(secondsFromGMT: 8 * 3600) ?? TimeZone.current
    }()
}


