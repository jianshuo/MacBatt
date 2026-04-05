#!/usr/bin/env python3
"""macOS Power Monitor — comprehensive battery & charger dashboard."""

import subprocess, re, time, os, sys

def get_battery_data():
    raw = subprocess.check_output(["ioreg", "-rn", "AppleSmartBattery"], text=True)
    return raw

def top_level(data, key):
    """Extract a top-level ioreg key (indented, uses ' = ')."""
    m = re.search(rf'^\s+"{key}"\s*=\s*(.+)$', data, re.MULTILINE)
    return m.group(1).strip() if m else None

def nested(data, key):
    """Extract a nested key (inside dict, uses 'key'=value)."""
    m = re.search(rf'"{key}"=([^,}}]+)', data)
    return m.group(1).strip() if m else None

def to_int(val):
    if val is None: return None
    try: return int(val)
    except: return None

def fix_signed(val, bits=32):
    if val is None: return None
    if bits == 32 and val > 2**31: return val - 2**32
    if bits == 64 and val > 2**63: return val - 2**64
    return val

def format_time(minutes):
    if minutes is None or minutes >= 65535: return "calculating..."
    h, m = divmod(minutes, 60)
    return f"{h}h {m}m" if h > 0 else f"{m}m"

def bar(pct, width=30):
    filled = int(width * pct / 100)
    return f"[{'█' * filled}{'░' * (width - filled)}]"

def parse_usb_pd_menu(data):
    """Parse USB-PD power delivery options from AdapterDetails (not Raw)."""
    # Use only the AdapterDetails line (not AppleRawAdapterDetails) to avoid duplicates
    m = re.search(r'^\s+"AdapterDetails"\s*=\s*(.+)$', data, re.MULTILINE)
    if not m: return []
    adapter_line = m.group(1)
    pdos = []
    for m in re.finditer(r'\{"Index"=(\d+),"MaxCurrent"=(\d+),"MaxVoltage"=(\d+)\}', adapter_line):
        idx, ma, mv = int(m.group(1)), int(m.group(2)), int(m.group(3))
        watts = mv * ma / 1_000_000
        pdos.append((idx, mv/1000, ma/1000, watts))
    return pdos

def parse_cell_voltages(data):
    """Parse individual cell voltages from BatteryData."""
    m = re.search(r'"CellVoltage"=\(([^)]+)\)', data)
    if m:
        return [int(x.strip()) for x in m.group(1).split(',')]
    return []

