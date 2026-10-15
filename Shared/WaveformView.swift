import SwiftUI

struct WaveformView: View {
    var samples: [Float]
    var progress: Double = 0
    var active: Color
    var inactive: Color
    var showsProgress = false

    var body: some View {
        Canvas { context, size in
            let bars = samples.isEmpty ? Array(repeating: Float(0.08), count: 24) : samples
            let count = bars.count
            let spacing: CGFloat = count > 32 ? 2 : 3
            let available = size.width - spacing * CGFloat(max(count - 1, 0))
            let width = max(2, min(4, available / CGFloat(count)))
            let used = width * CGFloat(count) + spacing * CGFloat(max(count - 1, 0))
            let originX = (size.width - used) / 2

            for index in 0..<count {
                let value = CGFloat(min(1, max(0.05, bars[index])))
                let height = max(3, value * size.height)
                let x = originX + CGFloat(index) * (width + spacing)
                let y = (size.height - height) / 2
                let rect = CGRect(x: x, y: y, width: width, height: height)
                let path = Path(roundedRect: rect, cornerRadius: width / 2)
                let played = showsProgress && Double(index) / Double(count) < progress
                context.fill(path, with: .color(played ? active : inactive))
            }
        }
        .accessibilityLabel("Waveform")
    }
}
