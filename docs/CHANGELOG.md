# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

---

## [v1.1.0] — 2026-04-27

### Highlights

This release turns the repo from a single-device handoff into a **versatile, modular, multi-device toolkit**. The core BLE patch is unchanged; everything around it is now built to scale.

### Added

- **Multi-device guide** — [`docs/MULTI_DEVICE.md`](docs/MULTI_DEVICE.md) covering same-premises and different-premises extensibility with a clear three-layer mental model
- **Troubleshooting catalog** — [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) with concrete recipes for every failure mode hit in production, including the elusive `AA:AA:AA:AA:AA:AA` placeholder-MAC bug
- **YAML generator** — [`scripts/generate_yaml.py`](scripts/generate_yaml.py) turns a simple `devices.yaml` registry into a full Home Assistant configuration block, eliminating copy-paste drift
- **Bluetooth repair script** — [`scripts/repair_bluetooth_mac.sh`](scripts/repair_bluetooth_mac.sh) automates the placeholder-MAC fix with timestamped backups and one-liner rollback
- **Devices registry example** — [`ha-snippets/devices.example.yaml`](ha-snippets/devices.example.yaml) shows the canonical input shape for the generator
- **Multi-device YAML output example** — [`ha-snippets/example-multi-device.yaml`](ha-snippets/example-multi-device.yaml) demonstrates a fully wired three-device configuration
- **Scripts README** — [`scripts/README.md`](scripts/README.md) documents both helper scripts with worked examples
- **Multi-device architecture diagram** — new mermaid diagram in `README.md` showing the three-layer flow across multiple devices and premises

### Changed

- **README** rewritten with new mermaid diagram, badges, multi-path quickstart (single device, multi-device, new premises), and a changelog reference
- **Migration guide** unchanged in substance but now cross-links the new multi-device and troubleshooting docs

### Fixed

- Documented the **`AA:AA:AA:AA:AA:AA` placeholder-MAC failure mode** that silently breaks BLE scanning across HA restarts. Repair recipe + automated script now ship in the repo.

### Documentation

- Established conventions for naming entities at scale (BLE source → template proxy → Google name)
- Captured the Google `report_state` cache caveat as a distinct troubleshooting entry
- Documented benign log warnings (oversized attributes, blocking-call warning) so they don't get chased

---

## [v1.0.0] — 2026-03

### Initial release

- Patched `custom_components/govee_ble_lights/light.py` with `RestoreEntity` to prevent the `unknown`-on-boot symptom
- Single-device YAML snippet `ha-snippets/google_tv_led_back_light.yaml`
- Initial migration guide and Google Home test-mode notes
- Device profile for the live H617C setup
