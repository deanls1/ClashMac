import SwiftUI

struct FilterBar: View {
    @Binding var query: String
    @Binding var options: FilterOptions

    var placeholder: String = "过滤条件"

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $query)
                .textFieldStyle(.roundedBorder)

            Toggle("Aa", isOn: $options.caseSensitive)
                .toggleStyle(.button)
                .help("区分大小写")
            Toggle("ab", isOn: $options.wholeWord)
                .toggleStyle(.button)
                .help("全词匹配")
            Toggle(".*", isOn: $options.useRegex)
                .toggleStyle(.button)
                .help("正则表达式")
        }
    }
}

struct TrafficChartView: View {
    let samples: [TrafficSample]
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(samples.map { max($0.upload, $0.download) }.max() ?? 1, 1)
            ZStack {
                closedAreaPath(for: samples.map(\.download), in: geo.size, maxValue: maxValue)
                    .fill(
                        LinearGradient(
                            colors: [VergeColor.download.opacity(0.28), VergeColor.download.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                downloadPath(in: geo.size, maxValue: maxValue)
                    .stroke(VergeColor.download, lineWidth: 2)
                uploadPath(in: geo.size, maxValue: maxValue)
                    .stroke(VergeColor.upload, lineWidth: 1.5)
            }
        }
        .frame(height: height)
    }

    private func closedAreaPath(for values: [Int], in size: CGSize, maxValue: Int) -> Path {
        var path = path(for: values, in: size, maxValue: maxValue)
        guard values.count > 1 else { return path }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func downloadPath(in size: CGSize, maxValue: Int) -> Path {
        path(for: samples.map(\.download), in: size, maxValue: maxValue)
    }

    private func uploadPath(in size: CGSize, maxValue: Int) -> Path {
        path(for: samples.map(\.upload), in: size, maxValue: maxValue)
    }

    private func path(for values: [Int], in size: CGSize, maxValue: Int) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let stepX = size.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            let y = size.height - (CGFloat(value) / CGFloat(maxValue)) * size.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

#Preview {
    VStack {
        TrafficChartView(
            samples: (0..<30).map { i in
                TrafficSample(upload: Int.random(in: 0...50_000), download: Int.random(in: 0...500_000))
            },
            height: 48
        )
        .padding()
    }
    .frame(width: 180)
}
