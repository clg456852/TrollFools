//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct OptionView: View {
    let app: App

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

    var body: some View {
        if #available(iOS 15, *) {
            content
                .alert(
                    NSLocalizedString("Notice", comment: ""),
                    isPresented: $isWarningPresented,
                    presenting: temporaryResult
                ) { result in
                    Button {
                        importerResult = result
                        isImporterSelected = true
                    } label: {
                        Text(NSLocalizedString("Continue", comment: ""))
                    }
                    Button(role: .destructive) {
                        importerResult = result
                        isImporterSelected = true
                        isWarningHidden = true
                    } label: {
                        Text(NSLocalizedString("Continue and Don’t Show Again", comment: ""))
                    }
                    Button(role: .cancel) {
                        temporaryResult = nil
                        isWarningPresented = false
                    } label: {
                        Text(NSLocalizedString("Cancel", comment: ""))
                    }
                } message: {
                    if case .success(let urls) = $0 {
                        Text(Self.warningMessage(urls))
                    }
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
                            try await downloadAndInject()
                        } catch {
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

            Button {
                isSettingsPresented = true
            } label: {
                Label(NSLocalizedString("Advanced Settings", comment: ""),
                      systemImage: "gear")
            }
        }
        .padding()
        .navigationTitle(app.name)
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
        .alert("File Info", isPresented: $isFileInfoPresented) {     // 新增弹窗
            Button(NSLocalizedString("Continue", comment: "")) {
                if let urls = pendingUrls {
                    importerResult = .success(urls)
                    isImporterSelected = true
                    pendingUrls = nil
                }
            }
        } message: {
            Text(fileInfoMessage)
        }
    }

    static func warningMessage(_ urls: [URL]) -> String {
        guard let firstDylibName = urls.first(where: { $0.pathExtension.lowercased() == "deb" })?.lastPathComponent else {
            fatalError("No debian package found.")
        }
        return String(format: NSLocalizedString("You’ve selected at least one Debian Package “%@”. We’re here to remind you that it will not work as it was in a jailbroken environment. Please make sure you know what you’re doing.", comment: ""), firstDylibName)
    }

    private func downloadAndInject() async throws {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
        }
        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
    
        var urls: [URL] = []
        if fileManager.fileExists(atPath: fileURL.path) {
            urls = [fileURL]
        } else {
            let downloadURL = URL(string: "https://dajiang-injection.oss-cn-hangzhou.aliyuncs.com/testa.dylib")!
    
            await MainActor.run {
                isDownloading = true
                downloadProgress = 0
                downloadTitle = NSLocalizedString("Downloading…", comment: "")
            }
    
            let (byteStream, response) = try await URLSession.shared.bytes(from: downloadURL)
            var lastModifiedDate: Date? = nil               // 新增：用于保存 Last-Modified 时间
            if let httpResp = response as? HTTPURLResponse, // 解析 Last-Modified
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
            // downloadAndInject() 内部（替换原 for 循环部分）
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
            urls = [fileURL]
    
            await MainActor.run {
                isDownloading = false
            }
    
            // 在切换到主线程前，先使用不可变常量保存结果，避免捕获可变变量触发
            let selectedUrls = urls // 保留原逻辑
    
            // === 新实现：始终构造弹窗信息 ===
            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) // 新增：获取文件属性
            var dateStr: String
            if let lm = lastModifiedDate {                // 使用服务器 Last-Modified
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = .medium
                fmt.timeZone = TimeZone(identifier: "Asia/Shanghai") // 转北京时间
                dateStr = fmt.string(from: lm)
            } else if let creation = attrs?[.creationDate] as? Date { // 回退到本地创建时间
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                fmt.timeStyle = .medium
                fmt.timeZone = TimeZone(identifier: "Asia/Shanghai")
                dateStr = fmt.string(from: creation)
            } else {
                dateStr = NSLocalizedString("Time unavailable", comment: "")
            }

            await MainActor.run {
                fileInfoMessage = String(format: NSLocalizedString("File creation time: %@", comment: ""), dateStr)
                pendingUrls = selectedUrls
                isFileInfoPresented = true           // 无论是否有日期，都先弹窗
            }
    }
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0 // 0~1
    @State private var downloadTitle: String = NSLocalizedString("Downloading…", comment: "")
    @State private var isFileInfoPresented = false       // 新增：控制弹窗
    @State private var fileInfoMessage: String = ""      // 新增：弹窗内容
    @State private var pendingUrls: [URL]? = nil         // 新增：暂存 URL 列表
}
