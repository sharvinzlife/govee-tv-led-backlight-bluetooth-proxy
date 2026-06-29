# ESP32 Bluetooth Proxy — the real fix for flaky BLE

> **STATUS: DRAFT / PLAN.** This is the recommended hardware mitigation for
> unreliable Govee BLE control. **Before flashing, re-verify current versions
> and behaviour** (ESPHome, ESP-IDF framework, Home Assistant minimums) using
> the "Research checklist" at the bottom — the ESPHome `bluetooth_proxy` API
> and active-connection limits change between releases.

## Why this exists

The Govee H617C is a **Bluetooth-LE-only** light. When Home Assistant drives it
over the host's **onboard** Bluetooth radio (e.g. a Raspberry Pi's `bcm43438`),
you get the classic failure pattern:

- intermittent on/off ("sometimes works, sometimes doesn't")
- colour/scene commands that time out → Google replies *"something went wrong"*
- the entity going briefly unreachable

Root cause is almost never the software — it's the **radio**: one weak antenna,
shared between HA's continuous BLE *scanning* and its *connections*, often metres
away from the strip behind a TV.

An **ESP32 Bluetooth Proxy** fixes this at the physics layer. A cheap ESP32,
flashed with ESPHome's `bluetooth_proxy`, sits **next to the TV** and relays BLE
to Home Assistant over Wi-Fi/LAN. HA's Bluetooth integration auto-discovers it as
a **remote adapter** and routes connections through whichever adapter has the best
path. Result: short RF hop to the strip, connections offloaded off the Pi, far
fewer timeouts.

## How it fits this project

```text
Before:  Google Home ─► HA ─► onboard Pi BT ──(weak, shared)──► Govee strip
After:   Google Home ─► HA ─► ESP32 proxy (Wi-Fi) ─(short hop)─► Govee strip
                          └─► onboard Pi BT  (fallback / scanning)
```

- No changes to the `govee_ble_lights` integration or the template light — HA
  picks the best adapter automatically.
- Keep the onboard radio enabled as a fallback, or disable it once the proxy is
  proven (one adapter avoids them fighting over the single connection slot).
- **Fully reversible:** unplug the ESP32 and HA falls back to the onboard radio.

## Hardware

- Any **ESP32** (dual-core, classic ESP32 / ESP32-S3). **Plain ESP32 with an
  external/PCB antenna is the safe default.**
  - ⚠️ **ESP32-C3/C2/H2 are single-core / limited** — historically weaker for
    multi-connection proxying. Verify current support before buying.
- A reliable 5V USB power supply + short cable.
- Physical placement: **same room as the strip, line-of-sight if possible**,
  not buried in a cabinet. This is where most of the win comes from.

## Setup outline (verify specifics first)

1. **Flash ESPHome.** Easiest path is the web installer at
   <https://web.esphome.io> (Chrome/Edge, plug ESP32 in via USB), or the ESPHome
   Builder/Dashboard add-on in HA. Pick the **"Bluetooth Proxy"** ready-made
   project if offered.
2. **Minimal config** (illustrative — confirm keys against current ESPHome docs):

   ```yaml
   esphome:
     name: bt-proxy-livingroom

   esp32:
     board: esp32dev          # match your actual board
     framework:
       type: esp-idf          # esp-idf recommended for BLE proxy

   wifi:
     ssid: !secret wifi_ssid
     password: !secret wifi_password

   api:                       # native HA API (encryption key auto-added)
   ota:
   logger:

   bluetooth_proxy:
     active: true             # true = allow HA to make connections (needed to
                              # CONTROL the Govee, not just scan)
   esp32_ble_tracker:
     scan_parameters:
       active: true
   ```

   > `active: true` is essential — a passive proxy only forwards advertisements
   > (scanning); controlling the Govee needs **active connections**. Confirm the
   > current max simultaneous connections for your chip/ESPHome version.

3. **Adopt in Home Assistant.** Settings → Devices & Services → ESPHome should
   auto-discover it. Confirm, enter the API key if prompted.
4. **Verify routing.** Settings → Devices & Services → **Bluetooth** should now
   list the proxy as an adapter. Power-cycle the Govee strip near the ESP32 and
   confirm the light's RSSI/connection improves and commands stop timing out.
5. **(Optional) Retire the onboard radio** once stable, so the two adapters don't
   contend for the single connection to the strip.

## Verification (done = these hold)

- [ ] ESPHome device shows **online** in HA.
- [ ] HA **Bluetooth** config page lists the ESP32 as a remote adapter.
- [ ] `light.govee_light` connects via the proxy (better RSSI, faster commands).
- [ ] Google Home colour **and** white presets work without "something went wrong".
- [ ] `govee-watch` (the monitor) stays `online` with no flap-mutes over a few days.

## Research checklist (do this when ready to build — info dates fast)

- [ ] Current **ESPHome** release + whether the **Bluetooth Proxy** project
      template is still the recommended starting point.
- [ ] **Framework**: is `esp-idf` still preferred over Arduino for `bluetooth_proxy`?
- [ ] **Max active connections** for the chosen ESP32 variant in the current release.
- [ ] **Home Assistant minimum version** for remote `bluetooth_proxy` adapters
      (and any "active connections" caveats).
- [ ] Whether to **disable the Pi onboard adapter** or run both (contention notes).
- [ ] Best-value **ESP32 board with a good antenna** currently available.

## Rollback

Unplug the ESP32 (and re-enable the onboard adapter if you disabled it). HA
returns to driving the strip over the host radio — i.e. back to today's setup.
