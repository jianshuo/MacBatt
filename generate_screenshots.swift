import AppKit
import SwiftUI

// MARK: - Mock data for attractive screenshots

func mockChargingBattery() -> BatteryData {
    var b = BatteryData()
    b.voltageMV = 12_832
    b.instantAmperageMa = 1_850
    b.avgAmperageMa = 1_780
    b.soc = 72
    b.rawCapacityMah = 5_123
    b.rawMaxCapacityMah = 6_905
    b.designCapacityMah = 7_200
    b.nominalCapacityMah = 7_060
    b.cycleCount = 128
    b.designCycleCount = 1_000
    b.temperature = 3_340  // 33.4°C
    b.isCharging = true
    b.fullyCharged = false
    b.externalConnected = true
    b.externalChargeCapable = true
    b.serial = "F5Y2345ABCDE"
    b.deviceName = "bq40z651"
    b.gaugeFirmwareVersion = 2
    b.avgTimeToFull = 62
    b.avgTimeToEmpty = 65535
    b.cellVoltages = [4278, 4276, 4278]

    // Adapter
    b.adapterWatts = 96
    b.adapterVoltage = 20_000
    b.adapterCurrent = 3_250
    b.adapterDescription = "USB-C 96W"
    b.isWireless = false
    b.hvcIndex = 4

    b.pdOptions = [
        PDOption(id: 1, voltageV: 5.0,  currentA: 3.0, watts: 15.0),
        PDOption(id: 2, voltageV: 9.0,  currentA: 3.0, watts: 27.0),
        PDOption(id: 3, voltageV: 15.0, currentA: 3.0, watts: 45.0),
        PDOption(id: 4, voltageV: 20.0, currentA: 4.8, watts: 96.0),
    ]

    // Charger IC
    b.chargingVoltageMV = 4380
    b.chargingCurrentMA = 3_900

    // System power
    b.systemPowerIn = 58_200
    b.systemLoad = 34_600
    b.batteryPower = 22_100
    b.wallEnergyEstimate = 62_400
    b.systemVoltageIn = 20_100
    b.systemCurrentIn = 2_900
    b.adapterEfficiencyLoss = 4_200
    b.portMaxPower = 100_000

    return b
}

// MARK: - Screenshot wrapper view

struct ScreenshotContentView: View {
    let battery: BatteryData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PowerFlowDiagram(battery: battery)
                StatusHeader(battery: battery)
                BatterySection(battery: battery)
                HealthSection(battery: battery)
                ChargerICSection(battery: battery)
                AdapterSection(battery: battery)
                SystemPowerSection(battery: battery)
                PowerFlowSection(battery: battery)

                HStack {
                    Text("Updated: 10:42:15 AM")
                    Spacer()
                    Text("Refresh: 2s")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(width: 500, height: 780)
        .transaction { $0.animation = nil }
    }
}

// MARK: - Rendering

func renderView<V: View>(_ view: V, size: NSSize) -> NSImage? {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(origin: .zero, size: size)

    // Force layout
    hostingView.layoutSubtreeIfNeeded()

    guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        return nil
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

    let image = NSImage(size: size)
    image.addRepresentation(bitmapRep)
    return image
}

func createScreenshot(appImage: NSImage, targetWidth: Int, targetHeight: Int) -> Data? {
    // Create a bitmap at exact pixel dimensions (1x, no Retina scaling)
    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetWidth,
        pixelsHigh: targetHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmapRep.size = NSSize(width: targetWidth, height: targetHeight)

    let ctx = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    let bgRect = NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight)

    // Dark gradient background
    let gradient = NSGradient(colors: [
        NSColor(red: 0.07, green: 0.07, blue: 0.14, alpha: 1.0),
        NSColor(red: 0.12, green: 0.08, blue: 0.20, alpha: 1.0),
        NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0),
    ])!
    gradient.draw(in: bgRect, angle: 135)

    // Scale the app view to fit nicely
    let appW: CGFloat = 500
    let appH: CGFloat = 780
    let scale = min(
        CGFloat(targetHeight) * 0.82 / appH,
        CGFloat(targetWidth) * 0.60 / appW
    )
    let scaledW = appW * scale
    let scaledH = appH * scale
    let x = (CGFloat(targetWidth) - scaledW) / 2
    let y = (CGFloat(targetHeight) - scaledH) / 2

    // Drop shadow behind the app
    let shadowRect = NSRect(x: x + 4, y: y - 4, width: scaledW, height: scaledH)
    NSColor.black.withAlphaComponent(0.4).setFill()
    NSBezierPath(roundedRect: shadowRect, xRadius: 14, yRadius: 14).fill()

    // Clip to rounded rect and draw app image
    let appRect = NSRect(x: x, y: y, width: scaledW, height: scaledH)
    let clipPath = NSBezierPath(roundedRect: appRect, xRadius: 12, yRadius: 12)
    ctx.cgContext.saveGState()
    clipPath.addClip()
    appImage.draw(in: appRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    ctx.cgContext.restoreGState()

    // Subtle border
    NSColor.white.withAlphaComponent(0.15).setStroke()
    let borderPath = NSBezierPath(roundedRect: appRect, xRadius: 12, yRadius: 12)
    borderPath.lineWidth = 1.5
    borderPath.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        return nil
    }
    return pngData
}

// MARK: - Main

@main
struct ScreenshotApp {
    static func main() {
        let battery = mockChargingBattery()
        let contentView = ScreenshotContentView(battery: battery)

        guard let appImage = renderView(contentView, size: NSSize(width: 500, height: 780)) else {
            print("ERROR: Failed to render app view")
            Foundation.exit(1)
        }

        let outputDir = "screenshots"
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let sizes: [(Int, Int)] = [
            (1280, 800),
            (1440, 900),
            (2560, 1600),
            (2880, 1800),
        ]

        for (w, h) in sizes {
            guard let pngData = createScreenshot(appImage: appImage, targetWidth: w, targetHeight: h) else {
                print("ERROR: Failed to create \(w)x\(h)")
                continue
            }
            let path = "\(outputDir)/MacBatt_\(w)x\(h).png"
            try! pngData.write(to: URL(fileURLWithPath: path))
            print("✓ Saved \(path)")
        }

        print("\nDone! Screenshots saved to ./screenshots/")
    }
}
