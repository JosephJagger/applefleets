import Charts
import SwiftRender
import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.043, green: 0.098, blue: 0.188)
    static let track = Color(red: 0.239, green: 0.447, blue: 1)
    static let coral = Color(red: 1, green: 0.353, blue: 0.306)
    static let mist = Color(red: 0.933, green: 0.957, blue: 1)
    static let paper = Color(red: 0.988, green: 0.992, blue: 1)
    static let muted = Color(red: 0.40, green: 0.455, blue: 0.545)
}

enum RunCardKind: Int, CaseIterable {
    case cover, splits, heart, finish
}

struct RunCardView: View {
    let run: RunSummary
    let plan: EditorialPlan
    let kind: RunCardKind
    let verticalVideo: Bool
    var progress: Double = 1

    private var scale: CGFloat { verticalVideo ? 1.28 : 1 }

    var body: some View {
        ZStack {
            Palette.paper
            VStack(alignment: .leading, spacing: 44 * scale) {
                timingHeader
                content
                Spacer(minLength: 20)
                footer
            }
            .padding(78 * scale)
            .opacity(progress)
            .scaleEffect(0.97 + 0.03 * progress)
        }
        .clipped()
    }

    private var timingHeader: some View {
        VStack(spacing: 22 * scale) {
            HStack {
                Text(run.startDate.formatted(.dateTime.year().month().day()))
                Text("RUN / \(kind.rawValue + 1)–4")
                Spacer()
                Circle().fill(Palette.coral).frame(width: 22 * scale, height: 22 * scale)
            }
            .font(.system(size: 27 * scale, weight: .bold, design: .monospaced))
            .tracking(3)
            .foregroundStyle(Palette.ink)
            HStack(spacing: 12) {
                ForEach(0..<12, id: \.self) { index in
                    Rectangle()
                        .fill(index <= kind.rawValue * 3 ? Palette.track : Palette.mist)
                        .frame(height: index.isMultiple(of: 3) ? 12 * scale : 5 * scale)
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .cover:
            VStack(alignment: .leading, spacing: 28 * scale) {
                Spacer(minLength: 20)
                Text(plan.coverTitle)
                    .font(.system(size: 108 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(-10)
                Text(String(format: "%.2f", run.distanceKilometers))
                    .font(.system(size: 220 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.track)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text("KILOMETERS")
                    .font(.system(size: 31 * scale, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .foregroundStyle(Palette.coral)
                HStack(spacing: 80 * scale) {
                    metric("用时", run.durationText)
                    metric("平均配速", "\(run.paceText) /km")
                }
            }
        case .splits:
            VStack(alignment: .leading, spacing: 30 * scale) {
                title("每一公里，\n都有自己的脾气", eyebrow: "SPLITS")
                let visible = Array(run.splits.prefix(verticalVideo ? 10 : 8))
                ForEach(visible) { split in
                    HStack(spacing: 25 * scale) {
                        Text(String(format: "%02d KM", split.kilometer))
                            .font(.system(size: 28 * scale, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                            .frame(width: 125 * scale, alignment: .leading)
                        GeometryReader { proxy in
                            let fastest = visible.map(\.duration).min() ?? split.duration
                            let slowest = visible.map(\.duration).max() ?? split.duration
                            let ratio = slowest == fastest ? 0.86 : 1 - ((split.duration - fastest) / (slowest - fastest)) * 0.36
                            Capsule()
                                .fill(split.duration == fastest ? Palette.coral : Palette.track)
                                .frame(width: max(80, proxy.size.width * ratio), height: 18 * scale)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(height: 36 * scale)
                        Text(split.paceText)
                            .font(.system(size: 42 * scale, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
        case .heart:
            VStack(alignment: .leading, spacing: 38 * scale) {
                title("心跳留下的\n训练轨迹", eyebrow: "HEART RATE")
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    Text(run.averageHeartRate.map(String.init) ?? "--")
                        .font(.system(size: 170 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.coral)
                    Text("BPM 平均")
                        .font(.system(size: 29 * scale, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                Chart(run.heartRate) { point in
                    AreaMark(x: .value("时间", point.secondsFromStart), y: .value("心率", point.beatsPerMinute))
                        .foregroundStyle(LinearGradient(colors: [Palette.coral.opacity(0.38), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("时间", point.secondsFromStart), y: .value("心率", point.beatsPerMinute))
                        .foregroundStyle(Palette.coral)
                        .lineStyle(StrokeStyle(lineWidth: 8 * scale, lineCap: .round, lineJoin: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Palette.mist)
                        AxisValueLabel().font(.system(size: 22 * scale, design: .monospaced))
                    }
                }
                .frame(height: 430 * scale)
                HStack {
                    metric("最高心率", run.maximumHeartRate.map { "\($0) BPM" } ?? "--")
                    Spacer()
                    metric("记录点", "\(run.heartRate.count)")
                }
            }
        case .finish:
            VStack(alignment: .leading, spacing: 54 * scale) {
                title("跑完以后，\n数字才开始说话", eyebrow: "RUN NOTE")
                Text(plan.closingInsight)
                    .font(.system(size: 63 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(22)
                Spacer(minLength: 30)
                HStack(spacing: 20) {
                    tag("\(run.paceText)/km")
                    if let heart = run.averageHeartRate { tag("\(heart) bpm") }
                }
                Rectangle().fill(Palette.track).frame(height: 28 * scale)
                Rectangle().fill(Palette.coral).frame(width: 190 * scale, height: 28 * scale)
            }
        }
    }

    private func title(_ value: String, eyebrow: String) -> some View {
        VStack(alignment: .leading, spacing: 20 * scale) {
            Text(eyebrow)
                .font(.system(size: 29 * scale, weight: .bold, design: .monospaced))
                .tracking(7)
                .foregroundStyle(Palette.track)
            Text(value)
                .font(.system(size: 84 * scale, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)
                .lineSpacing(-5)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            Text(label).font(.system(size: 27 * scale, weight: .medium)).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 45 * scale, weight: .bold, design: .monospaced)).foregroundStyle(Palette.ink)
        }
    }

    private func tag(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 32 * scale, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.track)
            .padding(.horizontal, 28 * scale)
            .padding(.vertical, 18 * scale)
            .background(Palette.mist, in: Capsule())
    }

    private var footer: some View {
        HStack {
            Text("RUN TAPE").font(.system(size: 24 * scale, weight: .black, design: .monospaced)).tracking(5)
            Spacer()
            Text("由我的 Apple Watch 记录").font(.system(size: 24 * scale, weight: .medium))
        }
        .foregroundStyle(Palette.muted)
    }
}

struct RunVideoView: View {
    let run: RunSummary
    let plan: EditorialPlan
    let time: Double

    var body: some View {
        let page = min(3, max(0, Int(time / 3)))
        let local = time - Double(page * 3)
        let enter = Ease.easeOut(Ease.clip(local, 0, 0.45))
        let exit = Ease.easeIn(Ease.clip(local, 2.65, 3))
        RunCardView(run: run, plan: plan, kind: RunCardKind(rawValue: page) ?? .cover, verticalVideo: true, progress: enter * (1 - exit))
    }
}
