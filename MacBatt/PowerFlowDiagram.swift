import SwiftUI

// MARK: - Power Flow Diagram (top-level illustration)

struct PowerFlowDiagram: View {
    let battery: BatteryData
    @State private var flowPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if battery.externalConnected {
                pluggedInDiagram
            } else {
                onBatteryDiagram
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .task {
            // Small delay so the popover finishes its entrance before we start animating
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                flowPhase = 1
            }
        }
    }

    // MARK: - Plugged-in diagram
    //
    //                                          ┌─────────────┐
    //                                    ┌═══▶ │   System    │
    //  [Wall] ═══▶ [Adapter] ═══▶ [Mac] ═╡    └─────────────┘
    //                                    └═══▶ ┌─────────────┐
    //                                          │   Battery   │
    //                                          └─────────────┘

    private var pluggedInDiagram: some View {
        let wallW = Double(battery.systemPowerIn + battery.adapterEfficiencyLoss) / 1000.0
        let macW = Double(battery.systemPowerIn) / 1000.0
        let batW = abs(Double(battery.batteryPower) / 1000.0)
        // System consumption = MacBook input - battery charging power
        let sysW = battery.isCharging ? max(0, macW - batW) : macW
        let lossW = Double(battery.adapterEfficiencyLoss) / 1000.0
        let adapterActual = battery.adapterActualWatts ?? Double(battery.adapterWatts)
        let efficiency: Double = {
            let totalIn = Double(battery.systemPowerIn + battery.adapterEfficiencyLoss)
            guard totalIn > 0 else { return 0 }
            return (1.0 - Double(battery.adapterEfficiencyLoss) / totalIn) * 100.0
        }()

        return VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 0) {
                // Wall
                DiagramBox(
                    icon: "poweroutlet.type.b.fill",
                    title: "Wall",
                    value: wallW > 0 ? String(format: "%.1fW", wallW) : "AC",
                    color: .orange
                )

                FlowArrow(color: .orange, phase: flowPhase)

                // Adapter
                DiagramBox(
                    icon: "cable.connector.usbc",
                    title: battery.adapterDescription.isEmpty ? "Adapter" : battery.adapterDescription,
                    value: String(format: "%.0fW", adapterActual),
                    subtitle: battery.adapterVoltage > 0 ? String(format: "%.0fV", Double(battery.adapterVoltage) / 1000.0) : nil,
                    color: .blue
                )

                FlowArrow(color: .blue, phase: flowPhase)

                // MacBook — the fork point
                DiagramBox(
                    icon: "laptopcomputer",
                    title: "MacBook",
                    value: String(format: "%.1fW", Double(battery.systemPowerIn) / 1000.0),
                    color: .purple
                )

                // Fork with visible lines + arrows
                ForkConnector(
                    topColor: .cyan,
                    bottomColor: .green,
                    phase: flowPhase
                )

                // Right: System (top) + Battery (bottom)
                VStack(spacing: 10) {
                    DiagramBox(
                        icon: "cpu",
                        title: "System",
                        value: String(format: "%.1fW", sysW),
                        subtitle: battery.temperature > 0 ? String(format: "%.0f°C", battery.temperatureC) : nil,
                        color: .cyan
                    )

                    DiagramBox(
                        icon: batteryIconName,
                        title: "Battery \(battery.soc)%",
                        value: battery.isCharging
                            ? String(format: "+%.1fW", batW)
                            : String(format: "-%.1fW", batW),
                        color: .green
                    )
                }
            }

            // Bottom info bar
            HStack(spacing: 16) {
                if lossW > 0 {
                    Label(String(format: "Loss: %.1fW", lossW), systemImage: "flame")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                }
                if efficiency > 0 {
                    Label(String(format: "Efficiency: %.1f%%", efficiency), systemImage: "gauge.with.dots.needle.33percent")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.8))
                }
                Spacer()
                if battery.adapterVoltage > 0 && battery.adapterCurrent > 0 {
                    Text(String(format: "USB-PD: %.0fV × %.1fA",
                                Double(battery.adapterVoltage) / 1000.0,
                                Double(battery.adapterCurrent) / 1000.0))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - On-battery diagram

    private var onBatteryDiagram: some View {
        let sysW = abs(battery.batteryWatts)

        return VStack(spacing: 10) {
            HStack(spacing: 2) {
                Image(systemName: "laptopcomputer")
                    .font(.caption)
                Text("MacBook — On Battery")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                DiagramBox(
                    icon: batteryIconName,
                    title: "Battery \(battery.soc)%",
                    value: String(format: "%.1fW", sysW),
                    subtitle: battery.avgTimeToEmpty < 65535 ? formatTime(battery.avgTimeToEmpty) : nil,
                    color: .green
                )

                FlowArrow(color: .cyan, phase: flowPhase)

                DiagramBox(
                    icon: "cpu",
                    title: "System",
                    value: String(format: "%.1fW", sysW),
                    subtitle: battery.temperature > 0 ? String(format: "%.0f°C", battery.temperatureC) : nil,
                    color: .cyan
                )
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private var batteryIconName: String {
        if battery.isCharging { return "battery.100percent.bolt" }
        if battery.soc > 75 { return "battery.100percent" }
        if battery.soc > 50 { return "battery.75percent" }
        if battery.soc > 25 { return "battery.50percent" }
        return "battery.25percent"
    }
}

// MARK: - Diagram Box (uniform style for all nodes)

private struct DiagramBox: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String? = nil
    let color: Color
    var width: CGFloat = 80

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 9).bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: width)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(0.4), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Flow Arrow (horizontal, between two boxes)

private struct FlowArrow: View {
    var color: Color
    var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            // Solid line
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(width: 12, height: 2.5)

            // Animated chevrons
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(color)
                        .opacity(chevronOpacity(index: i))
                }
            }

            // Solid line
            Rectangle()
                .fill(color.opacity(0.5))
                .frame(width: 12, height: 2.5)
        }
        .frame(minWidth: 48)
    }

    private func chevronOpacity(index: Int) -> Double {
        let offset = Double(index) / 3.0
        let adjusted = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * max(0, 1.0 - abs(adjusted - 0.5) * 3.5)
    }
}

