import SwiftUI

struct ContentView: View {
    @State private var service = BatteryService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PowerFlowDiagram(battery: service.battery)
                StatusHeader(battery: service.battery)
                BatterySection(battery: service.battery)
                HealthSection(battery: service.battery)

                if service.battery.externalConnected {
                    ChargerICSection(battery: service.battery)
                    AdapterSection(battery: service.battery)
                }

                SystemPowerSection(battery: service.battery)

                if service.battery.externalConnected && service.battery.systemPowerIn > 0 {
                    PowerFlowSection(battery: service.battery)
                }

                HStack {
                    Text("Updated: \(service.lastUpdated, format: .dateTime.hour().minute().second())")
                    Spacer()
                    Text("Refresh: 2s")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Text("Made by Jianshuo Wang")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                            Text("Quit")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 420, idealWidth: 480)
        .transaction { $0.animation = nil }
    }
}

// MARK: - Status Header

struct StatusHeader: View {
    let battery: BatteryData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: battery.statusIcon)
                    .font(.title)
                    .foregroundStyle(statusColor)
                Text(battery.statusText)
                    .font(.title2.bold())
                Spacer()
                Text("\(battery.soc)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(socColor)
            }

            if battery.atCriticalLevel {
                Label("CRITICAL BATTERY LEVEL", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption.bold())
            }

            ProgressView(value: Double(battery.soc), total: 100)
                .tint(socColor)

            // Time estimate
            if battery.isCharging && battery.avgTimeToFull < 65535 {
                Label("Time to full: \(formatTime(battery.avgTimeToFull))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !battery.externalConnected && battery.avgTimeToEmpty < 65535 {
                Label("Time remaining: \(formatTime(battery.avgTimeToEmpty))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    var statusColor: Color {
        if battery.fullyCharged { return .green }
        if battery.isCharging { return .yellow }
        if battery.externalConnected { return .orange }
        return .blue
    }

    var socColor: Color {
        if battery.soc > 60 { return .green }
        if battery.soc > 20 { return .yellow }
        return .red
    }
}

// MARK: - Battery Section

struct BatterySection: View {
    let battery: BatteryData

    var body: some View {
        SectionCard(title: "Battery", icon: "battery.100") {
            InfoRow("Voltage", "\(battery.voltageMV) mV  (\(String(format: "%.3f", Double(battery.voltageMV) / 1000.0)) V)")
            InfoRow("Current (instant)", "\(battery.instantAmperageMa) mA")
            InfoRow("Current (avg)", "\(battery.avgAmperageMa) mA")

            let watts = abs(battery.batteryWatts)
            let direction = battery.instantAmperageMa > 0 ? "charging" : "discharging"
            InfoRow("Power", String(format: "%.2f W (%@)", watts, direction))

            if !battery.cellVoltages.isEmpty {
                Divider()
                let cellsStr = battery.cellVoltages.map { "\($0) mV" }.joined(separator: "  /  ")
                InfoRow("Cells", cellsStr)

                if let delta = battery.cellBalanceDelta {
                    HStack {
                        Text("Cell Balance")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(delta) mV delta")
                        Image(systemName: delta < 20 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(delta < 20 ? .green : .yellow)
                    }
                    .font(.callout)
                }
            }

            if battery.temperature > 0 {
                Divider()
                let tempIcon: String = battery.temperatureC > 40 ? "flame.fill" : (battery.temperatureC < 10 ? "snowflake" : "thermometer.medium")
                let tempColor: Color = battery.temperatureC > 40 ? .red : (battery.temperatureC < 10 ? .blue : .green)
                HStack {
                    Text("Temperature")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: tempIcon)
                        .foregroundStyle(tempColor)
                    Text(String(format: "%.1f°C  /  %.1f°F", battery.temperatureC, battery.temperatureF))
                }
                .font(.callout)
            }
        }
    }
}

// MARK: - Health Section

struct HealthSection: View {
    let battery: BatteryData

    var body: some View {
        SectionCard(title: "Health", icon: "heart.fill") {
            InfoRow("Charge", "\(battery.rawCapacityMah) / \(battery.rawMaxCapacityMah) mAh")
            InfoRow("Design Capacity", "\(battery.designCapacityMah) mAh")

            if battery.nominalCapacityMah > 0 {
                InfoRow("Nominal Capacity", "\(battery.nominalCapacityMah) mAh")
            }

            if let health = battery.healthPercent {
                Divider()
                HStack {
                    Text("Health")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", health))
                        .bold()
                    Image(systemName: health >= 80 ? "checkmark.circle.fill" : (health >= 60 ? "exclamationmark.triangle.fill" : "xmark.circle.fill"))
                        .foregroundStyle(health >= 80 ? .green : (health >= 60 ? .yellow : .red))
                }
                .font(.callout)
                ProgressView(value: min(health, 100), total: 100)
                    .tint(health >= 80 ? .green : (health >= 60 ? .yellow : .red))
            }

            Divider()
            InfoRow("Cycle Count", "\(battery.cycleCount) / \(battery.designCycleCount)")
            if let cycleLife = battery.cycleLifePercent {
                InfoRow("Cycle Life Used", String(format: "%.1f%%", cycleLife))
            }

            if !battery.serial.isEmpty {
                InfoRow("Serial", battery.serial)
            }
            if !battery.deviceName.isEmpty {
                InfoRow("Gauge IC", "\(battery.deviceName) (fw v\(battery.gaugeFirmwareVersion))")
            }

            if battery.permanentFailureStatus != 0 {
                Label("Permanent Failure: \(battery.permanentFailureStatus)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if battery.cellDisconnectCount > 0 {
                Label("Cell Disconnect Count: \(battery.cellDisconnectCount)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
        }
    }
}

// MARK: - Charger IC Section

struct ChargerICSection: View {
    let battery: BatteryData

    var body: some View {
        SectionCard(title: "Charger IC", icon: "cpu") {
            if battery.chargingVoltageMV > 0 {
                InfoRow("Cell Voltage", "\(battery.chargingVoltageMV) mV/cell  (\(battery.chargingVoltageMV * 3) mV pack)")
            }
            if battery.chargingCurrentMA > 0 {
                InfoRow("Current", "\(battery.chargingCurrentMA) mA")
            }
            if let cw = battery.chargerWatts {
                InfoRow("Charge Power", String(format: "%.1f W (into battery)", cw))
            }
            if battery.vacVoltageLimit > 0 {
                InfoRow("Vac Limit", "\(battery.vacVoltageLimit) mV/cell")
            }
            if battery.notChargingReason != 0 {
                WarningRow("Not Charging", "reason code \(battery.notChargingReason)")
            }
            if battery.slowChargingReason != 0 {
                WarningRow("Slow Charging", "reason code \(battery.slowChargingReason)")
            }
            if battery.chargerInhibitReason != 0 {
                WarningRow("Inhibited", "reason code \(battery.chargerInhibitReason)")
            }
            if battery.thermallyLimitedSeconds > 0 {
                WarningRow("Thermally Limited", "\(battery.thermallyLimitedSeconds)s")
            }
        }
    }
}

// MARK: - Adapter Section

struct AdapterSection: View {
    let battery: BatteryData

    var body: some View {
        SectionCard(title: "Adapter", icon: "powerplug.fill") {
            InfoRow("Type", "\(battery.adapterDescription)\(battery.isWireless ? " (wireless)" : "")")
            InfoRow("Rated", "\(battery.adapterWatts) W")

            if battery.adapterVoltage > 0 && battery.adapterCurrent > 0 {
                let v = Double(battery.adapterVoltage) / 1000.0
                let ma = battery.adapterCurrent
                if let aw = battery.adapterActualWatts {
                    InfoRow("Negotiated", String(format: "%.0fV × %d mA = %.1f W", v, ma, aw))
                }
            }
            if battery.portMaxPower > 0 {
                InfoRow("Port Max", String(format: "%.0f W", Double(battery.portMaxPower) / 1000.0))
            }

            // USB-PD table
            if !battery.pdOptions.isEmpty {
                Divider()
                Text("USB-PD Power Delivery Options")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("Idx").bold()
                        Text("Voltage").bold()
                        Text("Current").bold()
                        Text("Power").bold()
                        Text("").bold()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    ForEach(battery.pdOptions) { pdo in
                        GridRow {
                            Text("\(pdo.id)")
                            Text(String(format: "%.1f V", pdo.voltageV))
                            Text(String(format: "%.0f mA", pdo.currentA * 1000))
                            Text(String(format: "%.1f W", pdo.watts))
                            if pdo.id == battery.hvcIndex {
                                Image(systemName: "arrowtriangle.left.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption2)
                            } else {
                                Text("")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(pdo.id == battery.hvcIndex ? .primary : .secondary)
                    }
                }
            }
        }
    }
}

// MARK: - System Power Section

struct SystemPowerSection: View {
    let battery: BatteryData

    var body: some View {
        SectionCard(title: "System Power", icon: "bolt.circle.fill") {
            if battery.systemPowerIn > 0 {
                InfoRow("Power In", String(format: "%.2f W (from adapter)", Double(battery.systemPowerIn) / 1000.0))
            }
            if battery.systemLoad > 0 {
                let sysConsumption = battery.isCharging
                    ? max(0, Double(battery.systemPowerIn) - abs(Double(battery.batteryPower))) / 1000.0
                    : Double(battery.systemLoad) / 1000.0
                InfoRow("System Load", String(format: "%.2f W", sysConsumption))
            }
            if battery.batteryPower != 0 {
                let batW = abs(Double(battery.batteryPower)) / 1000.0
                let label = battery.isCharging ? "charging" : "discharging"
                InfoRow("Battery Flow", String(format: "%.2f W (%@)", batW, label))
            }
            if battery.wallEnergyEstimate > 0 {
                InfoRow("Wall Energy", String(format: "%.2f W (total from wall)", Double(battery.wallEnergyEstimate) / 1000.0))
            }
            if battery.systemVoltageIn > 0 {
                InfoRow("Input Rail", String(format: "%.2f V  /  %d mA", Double(battery.systemVoltageIn) / 1000.0, battery.systemCurrentIn))
            }
            if battery.adapterEfficiencyLoss > 0 {
                InfoRow("Adapter Loss", String(format: "%.2f W", Double(battery.adapterEfficiencyLoss) / 1000.0))
                if battery.systemPowerIn > 0 {
                    let efficiency = (1.0 - Double(battery.adapterEfficiencyLoss) / Double(battery.systemPowerIn + battery.adapterEfficiencyLoss)) * 100.0
                    InfoRow("Efficiency", String(format: "%.1f%%", efficiency))
                }
            }
        }
    }
}

// MARK: - Power Flow Section

struct PowerFlowSection: View {
    let battery: BatteryData

    var body: some View {
        SectionCard(title: "Power Flow", icon: "arrow.right.arrow.left") {
            let wallW = Double(battery.systemPowerIn + battery.adapterEfficiencyLoss) / 1000.0
            let loadW = battery.isCharging
                ? max(0, Double(battery.systemPowerIn) - abs(Double(battery.batteryPower))) / 1000.0
                : Double(battery.systemLoad) / 1000.0
            let batW = abs(Double(battery.batteryPower)) / 1000.0
            let lossW = Double(battery.adapterEfficiencyLoss) / 1000.0

            HStack(spacing: 0) {
                FlowNode(label: "Wall", value: String(format: "%.1fW", wallW), color: .orange)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                FlowNode(label: "Adapter", value: "\(battery.adapterWatts)W rated", color: .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                FlowBranch(icon: "desktopcomputer", label: "System Load", value: String(format: "%.1f W", loadW))
                FlowBranch(icon: "battery.100", label: "Battery", value: String(format: "%@%.1f W (%@)", battery.isCharging ? "-" : "+", batW, battery.isCharging ? "charging" : "discharging"))
                FlowBranch(icon: "flame", label: "Losses", value: String(format: "%.1f W", lossW))
            }
            .padding(.leading, 8)
        }
    }
}

// MARK: - Reusable Components

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }
}

struct WarningRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }
}

struct FlowNode: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct FlowBranch: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Image(systemName: icon)
                .font(.caption)
                .frame(width: 16)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.caption)
    }
}

// MARK: - Helpers

func formatTime(_ minutes: Int) -> String {
    if minutes >= 65535 { return "calculating..." }
    let h = minutes / 60
    let m = minutes % 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
}

#Preview {
    ContentView()
}
