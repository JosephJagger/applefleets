import Charts
import SwiftUI

enum CardKind: Int, CaseIterable, Identifiable {
    case cover, splits, heart, finish
    var id: Int { rawValue }
}

struct WorkoutCardView: View {
    let run: WorkoutSummary
    let kind: CardKind
    let format: ExportFormat

    var body: some View {
        ZStack {
            RunTheme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: format == .story ? 28 : 20) {
                timingHeader
                content
                Spacer(minLength: 8)
                footer
            }
            .padding(format == .story ? 34 : 28)
        }
        .frame(width: format.pointSize.width, height: format.pointSize.height)
        .clipped()
    }

    private var timingHeader: some View {
        HStack(spacing: 8) {
            Text(run.startDate.formatted(.dateTime.month().day()))
            Text("RUN / \(kind.rawValue + 1)–4")
            Spacer()
            Circle().fill(RunTheme.coral).frame(width: 9, height: 9)
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .tracking(1.2)
        .foregroundStyle(RunTheme.ink)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            HStack(spacing: 5) {
                ForEach(0..<12, id: \.self) { index in
                    Rectangle()
                        .fill(index <= kind.rawValue * 3 ? RunTheme.track : RunTheme.mist)
                        .frame(height: index.isMultiple(of: 3) ? 5 : 2)
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .cover: cover
        case .splits: splitBoard
        case .heart: heartBoard
        case .finish: finishBoard
        }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 8)
            Text("今天的跑步\n有据可查")
                .font(.system(size: format == .story ? 54 : 44, weight: .black, design: .rounded))
                .foregroundStyle(RunTheme.ink)
                .lineSpacing(-4)
            Text(String(format: "%.2f", run.distanceKilometers))
                .font(.system(size: format == .story ? 112 : 88, weight: .black, design: .rounded))
                .foregroundStyle(RunTheme.track)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text("KILOMETERS")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(RunTheme.coral)
            HStack(spacing: 26) {
                metric("用时", run.durationText)
                metric("平均配速", "\(run.paceText) /km")
            }
            .padding(.top, 8)
        }
    }

    private var splitBoard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardTitle("每一公里，\n都有自己的脾气", eyebrow: "SPLITS")
            let visible = Array(run.splits.prefix(format == .story ? 10 : 8))
            ForEach(visible) { split in
                HStack {
                    Text(String(format: "%02d KM", split.kilometer))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RunTheme.muted)
                    GeometryReader { proxy in
                        let fastest = visible.map(\.duration).min() ?? split.duration
                        let slowest = visible.map(\.duration).max() ?? split.duration
                        let ratio = slowest == fastest ? 0.85 : 1 - ((split.duration - fastest) / (slowest - fastest)) * 0.35
                        Capsule()
                            .fill(split.duration == fastest ? RunTheme.coral : RunTheme.track)
                            .frame(width: max(30, proxy.size.width * ratio), height: 8)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 18)
                    Text(split.paceText)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(RunTheme.ink)
                }
            }
        }
    }

    private var heartBoard: some View {
        VStack(alignment: .leading, spacing: 20) {
            cardTitle("心跳留下的\n训练轨迹", eyebrow: "HEART RATE")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(run.averageHeartRate.map(String.init) ?? "--")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(RunTheme.coral)
                Text("BPM 平均")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(RunTheme.muted)
            }
            Chart(run.heartRate) { point in
                AreaMark(
                    x: .value("时间", point.secondsFromStart),
                    y: .value("心率", point.beatsPerMinute)
                )
                .foregroundStyle(
                    LinearGradient(colors: [RunTheme.coral.opacity(0.38), .clear], startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value("时间", point.secondsFromStart),
                    y: .value("心率", point.beatsPerMinute)
                )
                .foregroundStyle(RunTheme.coral)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(RunTheme.mist)
                    AxisValueLabel().font(.caption2.monospacedDigit())
                }
            }
            .frame(height: format == .story ? 250 : 185)
            HStack {
                metric("最高心率", run.maximumHeartRate.map { "\($0) BPM" } ?? "--")
                Spacer()
                metric("记录点", "\(run.heartRate.count)")
            }
        }
    }

    private var finishBoard: some View {
        VStack(alignment: .leading, spacing: 22) {
            cardTitle("跑完以后，\n数字才开始说话", eyebrow: "RUN NOTE")
            Text(insight)
                .font(.system(size: format == .story ? 31 : 25, weight: .semibold, design: .rounded))
                .foregroundStyle(RunTheme.ink)
                .lineSpacing(8)
            Spacer(minLength: 10)
            HStack(spacing: 10) {
                tag("\(run.paceText)/km")
                if let heart = run.averageHeartRate { tag("\(heart) bpm") }
            }
            Rectangle().fill(RunTheme.track).frame(height: 12)
            Rectangle().fill(RunTheme.coral).frame(width: 74, height: 12)
        }
    }

    private var insight: String {
        guard let first = run.splits.first?.duration,
              let last = run.splits.last?.duration else {
            return "完成比完美更重要。今天的每一步，都已经被认真记录。"
        }
        if last < first {
            return "最后一公里比第一公里快了 \(Int(first - last)) 秒。不是突然发力，是前面的克制终于有了答案。"
        }
        return "今天没有追着数字跑。把呼吸放稳，把节奏留在自己手里。"
    }

    private func cardTitle(_ title: String, eyebrow: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(RunTheme.track)
            Text(title)
                .font(.system(size: format == .story ? 40 : 34, weight: .black, design: .rounded))
                .foregroundStyle(RunTheme.ink)
                .lineSpacing(-2)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RunTheme.muted)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(RunTheme.ink)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(RunTheme.track)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RunTheme.mist, in: Capsule())
    }

    private var footer: some View {
        HStack {
            Text("RUN TAPE")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
            Spacer()
            Text("由我的 Apple Watch 记录")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(RunTheme.muted)
    }
}

