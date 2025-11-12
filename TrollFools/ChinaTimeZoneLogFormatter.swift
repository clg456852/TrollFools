//
//  ChinaTimeZoneLogFormatter.swift
//  TrollFools
//
//  Created by ChatGPT on 2025/11/12.
//

import CocoaLumberjackSwift
import Foundation

final class ChinaTimeZoneLogFormatter: NSObject, DDLogFormatter {

    static let shared = ChinaTimeZoneLogFormatter()
    static let chinaTimeZone: TimeZone = .trollFoolsChina

    private let dateFormatterKey = "com.trollfools.logger.dateformatter"

    private func threadDateFormatter() -> DateFormatter {
        let threadDictionary = Thread.current.threadDictionary
        if let existing = threadDictionary[dateFormatterKey] as? DateFormatter {
            return existing
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss:SSS"
        formatter.timeZone = Self.chinaTimeZone

        threadDictionary[dateFormatterKey] = formatter
        return formatter
    }

    func format(message logMessage: DDLogMessage) -> String? {
        let timestamp = threadDateFormatter().string(from: logMessage.timestamp)
        let level: String

        switch logMessage.flag {
        case .error: level = "E"
        case .warning: level = "W"
        case .info: level = "I"
        case .debug: level = "D"
        default: level = "V"
        }

        let threadIdentifier = logMessage.threadName ?? logMessage.threadID
        let fileName = logMessage.fileName
        let function = logMessage.function ?? ""
        let line = logMessage.line

        if function.isEmpty {
            return "\(timestamp) [\(level)] [\(threadIdentifier)] \(fileName):\(line) - \(logMessage.message)"
        } else {
            return "\(timestamp) [\(level)] [\(threadIdentifier)] \(fileName).\(function):\(line) - \(logMessage.message)"
        }
    }
}

