//
//  InjectView.swift
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

import CocoaLumberjackSwift
import SwiftUI

struct InjectView: View {
    @EnvironmentObject var appList: AppListModel

    let app: App
    let urlList: [URL]

    @State var injectResult: Result<URL?, Error>?
    @StateObject fileprivate var viewControllerHost = ViewControllerHost()
    @State private var fileCreationTime: String = "获取中..."

    @AppStorage var useWeakReference: Bool
    @AppStorage var preferMainExecutable: Bool
    @AppStorage var injectStrategy: InjectorV3.Strategy

    init(_ app: App, urlList: [URL]) {
        self.app = app
        self.urlList = urlList
        _useWeakReference = AppStorage(wrappedValue: true, "UseWeakReference-\(app.id)")
        _preferMainExecutable = AppStorage(wrappedValue: false, "PreferMainExecutable-\(app.id)")
        _injectStrategy = AppStorage(wrappedValue: .lexicographic, "InjectStrategy-\(app.id)")
    }

    var body: some View {
        if appList.isSelectorMode {
            bodyContent
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("Done", comment: "")) {
                            viewControllerHost.viewController?.navigationController?
                                .dismiss(animated: true)
                        }
                    }
                }
        } else {
            bodyContent
        }
    }

    var bodyContent: some View {
        VStack {
            // 添加显眼的固定信息标签
            Text("文件版本")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.bottom, 20)
            
            Text(fileCreationTime)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.bottom, 30)

            if let injectResult {
                switch injectResult {
                case let .success(url):
                    SuccessView(
                        title: NSLocalizedString("Completed", comment: ""),
                        logFileURL: url
                    )
                    .onAppear {
                        app.reload()
                    }
                case let .failure(error):
                    FailureView(
                        title: NSLocalizedString("Failed", comment: ""),
                        error: error
                    )
                    .onAppear {
                        app.reload()
                    }
                }
            } else {
                if #available(iOS 16, *) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.all, 20)
                        .controlSize(.large)
                } else {
                    // Fallback on earlier versions
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.all, 20)
                        .scaleEffect(2.0)
                }
            
                Text(NSLocalizedString("Injecting", comment: ""))
                    .font(.headline)
            }
        }
        .padding()
        .animation(.easeOut, value: injectResult == nil)
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .onViewWillAppear { viewController in
            viewController.navigationController?
                .view.isUserInteractionEnabled = false
            viewControllerHost.viewController = viewController
        }
        .onAppear {
            // 在主线程安全地获取文件时间
            DispatchQueue.main.async {
                getFileCreationTime()
            }
            
            // 异步执行注入操作
            DispatchQueue.global(qos: .userInteractive).async {
                let result = inject()

                DispatchQueue.main.async {
                    injectResult = result
                    app.reload()
                    viewControllerHost.viewController?.navigationController?
                        .view.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    private func getFileCreationTime() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("injection.dylib")
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                formatter.locale = Locale(identifier: "zh_CN")
                formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
                fileCreationTime = formatter.string(from: creationDate)
            } else {
                fileCreationTime = "无法获取创建时间"
            }
        } catch {
            fileCreationTime = "文件不存在"
        }
    }

    private func inject() -> Result<URL?, Error> {
        var logFileURL: URL?

        do {
            let injector = try InjectorV3(app.url)
            logFileURL = injector.latestLogFileURL

            if injector.appID.isEmpty {
                injector.appID = app.id
            }

            if injector.teamID.isEmpty {
                injector.teamID = app.teamID
            }

            injector.useWeakReference = useWeakReference
            injector.preferMainExecutable = preferMainExecutable
            injector.injectStrategy = injectStrategy

            try injector.inject(urlList)
            return .success(injector.latestLogFileURL)

        } catch {
            DDLogError("\(error)", ddlog: InjectorV3.main.logger)

            var userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ]

            if let logFileURL {
                userInfo[NSURLErrorKey] = logFileURL
            }

            let nsErr = NSError(domain: gTrollFoolsErrorDomain, code: 0, userInfo: userInfo)

            return .failure(nsErr)
        }
    }
}
