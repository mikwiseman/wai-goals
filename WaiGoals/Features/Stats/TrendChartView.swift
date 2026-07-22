import SwiftUI
import Charts

/// A clean weekly-completion bar chart for the last several weeks.
struct TrendChartView: View {
    let points: [StatsCalculator.WeekPoint]
    var tint: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Completion", displayedRate(for: point))
            )
            .foregroundStyle(tint.gradient)
            .cornerRadius(4)
            .accessibilityLabel(point.weekStart.formatted(.dateTime.month().day()))
            .accessibilityValue(point.rate.formatted(.percent.precision(.fractionLength(0))))
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.5, 1.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let fraction = value.as(Double.self) {
                        Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 168)
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.86)) {
                    revealed = true
                }
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { revealed = true }
        }
    }

    private func displayedRate(for point: StatsCalculator.WeekPoint) -> Double {
        reduceMotion || revealed ? point.rate : 0
    }
}
