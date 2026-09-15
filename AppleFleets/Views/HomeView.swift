import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var bridge: RunBridgeServer
    @State private var demoRun: WorkoutSummary?
    @State private var copy = WorkoutCopy.make(for: .sample)
    @State private var shareItems: [Any] = []
    @State private var showsShareSheet = false
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var selectedCard = 0

    private var run: WorkoutSummary? { demoRun ?? health.latestWorkout }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statusStrip
                    macBridge
                    if let run {
                        preview(run)
                        copyEditor
                        exportActions(run)
                    } else {
                        emptyState
                    }
                }
                .padding(20)
            }
            .background(RunTheme.mist.opacity(0.55))
            .navigationTitle("跑步纸带")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        Task { try? await health.refreshLatestWorkout() }
                    }
                    .disabled(isExporting)
                }
            }
        }
        .sheet(isPresented: $showsShareSheet) { ShareSheet(items: shareItems) }
        .alert("没有完成导出", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请重试")
        }
        .onChange(of: run) { _, newRun in
            if let newRun {
                copy = WorkoutCopy.make(for: newRun)
                if demoRun == nil {
                    bridge.publish(newRun)
                }
            }
        }
    }

    private var macBridge: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("连接 Mac", systemImage: "laptopcomputer.and.iphone")
                    .font(.headline)
                Spacer()
                Text(bridge.isRunning ? "局域网可用" : "未启动")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(bridge.isRunning ? RunTheme.track : RunTheme.coral)
            }
            Text(bridge.address)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(RunTheme.muted)
            HStack(alignment: .firstTextBaseline) {
                Text("配对码")
                    .font(.caption)
                    .foregroundStyle(RunTheme.muted)
                Text(bridge.auth.pairingCode)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(RunTheme.ink)
            }
            Text("Mac 首次连接时使用。配对成功后会自动更换。")
                .font(.caption)
                .foregroundStyle(RunTheme.muted)
            if !bridge.auth.pairedMacs.isEmpty {
                Divider()
                ForEach(bridge.auth.pairedMacs) { mac in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mac.name).font(.subheadline.weight(.semibold))
                            Text("已于 \(mac.pairedAt.formatted(date: .abbreviated, time: .shortened)) 配对")
                                .font(.caption2)
                                .foregroundStyle(RunTheme.muted)
                        }
                        Spacer()
                        Button("移除", role: .destructive) {
                            bridge.auth.revoke(mac)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(run == nil ? RunTheme.coral : RunTheme.track)
                .frame(width: 9, height: 9)
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RunTheme.ink)
            Spacer()
            if health.state == .loading { ProgressView().controlSize(.small) }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusText: String {
        switch health.state {
        case .idle: "等待读取健康数据"
        case .requestingAccess: "等待健康数据授权"
        case .loading: "正在读取最近一次跑步"
        case .ready: demoRun == nil ? "已读取真实跑步记录" : "正在查看示例数据"
        case .unavailable(let message), .failed(let message): message
        }
    }

    private func preview(_ run: WorkoutSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("图文预览")
                .font(.title2.bold())
                .foregroundStyle(RunTheme.ink)
            TabView(selection: $selectedCard) {
                ForEach(CardKind.allCases) { kind in
                    WorkoutCardView(run: run, kind: kind, format: .post)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: RunTheme.ink.opacity(0.10), radius: 18, y: 8)
                        .padding(.horizontal, 12)
                        .tag(kind.rawValue)
                }
            }
            .frame(height: 500)
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }

    private var copyEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("发布文案")
                .font(.title2.bold())
                .foregroundStyle(RunTheme.ink)
            TextField("标题", text: $copy.title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            TextField("正文", text: $copy.body, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)
            TextField("话题", text: $copy.hashtags, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func exportActions(_ run: WorkoutSummary) -> some View {
        VStack(spacing: 12) {
            Button {
                exportPost(run)
            } label: {
                Label("生成小红书图文", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                exportVideo(run)
            } label: {
                Label("生成抖音竖屏视频", systemImage: "play.rectangle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            if isExporting {
                HStack { ProgressView(); Text("正在生成，请保持页面打开…") }
                    .font(.footnote)
                    .foregroundStyle(RunTheme.muted)
            }
            Text("分享前请检查内容；精确位置不会出现在当前模板中。")
                .font(.footnote)
                .foregroundStyle(RunTheme.muted)
        }
        .disabled(isExporting)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 48))
                .foregroundStyle(RunTheme.track)
            Text("还没有可用的跑步")
                .font(.title2.bold())
            Text("等待 Apple Watch 同步，或者先用示例数据查看完整效果。")
                .foregroundStyle(RunTheme.muted)
            Button("查看示例") {
                demoRun = .sample
                copy = .make(for: .sample)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private func exportPost(_ run: WorkoutSummary) {
        isExporting = true
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let files = try CardExporter.pngFiles(for: run)
                shareItems = files + ["\(copy.title)\n\n\(copy.body)\n\n\(copy.hashtags)"]
                showsShareSheet = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportVideo(_ run: WorkoutSummary) {
        isExporting = true
        Task { @MainActor in
            do {
                let images = try CardExporter.images(for: run, format: .story)
                let video = try await VideoExporter.export(images: images, id: run.id)
                shareItems = [video, "\(copy.title)\n\n\(copy.body)\n\n\(copy.hashtags)"]
                showsShareSheet = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isExporting = false
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(configuration.isPressed ? RunTheme.ink.opacity(0.8) : RunTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(RunTheme.ink)
            .padding(.vertical, 15)
            .background(configuration.isPressed ? RunTheme.track.opacity(0.16) : .white)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(RunTheme.ink, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}
