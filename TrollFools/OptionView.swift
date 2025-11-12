//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI
import UIKit
import CocoaLumberjackSwift

struct OptionView: View {
    let app: App
    // 添加URL常量
    private let debugDownloadURL = "https://dj-injection.oss-cn-hangzhou.aliyuncs.com/debug/testa.dylib"
    private let preDownloadURL = "https://dj-injection.oss-cn-hangzhou.aliyuncs.com/pre/testa.dylib"
    private let releaseDownloadURL = "https://dj-injection.oss-cn-hangzhou.aliyuncs.com/release/testa.dylib"

    @State var isImporterPresented = false
    @State var isImporterSelected = false

    @State var isWarningPresented = false
    @State var temporaryResult: Result<[URL], any Error>?

    @State var isSettingsPresented = false

    @State var importerResult: Result<[URL], any Error>?

    @AppStorage("isWarningHidden")
    var isWarningHidden: Bool = false

    init(_ app: App) {
        self.app = app
    }

    // 添加简单弹窗状态变量
    @State var isNoFileAlertPresented = false
    
    var body: some View {
        if #available(iOS 15, *) {
            content
                .alert(
                    "提示",
                    isPresented: $isWarningPresented,
                    presenting: temporaryResult
                ) { result in
                    Button {
                        importerResult = result
                        isImporterSelected = true
                    } label: {
                        Text("继续")
                    }
                    Button(role: .destructive) {
                        importerResult = result
                        isImporterSelected = true
                        isWarningHidden = true
                    } label: {
                        Text("继续且不再显示")
                    }
                    Button(role: .cancel) {
                        temporaryResult = nil
                        isWarningPresented = false
                    } label: {
                        Text("取消")
                    }
                } message: {
                    if case .success(let urls) = $0 {
                        Text(Self.warningMessage(urls))
                    }
                }
                // 添加简单的无文件弹窗
                .alert(
                    "提示",
                    isPresented: $isNoFileAlertPresented
                ) {
                    Button("确定") {
                        isNoFileAlertPresented = false
                    }
                } message: {
                    Text("无文件")
                }
        } else {
            content
        }
    }

    var content: some View {
        VStack(spacing: 80) {
            HStack {
                Spacer()

                Button {
                    Task {
                        do {
                            DDLogInfo("OptionView: 开始尝试使用本地文件注入", ddlog: .sharedInstance)
                            try await downloadAndInject()
                        } catch {
                            DDLogError("OptionView: 注入流程发生错误 \(error)", ddlog: .sharedInstance)
                            await MainActor.run {
                                importerResult = .failure(error)
                                isImporterSelected = true
                            }
                        }
                    }
                } label: {
                    OptionCell(option: .attach)
                }
                .accessibilityLabel(NSLocalizedString("Inject", comment: ""))

                Spacer()

                NavigationLink {
                    EjectListView(app)
                } label: {
                    OptionCell(option: .detach)
                }
                .accessibilityLabel(NSLocalizedString("Eject", comment: ""))

                Spacer()
            }
            // 新增文件状态显示
            Text(fileStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
            // 新增下载按钮
            Button {
                Task {
                    do {
                        let fileManager = FileManager.default
                        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
                        }
                        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
                        guard let downloadURL = URL(string: releaseDownloadURL) else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
                        }
                        
                        _ = try await downloadFile(from: downloadURL, to: fileURL)
                        
                        // 下载完成后的提示
                        await MainActor.run {
                            // 下载完成后更新文件状态
                            checkFileStatus()
                        }
                    } catch {
                        await MainActor.run {
                            importerResult = .failure(error)
                            isImporterSelected = true
                        }
                    }
                }
            } label: {
                Label("下载正式版", systemImage: "arrow.down.circle")
            }
            .disabled(isDownloading) // 下载时禁用按钮
            
            Button {
                isSettingsPresented = true
            } label: {
                Label(NSLocalizedString("Advanced Settings", comment: ""),
                      systemImage: "gear")
            }
            
            // pre 下载按钮
            Button {
                Task {
                    do {
                        let fileManager = FileManager.default
                        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
                        }
                        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
                        guard let downloadURL = URL(string: preDownloadURL) else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
                        }
                        
                        _ = try await downloadFile(from: downloadURL, to: fileURL)
                        
                        // 下载完成后的提示
                        await MainActor.run {
                            // 下载完成后更新文件状态
                            checkFileStatus()
                        }
                    } catch {
                        await MainActor.run {
                            importerResult = .failure(error)
                            isImporterSelected = true
                        }
                    }
                }
            } label: {
                Label("下载预发版", systemImage: "testtube.2")
            }
            .disabled(isDownloading) // 下载时禁用按钮
            
            // debug
            Button {
                Task {
                    do {
                        let fileManager = FileManager.default
                        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
                        }
                        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
                        guard let downloadURL = URL(string: debugDownloadURL) else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
                        }
                        
                        _ = try await downloadFile(from: downloadURL, to: fileURL)
                        
                        // 下载完成后的提示
                        await MainActor.run {
                            // 下载完成后更新文件状态
                            checkFileStatus()
                        }
                    } catch {
                        await MainActor.run {
                            importerResult = .failure(error)
                            isImporterSelected = true
                        }
                    }
                }
            } label: {
                Label("下载调试版", systemImage: "ladybug")
            }
            .disabled(isDownloading) // 下载时禁用按钮
        }
        .padding()
        .navigationTitle(app.name)
        .onAppear {
            checkFileStatus()
        }
        .onDisappear {
            // 清理任务，避免内存泄漏
            checkFileStatusTask?.cancel()
            checkFileStatusTask = nil
        }
        // 摇一摇查看日志
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
            Task {
                await presentLatestLogSheet()
            }
        }
        .background(Group {
            NavigationLink(isActive: $isImporterSelected) {
                if let result = importerResult {
                    switch result {
                    case .success(let urls):
                        InjectView(app, urlList: urls
                            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }))
                    case .failure(let error):
                        FailureView(
                            title: NSLocalizedString("Error", comment: ""),
                            error: error
                        )
                    }
                }
            } label: { }
        })
        // Remove the .fileImporter modifier here
        .sheet(isPresented: $isSettingsPresented) {
            if #available(iOS 16, *) {
                SettingsView(app)
                    .presentationDetents([.medium, .large])
            } else {
                SettingsView(app)
            }
        }
        // 日志面板
        .sheet(isPresented: $isLogsPresented) {
            if let latestLogURL {
                LogsView(url: latestLogURL)
            }
        }
        // 注入隐藏摇一摇探测器
        .background(ShakeDetectorRepresentable())
        .overlay {
            if isDownloading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text(downloadTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                            .tint(.white)
                        Text(String(format: "%.0f%%", downloadProgress * 100))
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)))
                }
            }
        }
    }

    static func warningMessage(_ urls: [URL]) -> String {
        guard let firstDylibName = urls.first(where: { $0.pathExtension.lowercased() == "deb" })?.lastPathComponent else {
            fatalError("No debian package found.")
        }
        return String(format: NSLocalizedString("You’ve selected at least one Debian Package “%@”. We’re here to remind you that it will not work as it was in a jailbroken environment. Please make sure you know what you’re doing.", comment: ""), firstDylibName)
    }

    // 新增：专门处理文件下载的函数
    private func downloadFile(from url: URL, to fileURL: URL) async throws -> Date? {
        // 确保下载状态在函数结束时总是被重置
        defer {
            Task { @MainActor in
                isDownloading = false
            }
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            downloadTitle = NSLocalizedString("Downloading…", comment: "")
        }
        
        // 确保目标目录存在
        let fileManager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        
        DDLogInfo("OptionView.downloadFile: 请求地址 \(url.absoluteString)", ddlog: .sharedInstance)
        let (byteStream, response) = try await URLSession.shared.bytes(from: url)
        if let httpResp = response as? HTTPURLResponse {
            let lm = httpResp.value(forHTTPHeaderField: "Last-Modified") ?? "nil"
            let etag = httpResp.value(forHTTPHeaderField: "ETag") ?? "nil"
            DDLogInfo("OptionView.downloadFile: 状态=\(httpResp.statusCode) 内容长度=\(response.expectedContentLength) Last-Modified=\(lm) ETag=\(etag)", ddlog: .sharedInstance)
        }
        
        // 解析 Last-Modified
        var lastModifiedDate: Date? = nil
        if let httpResp = response as? HTTPURLResponse,
           let lmStr = httpResp.value(forHTTPHeaderField: "Last-Modified") {
            let rfcFmt = DateFormatter()
            rfcFmt.locale = Locale(identifier: "en_US_POSIX")
            rfcFmt.dateFormat = "E, dd MMM yyyy HH:mm:ss z"
            rfcFmt.timeZone = TimeZone(abbreviation: "GMT")
            lastModifiedDate = rfcFmt.date(from: lmStr)
        }
        
        let expected = response.expectedContentLength
        var received: Int64 = 0
        var data = Data()
        var buffer = [UInt8]()
        buffer.reserveCapacity(8 * 1024) // 8 KB
        var lastReported: Double = 0
        let reportInterval: Double = 0.05 // 每提升 5% 刷新一次 UI
        
        for try await byte in byteStream {
            buffer.append(byte)
            received += 1
            
            // 若到达 8 KB 或已结束，写入 data
            if buffer.count >= 8 * 1024 {
                data.append(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
            
            if expected > 0 {
                let progress = Double(received) / Double(expected)
                if progress - lastReported >= reportInterval || progress == 1 {
                    lastReported = progress
                    await MainActor.run { downloadProgress = progress }
                }
            }
        }
        
        // 处理剩余缓冲区
        if !buffer.isEmpty {
            data.append(contentsOf: buffer)
        }
        
        try data.write(to: fileURL, options: .atomic)
        DDLogInfo("OptionView.downloadFile: 已写入文件 \(fileURL.lastPathComponent) 大小=\(data.count) 字节", ddlog: .sharedInstance)
        
        // 如果有 lastModifiedDate，将其设置为文件的创建时间
        if let lastModifiedDate = lastModifiedDate {
            // 直接使用服务器返回的时间，不进行时区转换
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: lastModifiedDate,
                .modificationDate: lastModifiedDate
            ]
            
            do {
                try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
            } catch {
                DDLogWarn("OptionView.downloadFile: 设置文件属性失败 \(error)", ddlog: .sharedInstance)
            }
        } else {
            DDLogWarn("OptionView.downloadFile: 服务端未提供 Last-Modified，改用系统时间戳", ddlog: .sharedInstance)
        }
        
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) {
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? -1
            let cdate = (attrs[.creationDate] as? Date)?.description ?? "nil"
            let mdate = (attrs[.modificationDate] as? Date)?.description ?? "nil"
            DDLogInfo("OptionView.downloadFile: 最终文件信息 size=\(size) 创建时间=\(cdate) 修改时间=\(mdate)", ddlog: .sharedInstance)
        }
        
        return lastModifiedDate
    }
    
    // 简化后的主函数：只处理本地文件获取和注入
    private func downloadAndInject() async throws {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
        }
        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
        
        // 检查本地文件是否存在
        if fileManager.fileExists(atPath: fileURL.path) {
            let selectedUrls = [fileURL]
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                let cdate = (attrs[.creationDate] as? Date)?.description ?? "nil"
                let mdate = (attrs[.modificationDate] as? Date)?.description ?? "nil"
                DDLogInfo("OptionView: 使用本地文件注入 创建时间=\(cdate) 修改时间=\(mdate)", ddlog: .sharedInstance)
            }
            await MainActor.run {
                importerResult = .success(selectedUrls)
                isImporterSelected = true
            }
        } else {
            // 如果本地文件不存在，则弹窗
            DDLogWarn("OptionView: 本地不存在 injection.dylib，无法注入", ddlog: .sharedInstance)
            await MainActor.run {
                isNoFileAlertPresented = true
            }
        }
    }
    // 将 checkFileStatus 函数移到 OptionView struct 内部
    private func checkFileStatus() {
        // 取消之前的任务，避免并发问题
        checkFileStatusTask?.cancel()
        checkFileStatusTask = Task {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                await MainActor.run {
                    fileStatusText = "无法访问文档目录"
                }
                return
            }
            
            let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
            
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
                    if let creationDate = attrs[.creationDate] as? Date {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
                        
                        if let fileSize = attrs[.size] as? Int64 {
                            let sizeInKB = Double(fileSize) / 1024
                            let sizeString = String(format: "%.2f KB", sizeInKB)
                            await MainActor.run {
                                fileStatusText = "文件版本: \(formatter.string(from: creationDate)) | 大小: \(sizeString)"
                            }
                            DDLogInfo("OptionView.checkFileStatus: 文件存在 size=\(fileSize)B 创建时间=\(creationDate) 修改时间=\(attrs[.modificationDate] as? Date as Any)", ddlog: .sharedInstance)
                        } else {
                            await MainActor.run {
                                fileStatusText = "文件版本: \(formatter.string(from: creationDate)) | 大小: 未知"
                            }
                            DDLogWarn("OptionView.checkFileStatus: 文件存在但无法获取大小", ddlog: .sharedInstance)
                        }
                    } else {
                        await MainActor.run {
                            fileStatusText = "文件存在，但无法获取创建时间"
                        }
                        DDLogWarn("OptionView.checkFileStatus: 文件存在但无法读取创建时间", ddlog: .sharedInstance)
                    }
                } catch {
                    await MainActor.run {
                        fileStatusText = "无法读取文件属性"
                    }
                    DDLogError("OptionView.checkFileStatus: 读取文件属性失败 \(error)", ddlog: .sharedInstance)
                }
            } else {
                await MainActor.run {
                    fileStatusText = "无文件，需下载"
                }
                DDLogInfo("OptionView.checkFileStatus: 未找到本地文件", ddlog: .sharedInstance)
            }
        }
    }
    
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0 // 0~1
    @State private var downloadTitle: String = NSLocalizedString("Downloading…", comment: "")
    @State private var fileStatusText: String = "检查中..."
    @State private var checkFileStatusTask: Task<Void, Never>?
    
    // 日志查看状态
    @State private var isLogsPresented = false
    @State private var latestLogURL: URL?

    // 展示最新日志
    @MainActor
    private func presentLatestLogSheet() async {
        guard let latestURL = latestLogFileURLForCurrentApp() else {
            DDLogWarn("OptionView: 未找到最新日志文件", ddlog: .sharedInstance)
            return
        }
        DDLogInfo("OptionView: 展示最新日志 \(latestURL.lastPathComponent)", ddlog: .sharedInstance)
        latestLogURL = latestURL
        isLogsPresented = true
    }

    private func latestLogFileURLForCurrentApp() -> URL? {
        let fileManager = FileManager.default
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        var latestURL: URL?
        var latestDate: Date?

        // 查找 InjectorV3/Logs 目录下的日志（注入过程的日志）
        let rootDirectory = cachesDirectory
            .appendingPathComponent(gTrollFoolsIdentifier, isDirectory: true)
            .appendingPathComponent("InjectorV3", isDirectory: true)

        if fileManager.fileExists(atPath: rootDirectory.path),
           let tempDirectories = try? fileManager.contentsOfDirectory(
               at: rootDirectory,
               includingPropertiesForKeys: [.isDirectoryKey],
               options: [.skipsHiddenFiles]
           ) {
            for tempDirectory in tempDirectories {
                guard let directoryValues = try? tempDirectory.resourceValues(forKeys: [.isDirectoryKey]),
                      directoryValues.isDirectory == true else {
                    continue
                }

                let logsDirectory = tempDirectory
                    .appendingPathComponent("Logs", isDirectory: true)
                    .appendingPathComponent(app.id, isDirectory: true)

                guard let enumerator = fileManager.enumerator(
                    at: logsDirectory,
                    includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    continue
                }

                for case let fileURL as URL in enumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey]),
                          resourceValues.isRegularFile == true else {
                        continue
                    }

                    let candidateDate = resourceValues.creationDate ?? resourceValues.contentModificationDate
                    guard let candidateDate else {
                        continue
                    }

                    if let currentLatestDate = latestDate {
                        if candidateDate > currentLatestDate {
                            latestDate = candidateDate
                            latestURL = fileURL
                        }
                    } else {
                        latestDate = candidateDate
                        latestURL = fileURL
                    }
                }
            }
        }

        // 查找 SharedLogs 目录下的日志（应用本身的日志，包括 OptionView 的日志）
        let sharedLogsDirectory = cachesDirectory
            .appendingPathComponent(gTrollFoolsIdentifier, isDirectory: true)
            .appendingPathComponent("SharedLogs", isDirectory: true)

        if fileManager.fileExists(atPath: sharedLogsDirectory.path),
           let enumerator = fileManager.enumerator(
               at: sharedLogsDirectory,
               includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey],
               options: [.skipsHiddenFiles]
           ) {
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .creationDateKey, .contentModificationDateKey]),
                      resourceValues.isRegularFile == true else {
                    continue
                }

                let candidateDate = resourceValues.creationDate ?? resourceValues.contentModificationDate
                guard let candidateDate else {
                    continue
                }

                if let currentLatestDate = latestDate {
                    if candidateDate > currentLatestDate {
                        latestDate = candidateDate
                        latestURL = fileURL
                    }
                } else {
                    latestDate = candidateDate
                    latestURL = fileURL
                }
            }
        }

        return latestURL
    }
}

// MARK: - 摇一摇探测器封装

private extension Notification.Name {
    static let deviceDidShakeNotification = Notification.Name("deviceDidShakeNotification")
}

private final class ShakeDetectorView: UIView {
    override var canBecomeFirstResponder: Bool { true }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            _ = self?.becomeFirstResponder()
        }
    }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShakeNotification, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

private struct ShakeDetectorRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ShakeDetectorView { ShakeDetectorView() }
    func updateUIView(_ uiView: ShakeDetectorView, context: Context) {}
}
