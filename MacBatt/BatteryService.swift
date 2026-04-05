import Foundation
import IOKit
import Observation

@Observable
final class BatteryService {
    var battery = BatteryData()
    var lastUpdated = Date()

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        guard let props = Self.readSmartBattery() else { return }

        var b = BatteryData()

        // Battery basics
        b.voltageMV = props["Voltage"] as? Int ?? 0
        b.instantAmperageMa = Self.signedInt(props["InstantAmperage"] as? Int)
        b.avgAmperageMa = Self.signedInt(props["Amperage"] as? Int)
        b.soc = props["CurrentCapacity"] as? Int ?? 0
        b.rawCapacityMah = props["AppleRawCurrentCapacity"] as? Int ?? 0
        b.rawMaxCapacityMah = props["AppleRawMaxCapacity"] as? Int ?? 0
        b.designCapacityMah = props["DesignCapacity"] as? Int ?? 0
        b.nominalCapacityMah = props["NominalChargeCapacity"] as? Int ?? 0
        b.cycleCount = props["CycleCount"] as? Int ?? 0
        b.designCycleCount = props["DesignCycleCount9C"] as? Int ?? 0
        b.temperature = props["Temperature"] as? Int ?? 0
        b.isCharging = props["IsCharging"] as? Bool ?? false
        b.fullyCharged = props["FullyCharged"] as? Bool ?? false
        b.externalConnected = props["ExternalConnected"] as? Bool ?? false
        b.externalChargeCapable = props["ExternalChargeCapable"] as? Bool ?? false
        b.atCriticalLevel = props["AtCriticalLevel"] as? Bool ?? false
        b.serial = props["Serial"] as? String ?? ""
        b.deviceName = props["DeviceName"] as? String ?? ""
        b.timeRemaining = props["TimeRemaining"] as? Int ?? 65535
        b.avgTimeToFull = props["AvgTimeToFull"] as? Int ?? 65535
        b.avgTimeToEmpty = props["AvgTimeToEmpty"] as? Int ?? 65535
        b.permanentFailureStatus = props["PermanentFailureStatus"] as? Int ?? 0
        b.cellDisconnectCount = props["BatteryCellDisconnectCount"] as? Int ?? 0
        b.gaugeFirmwareVersion = props["GasGaugeFirmwareVersion"] as? Int ?? 0
        b.virtualTemperature = props["VirtualTemperature"] as? Int ?? 0

        // Cell voltages from BatteryData
        if let batteryData = props["BatteryData"] as? [String: Any],
           let cellVoltages = batteryData["CellVoltage"] as? [Int] {
            b.cellVoltages = cellVoltages
        }

        // Adapter details
        if let adapterDetails = props["AdapterDetails"] as? [String: Any] {
            b.adapterWatts = adapterDetails["Watts"] as? Int ?? 0
            b.adapterVoltage = adapterDetails["AdapterVoltage"] as? Int ?? 0
            b.adapterCurrent = adapterDetails["Current"] as? Int ?? 0
            b.adapterDescription = adapterDetails["Description"] as? String ?? ""
            b.isWireless = adapterDetails["IsWireless"] as? Bool ?? false

            // USB-PD menu
            if let hvcMenu = adapterDetails["UsbHvcMenu"] as? [[String: Any]] {
                b.pdOptions = hvcMenu.compactMap { entry in
                    guard let idx = entry["Index"] as? Int,
                          let maxCurrent = entry["MaxCurrent"] as? Int,
                          let maxVoltage = entry["MaxVoltage"] as? Int else { return nil }
                    let volts = Double(maxVoltage) / 1000.0
                    let amps = Double(maxCurrent) / 1000.0
                    let watts = volts * amps
                    return PDOption(id: idx, voltageV: volts, currentA: amps, watts: watts)
                }
            }
            b.hvcIndex = adapterDetails["UsbHvcHvcIndex"] as? Int ?? -1
        }

        // Charger data from ChargerData
        if let chargerData = props["ChargerData"] as? [String: Any] {
            b.chargingVoltageMV = chargerData["ChargingVoltage"] as? Int ?? 0
            b.chargingCurrentMA = chargerData["ChargingCurrent"] as? Int ?? 0
            b.notChargingReason = chargerData["NotChargingReason"] as? Int ?? 0
            b.slowChargingReason = chargerData["SlowChargingReason"] as? Int ?? 0
            b.chargerInhibitReason = chargerData["ChargerInhibitReason"] as? Int ?? 0
            b.thermallyLimitedSeconds = chargerData["TimeChargingThermallyLimited"] as? Int ?? 0
            b.vacVoltageLimit = chargerData["VacVoltageLimit"] as? Int ?? 0
        }

        // System power telemetry from PowerTelemetryData or top-level
        // These may be nested in different places depending on macOS version
        if let telemetry = props["PowerTelemetryData"] as? [String: Any] {
            b.systemPowerIn = telemetry["SystemPowerIn"] as? Int ?? 0
            b.systemLoad = telemetry["SystemLoad"] as? Int ?? 0
            b.batteryPower = telemetry["BatteryPower"] as? Int ?? 0
            b.wallEnergyEstimate = telemetry["WallEnergyEstimate"] as? Int ?? 0
            b.systemVoltageIn = telemetry["SystemVoltageIn"] as? Int ?? 0
            b.systemCurrentIn = telemetry["SystemCurrentIn"] as? Int ?? 0
            b.adapterEfficiencyLoss = telemetry["AdapterEfficiencyLoss"] as? Int ?? 0
            b.systemEnergyConsumed = telemetry["SystemEnergyConsumed"] as? Int ?? 0
        }

        // Port max power - scan for active port
        if let portData = props["AppleRawAdapterDetails"] as? [[String: Any]] {
            for port in portData {
                if let maxPower = port["PortControllerMaxPower"] as? Int, maxPower > 0 {
                    b.portMaxPower = maxPower
                }
            }
        }

        battery = b
        lastUpdated = Date()
    }

    // MARK: - IOKit helpers

    private static func readSmartBattery() -> [String: Any]? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var cfProps: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &cfProps, kCFAllocatorDefault, 0)
        guard result == kIOReturnSuccess, let props = cfProps?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return props
    }

    private static func signedInt(_ val: Int?) -> Int {
        guard let v = val else { return 0 }
        if v > Int(Int32.max) { return v - Int(UInt32.max) - 1 }
        return v
    }
}
