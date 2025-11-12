//
//  TrollFoolsApp.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import CocoaLumberjackSwift

@main
struct TrollFoolsApp: SwiftUI.App {

    @AppStorage("isDisclaimerHidden")
    var isDisclaimerHidden: Bool = false

    init() {
        Self.configureSharedLogger()
        try? FileManager.default.removeItem(at: InjectorV3.temporaryRoot)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isDisclaimerHidden {
                    AppListView()
                        .environmentObject(AppListModel())
                        .transition(.opacity)
                } else {
                    DisclaimerView(isDisclaimerHidden: $isDisclaimerHidden)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isDisclaimerHidden)
        }
    }

    private static var didConfigureLogger = false

    private static func configureSharedLogger() {
        guard !didConfigureLogger else { return }
        didConfigureLogger = true

        let fileLogger: DDFileLogger? = {
            guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return nil
            }

            let logsDirectory = cachesDirectory
                .appendingPathComponent(gTrollFoolsIdentifier, isDirectory: true)
                .appendingPathComponent("SharedLogs", isDirectory: true)

            try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

            let fileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory.path)
            let logger = DDFileLogger(logFileManager: fileManager)
            logger.rollingFrequency = 60 * 60 * 24
            logger.logFileManager.maximumNumberOfLogFiles = 7
            logger.doNotReuseLogFiles = true
            logger.logFormatter = ChinaTimeZoneLogFormatter.shared
            return logger
        }()

        if let fileLogger {
            DDLog.add(fileLogger)
        }

        DDOSLogger.sharedInstance.logFormatter = ChinaTimeZoneLogFormatter.shared
        DDLog.add(DDOSLogger.sharedInstance)
    }
}
