//
//  OptionView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import SwiftUI

struct OptionView: View {
    let app: App
    // 添加URL常量
    private let debugDownloadURL = "https://dj-injection.oss-cn-hangzhou.aliyuncs.com/debug/testa.dylib"
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
            // 新增下载按钮
            Button {
                Task {
                    do {
                        let fileManager = FileManager.default
                        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
                        }
                        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
                        let downloadURL = URL(string: releaseDownloadURL)!
                        
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
                Label("下载新文件", systemImage: "arrow.down.circle")
            }
            .disabled(isDownloading) // 下载时禁用按钮
            // 新增文件状态显示
            Text(fileStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button {
                isSettingsPresented = true
            } label: {
                Label(NSLocalizedString("Advanced Settings", comment: ""),
                      systemImage: "gear")
            }
            // debug
            Button {
                Task {
                    do {
                        let fileManager = FileManager.default
                        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to access documents directory"])
                        }
                        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
                        let downloadURL = URL(string: debugDownloadURL)!
                        
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
                Label("debug", systemImage: "ladybug")
            }
            .disabled(isDownloading) // 下载时禁用按钮
        }
        .padding()
        .navigationTitle(app.name)
        .onAppear {
            // 删除已存在的injection.dylib文件
            let fileManager = FileManager.default
            if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
                if fileManager.fileExists(atPath: fileURL.path) {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
            checkFileStatus()
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
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            downloadTitle = NSLocalizedString("Downloading…", comment: "")
        }
        
        let (byteStream, response) = try await URLSession.shared.bytes(from: url)
        
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
        
        // 如果有 lastModifiedDate，将其设置为文件的创建时间
        // if let lastModifiedDate = lastModifiedDate {
        //     // 直接使用服务器返回的时间，不进行时区转换
        //     let attributes: [FileAttributeKey: Any] = [
        //         .creationDate: lastModifiedDate,
        //         .modificationDate: lastModifiedDate
        //     ]
            
        //     do {
        //         try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
        //     } catch {
        //         print("Failed to set file attributes: \(error)")
        //     }
        // }
        await MainActor.run {
            isDownloading = false
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
        
        var urls: [URL] = []
        var lastModifiedDate: Date? = nil
        
        // 检查本地文件是否存在
        if fileManager.fileExists(atPath: fileURL.path) {
            urls = [fileURL]
        } else {
            // 如果本地文件不存在，则弹窗
            await MainActor.run {
                isNoFileAlertPresented = true
            }
            return
        }
        let selectedUrls = urls
        
        await MainActor.run {
            importerResult = .success(selectedUrls)
            isImporterSelected = true
        }
    }
    // 将 checkFileStatus 函数移到 OptionView struct 内部
    private func checkFileStatus() {
        Task {
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
                        
                        await MainActor.run {
                            fileStatusText = "文件版本: \(formatter.string(from: creationDate))"
                        }
                    } else {
                        await MainActor.run {
                            fileStatusText = "文件存在，但无法获取创建时间"
                        }
                    }
                } catch {
                    await MainActor.run {
                        fileStatusText = "无法读取文件属性"
                    }
                }
            } else {
                await MainActor.run {
                    fileStatusText = "无文件，需下载"
                }
            }
        }
    }
    
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0 // 0~1
    @State private var downloadTitle: String = NSLocalizedString("Downloading…", comment: "")
    @State private var fileStatusText: String = "检查中..."
}
