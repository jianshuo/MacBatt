import Foundation

struct BatteryData {
    // Battery basics
    var voltageMV: Int = 0
    var instantAmperageMa: Int = 0
    var avgAmperageMa: Int = 0
    var soc: Int = 0
    var rawCapacityMah: Int = 0
    var rawMaxCapacityMah: Int = 0
    var designCapacityMah: Int = 0
    var nominalCapacityMah: Int = 0
    var cycleCount: Int = 0
    var designCycleCount: Int = 0
    var temperature: Int = 0  // centi-degrees C
    var isCharging: Bool = false
    var fullyCharged: Bool = false
    var externalConnected: Bool = false
    var externalChargeCapable: Bool = false
    var atCriticalLevel: Bool = false
    var serial: String = ""
    var deviceName: String = ""
    var timeRemaining: Int = 0
    var avgTimeToFull: Int = 0
    var avgTimeToEmpty: Int = 0
    var permanentFailureStatus: Int = 0
    var cellDisconnectCount: Int = 0
    var gaugeFirmwareVersion: Int = 0
    var virtualTemperature: Int = 0

    // Cell voltages
    var cellVoltages: [Int] = []

    // Adapter details
    var adapterWatts: Int = 0
    var adapterVoltage: Int = 0
    var adapterCurrent: Int = 0
    var adapterDescription: String = ""
    var isWireless: Bool = false

    // USB-PD menu
    var pdOptions: [PDOption] = []
    var hvcIndex: Int = -1

    // Charger IC
    var chargingVoltageMV: Int = 0
    var chargingCurrentMA: Int = 0
    var notChargingReason: Int = 0
    var slowChargingReason: Int = 0
    var chargerInhibitReason: Int = 0
    var thermallyLimitedSeconds: Int = 0
    var vacVoltageLimit: Int = 0

    // System power telemetry
    var systemPowerIn: Int = 0
    var systemLoad: Int = 0
    var batteryPower: Int = 0
    var wallEnergyEstimate: Int = 0
    var systemVoltageIn: Int = 0
    var systemCurrentIn: Int = 0
    var adapterEfficiencyLoss: Int = 0
    var systemEnergyConsumed: Int = 0

    // Port controller
    var portMaxPower: Int = 0

    // Computed properties
    var temperatureC: Double { Double(temperature) / 100.0 }
    var temperatureF: Double { temperatureC * 9.0 / 5.0 + 32.0 }

    var healthPercent: Double? {
        guard rawMaxCapacityMah > 0, designCapacityMah > 0 else { return nil }
        return Double(rawMaxCapacityMah) / Double(designCapacityMah) * 100.0
    }

    var batteryWatts: Double {
        Double(voltageMV) * Double(instantAmperageMa) / 1_000_000.0
    }

    var chargerWatts: Double? {
        guard chargingVoltageMV > 0, chargingCurrentMA > 0 else { return nil }
        return Double(chargingVoltageMV) * 3.0 * Double(chargingCurrentMA) / 1_000_000.0
    }

    var adapterActualWatts: Double? {
        guard adapterVoltage > 0, adapterCurrent > 0 else { return nil }
        return Double(adapterVoltage) * Double(adapterCurrent) / 1_000_000.0
    }

    var statusText: String {
        if fullyCharged { return "Fully Charged" }
        if isCharging { return "Charging" }
        if externalConnected { return "Plugged in (not charging)" }
        return "On Battery"
    }

    var statusIcon: String {
        if fullyCharged { return "checkmark.circle.fill" }
        if isCharging { return "bolt.fill" }
        if externalConnected { return "powerplug.fill" }
        return "battery.100" // will be adjusted by level
    }

    var cycleLifePercent: Double? {
        guard cycleCount > 0, designCycleCount > 0 else { return nil }
        return Double(cycleCount) / Double(designCycleCount) * 100.0
    }

    var cellBalanceDelta: Int? {
        guard cellVoltages.count > 1,
              let maxV = cellVoltages.max(),
              let minV = cellVoltages.min() else { return nil }
        return maxV - minV
    }
}

struct PDOption: Identifiable {
    let id: Int  // index
    let voltageV: Double
    let currentA: Double
    let watts: Double
}