def main():
    data = get_battery_data()

    # ── Battery basics ──
    voltage_mv      = to_int(top_level(data, "Voltage"))
    amperage_ma     = fix_signed(to_int(top_level(data, "InstantAmperage")))
    avg_amperage_ma = fix_signed(to_int(top_level(data, "Amperage")))
    soc             = to_int(top_level(data, "CurrentCapacity"))
    raw_cap_mah     = to_int(top_level(data, "AppleRawCurrentCapacity"))
    raw_max_mah     = to_int(top_level(data, "AppleRawMaxCapacity"))
    design_cap_mah  = to_int(top_level(data, "DesignCapacity"))
    nom_cap_mah     = to_int(top_level(data, "NominalChargeCapacity"))
    cycle_count     = to_int(top_level(data, "CycleCount"))
    design_cycles   = to_int(top_level(data, "DesignCycleCount9C"))
    temperature     = to_int(top_level(data, "Temperature"))
    is_charging     = top_level(data, "IsCharging") == "Yes"
    fully_charged   = top_level(data, "FullyCharged") == "Yes"
    ext_connected   = top_level(data, "ExternalConnected") == "Yes"
    ext_capable     = top_level(data, "ExternalChargeCapable") == "Yes"
    at_critical     = top_level(data, "AtCriticalLevel") == "Yes"
    serial          = top_level(data, "Serial")
    device_name     = top_level(data, "DeviceName")
    time_remaining  = to_int(top_level(data, "TimeRemaining"))
    avg_to_full     = to_int(top_level(data, "AvgTimeToFull"))
    avg_to_empty    = to_int(top_level(data, "AvgTimeToEmpty"))
    perm_fail       = to_int(top_level(data, "PermanentFailureStatus"))
    cell_disconnect = to_int(top_level(data, "BatteryCellDisconnectCount"))
    gauge_fw        = to_int(top_level(data, "GasGaugeFirmwareVersion"))
    virtual_temp    = to_int(top_level(data, "VirtualTemperature"))

    # ── Cell-level data ──
    cell_voltages = parse_cell_voltages(data)

    # ── Battery health ──
    health_pct = None
    if raw_max_mah and design_cap_mah:
        health_pct = round(raw_max_mah / design_cap_mah * 100, 1)

    # ── Temperature ──
    temp_c = temperature / 100.0 if temperature else None
    temp_f = temp_c * 9/5 + 32 if temp_c else None

    # ── Power calculations ──
    battery_watts = None
    if voltage_mv is not None and amperage_ma is not None:
        battery_watts = round(voltage_mv * amperage_ma / 1_000_000, 2)

    # ── Adapter details ──
    adapter_watts     = to_int(nested(data, "Watts"))
    adapter_voltage   = to_int(nested(data, "AdapterVoltage"))
    adapter_current   = to_int(nested(data, "Current"))
    adapter_desc      = nested(data, "Description")
    if adapter_desc: adapter_desc = adapter_desc.strip('"')
    is_wireless       = nested(data, "IsWireless")

    # ── USB-PD negotiation menu ──
    pd_menu = parse_usb_pd_menu(data)
    hvc_index = to_int(nested(data, "UsbHvcHvcIndex"))

    # ── Charger IC data ──
    charging_voltage_mv = to_int(nested(data, "ChargingVoltage"))
    charging_current_ma = to_int(nested(data, "ChargingCurrent"))
    not_charging_reason = to_int(nested(data, "NotChargingReason"))
    slow_charging       = to_int(nested(data, "SlowChargingReason"))
    charger_inhibit     = to_int(nested(data, "ChargerInhibitReason"))
    thermal_limited     = to_int(nested(data, "TimeChargingThermallyLimited"))
    vac_limit           = to_int(nested(data, "VacVoltageLimit"))

    # ── System power telemetry ──
    sys_power_in    = to_int(nested(data, "SystemPowerIn"))
    sys_load        = to_int(nested(data, "SystemLoad"))
    bat_power       = to_int(nested(data, "BatteryPower"))
    wall_energy     = to_int(nested(data, "WallEnergyEstimate"))
    sys_voltage_in  = to_int(nested(data, "SystemVoltageIn"))
    sys_current_in  = to_int(nested(data, "SystemCurrentIn"))
    adapter_loss    = to_int(nested(data, "AdapterEfficiencyLoss"))
    sys_energy      = to_int(nested(data, "SystemEnergyConsumed"))

    # ── Port controller (connected port) ──
    port_max_power = None
    for m in re.finditer(r'"PortControllerMaxPower"=(\d+)', data):
        val = int(m.group(1))
        if val > 0: port_max_power = val  # find the active port

    # ── Charger actual watts ──
    charger_watts = None
    if charging_voltage_mv and charging_current_ma:
        # ChargingVoltage is per-cell mV, ChargingCurrent is mA
        # Pack has 3 cells in series
        charger_watts = round(charging_voltage_mv * 3 * charging_current_ma / 1_000_000, 2)

    # ── Adapter actual delivery ──
    adapter_actual_watts = None
    if adapter_voltage and adapter_current:
        adapter_actual_watts = round(adapter_voltage * adapter_current / 1_000_000, 2)

    # ── Display ──
    os.system('clear')
    print("⚡ macOS Power Monitor")
    print("━" * 56)

    # Status line
    if fully_charged:
        status = "✅ Fully Charged"
    elif is_charging:
        status = "🔋 Charging"
    elif ext_connected:
        status = "🔌 Plugged in (not charging)"
    else:
        status = "🔋 On Battery (discharging)"

    print(f"\n  Status:        {status}")
    if at_critical:
        print("  ⚠️  CRITICAL BATTERY LEVEL")
    print(f"  Battery:       {soc}%  {bar(soc or 0)}")

    # Time estimate
    if is_charging and avg_to_full is not None:
        print(f"  Time to Full:  {format_time(avg_to_full)}")
    elif not ext_connected and avg_to_empty is not None:
        print(f"  Time Left:     {format_time(avg_to_empty)}")
    if time_remaining is not None and time_remaining < 65535:
        print(f"  Est. Remain:   {format_time(time_remaining)}")

    # ── Battery Details ──
    print(f"\n{'── Battery ─' * 1}{'─' * 44}")
    print(f"  Voltage:       {voltage_mv} mV  ({voltage_mv/1000:.3f} V)")
    print(f"  Current:       {amperage_ma} mA (instant)  /  {avg_amperage_ma} mA (avg)")
    if battery_watts is not None:
        direction = "charging" if amperage_ma > 0 else "discharging"
        print(f"  Power:         {abs(battery_watts):.2f} W ({direction})")

    # Cell voltages
    if cell_voltages:
        cells_str = "  /  ".join(f"{v} mV" for v in cell_voltages)
        cell_diff = max(cell_voltages) - min(cell_voltages)
        print(f"  Cells:         {cells_str}")
        print(f"  Cell Balance:  {cell_diff} mV delta {'✅' if cell_diff < 20 else '⚠️'}")

    # Temperature
    if temp_c is not None:
        temp_status = "🔥" if temp_c > 40 else ("❄️" if temp_c < 10 else "✅")
        print(f"  Temperature:   {temp_c:.1f}°C  /  {temp_f:.1f}°F  {temp_status}")

    # ── Capacity & Health ──
    print(f"\n{'── Health ─' * 1}{'─' * 45}")
    print(f"  Charge:        {raw_cap_mah} / {raw_max_mah} mAh")
    print(f"  Design Cap:    {design_cap_mah} mAh")
    if nom_cap_mah:
        print(f"  Nominal Cap:   {nom_cap_mah} mAh")
    if health_pct is not None:
        health_bar = bar(min(health_pct, 100))
        health_status = "✅" if health_pct >= 80 else ("⚠️" if health_pct >= 60 else "❌")
        print(f"  Health:        {health_pct}%  {health_bar}  {health_status}")
    print(f"  Cycle Count:   {cycle_count} / {design_cycles}")
    if cycle_count and design_cycles:
        cycle_pct = round(cycle_count / design_cycles * 100, 1)
        print(f"  Cycle Life:    {cycle_pct}% used")
    if serial:
        serial = serial.strip('"')
        print(f"  Serial:        {serial}")
    if device_name:
        device_name = device_name.strip('"')
        print(f"  Gauge IC:      {device_name} (fw v{gauge_fw})")
    if perm_fail:
        print(f"  ⚠️  Permanent Failure Status: {perm_fail}")
    if cell_disconnect:
        print(f"  ⚠️  Cell Disconnect Count: {cell_disconnect}")

    # ── Charger IC ──
    if ext_connected:
        print(f"\n{'── Charger IC ─' * 1}{'─' * 41}")
        if charging_voltage_mv:
            print(f"  Cell Voltage:  {charging_voltage_mv} mV/cell  ({charging_voltage_mv * 3} mV pack)")
        if charging_current_ma:
            print(f"  Current:       {charging_current_ma} mA")
        if charger_watts:
            print(f"  Charge Power:  {charger_watts:.1f} W (into battery)")
        if vac_limit:
            print(f"  Vac Limit:     {vac_limit} mV/cell")
        if not_charging_reason:
            print(f"  Not Charging:  reason code {not_charging_reason}")
        if slow_charging:
            print(f"  ⚠️  Slow Charging: reason code {slow_charging}")
        if charger_inhibit:
            print(f"  ⚠️  Inhibited: reason code {charger_inhibit}")
        if thermal_limited and thermal_limited > 0:
            print(f"  ⚠️  Thermally Limited: {thermal_limited}s")

    # ── Adapter ──
    if ext_connected:
        print(f"\n{'── Adapter ─' * 1}{'─' * 44}")
        print(f"  Type:          {adapter_desc or 'unknown'}  {'(wireless)' if is_wireless == 'Yes' else ''}")
        print(f"  Rated:         {adapter_watts} W")
        if adapter_voltage and adapter_current:
            print(f"  Negotiated:    {adapter_voltage/1000:.0f}V x {adapter_current} mA = {adapter_actual_watts:.1f} W")
        if port_max_power:
            print(f"  Port Max:      {port_max_power/1000:.0f} W")

        # USB-PD PDO table
        if pd_menu:
            print(f"\n  USB-PD Power Delivery Options:")
            print(f"  {'Idx':>3}  {'Voltage':>8}  {'Current':>9}  {'Power':>7}  Active")
            print(f"  {'───':>3}  {'────────':>8}  {'─────────':>9}  {'───────':>7}  ──────")
            for idx, volts, amps, watts in pd_menu:
                active = " ◀" if hvc_index is not None and idx == hvc_index else ""
                print(f"  {idx:>3}  {volts:>7.1f}V  {amps*1000:>7.0f} mA  {watts:>5.1f} W{active}")

    # ── System Power Telemetry ──
    print(f"\n{'── System Power ─' * 1}{'─' * 39}")
    if sys_power_in is not None:
        print(f"  Power In:      {sys_power_in/1000:.2f} W  (from adapter)")
    if sys_load is not None:
        print(f"  System Load:   {sys_load/1000:.2f} W")
    if bat_power is not None:
        print(f"  Battery Flow:  {bat_power/1000:.2f} W")
    if wall_energy is not None:
        print(f"  Wall Energy:   {wall_energy/1000:.2f} W  (total from wall)")
    if sys_voltage_in is not None:
        print(f"  Input Rail:    {sys_voltage_in/1000:.2f} V  /  {sys_current_in} mA")
    if adapter_loss is not None:
        print(f"  Adapter Loss:  {adapter_loss/1000:.2f} W")
        if sys_power_in and adapter_loss and sys_power_in > 0:
            efficiency = (1 - adapter_loss / (sys_power_in + adapter_loss)) * 100
            print(f"  Efficiency:    {efficiency:.1f}%")

    # ── Power Flow Diagram ──
    if ext_connected and sys_power_in:
        print(f"\n{'── Power Flow ─' * 1}{'─' * 41}")
        wall_w = wall_energy / 1000 if wall_energy else 0
        sys_w = sys_power_in / 1000 if sys_power_in else 0
        load_w = sys_load / 1000 if sys_load else 0
        bat_w = bat_power / 1000 if bat_power else 0
        loss_w = adapter_loss / 1000 if adapter_loss else 0

        print(f"  Wall [{wall_w:.1f}W] --> Adapter [{adapter_watts}W rated]")
        print(f"    ├── System Load:  {load_w:.1f} W")
        print(f"    ├── Battery:      {bat_w:.1f} W {'(charging)' if is_charging else '(maintaining)'}")
        print(f"    └── Losses:       {loss_w:.1f} W")

    print(f"\n{'━' * 56}")
    print(f"  {time.strftime('%H:%M:%S')}  |  Refresh: 2s  |  Ctrl+C to exit")

if __name__ == "__main__":
    try:
        while True:
            main()
            time.sleep(2)
    except KeyboardInterrupt:
        print("\n")
