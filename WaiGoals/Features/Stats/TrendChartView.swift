import SwiftUI
import Charts

/// A clean weekly-completion bar chart for the last several weeks.
struct TrendChartView: View {
    let points: [StatsCalculator.WeekPoint]
    var tint: Color = .accentColor

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Week", point.weekStart, unit: .weekOfYear),
                y: .value("Completion", point.rate)
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
    }
}