// MARK: - Fork Connector (drawn lines that split into top and bottom branches)

private struct ForkConnector: View {
    let topColor: Color
    let bottomColor: Color
    var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Draw fork lines with Canvas
            Canvas { context, size in
                let midY = size.height / 2
                let left: CGFloat = 0
                let right = size.width
                let topY = size.height * 0.25
                let botY = size.height * 0.75

                // Horizontal stub from left edge to center
                var stub = Path()
                stub.move(to: CGPoint(x: left, y: midY))
                stub.addLine(to: CGPoint(x: right * 0.3, y: midY))
                context.stroke(stub, with: .color(.purple.opacity(0.5)), lineWidth: 2.5)

                // Top branch: center → top-right
                var topBranch = Path()
                topBranch.move(to: CGPoint(x: right * 0.3, y: midY))
                topBranch.addQuadCurve(
                    to: CGPoint(x: right, y: topY),
                    control: CGPoint(x: right * 0.55, y: midY)
                )
                context.stroke(topBranch, with: .color(topColor.opacity(0.5)), lineWidth: 2.5)

                // Bottom branch: center → bottom-right
                var botBranch = Path()
                botBranch.move(to: CGPoint(x: right * 0.3, y: midY))
                botBranch.addQuadCurve(
                    to: CGPoint(x: right, y: botY),
                    control: CGPoint(x: right * 0.55, y: midY)
                )
                context.stroke(botBranch, with: .color(bottomColor.opacity(0.5)), lineWidth: 2.5)
            }

            // Chevron overlays on each branch
            VStack(spacing: 0) {
                // Top branch chevrons
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(topColor)
                            .opacity(chevronOpacity(index: i))
                    }
                }
                .offset(x: 6)
                .frame(height: 20)

                Spacer(minLength: 0)

                // Bottom branch chevrons
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(bottomColor)
                            .opacity(chevronOpacity(index: i))
                    }
                }
                .offset(x: 6)
                .frame(height: 20)
            }
            .padding(.vertical, 12)
        }
        .frame(width: 44)
    }

    private func chevronOpacity(index: Int) -> Double {
        let offset = Double(index) / 3.0
        let adjusted = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * max(0, 1.0 - abs(adjusted - 0.5) * 3.5)
    }
}
