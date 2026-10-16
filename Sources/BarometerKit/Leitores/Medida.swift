import Foundation

enum Medida {
    /// "12 MB/s", "840 KB/s", "0".
    static func velocidade(_ bytes: Double) -> String {
        if bytes < 1024 { return "0" }
        if bytes < 1_048_576 { return "\(Int(bytes / 1024)) KB/s" }
        let mb = bytes / 1_048_576
        return (mb < 10 ? decimal(mb) : "\(Int(mb.rounded()))") + " MB/s"
    }

    /// "45 min", "3 h", "2 d 5 h".
    static func duracao(_ segundos: TimeInterval) -> String {
        let m = max(0, Int(segundos / 60))
        if m < 60 { return "\(m) min" }
        if m < 60 * 24 { return "\(m / 60) h" }
        return "\(m / 1440) d \(m / 60 % 24) h"
    }

    /// "460 GB", "1,2 TB".
    static func espaco(_ bytes: Double) -> String {
        let gb = bytes / 1_000_000_000
        if gb >= 1000 { return decimal(gb / 1000) + " TB" }
        return "\(Int(gb.rounded())) GB"
    }
}
