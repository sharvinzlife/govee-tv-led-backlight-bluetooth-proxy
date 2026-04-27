# Scripts

Two helper scripts ship with this repo. Both are dependency-light and self-documenting.

| Script | Purpose | Runtime |
| --- | --- | --- |
| [`generate_yaml.py`](generate_yaml.py) | Turn a devices registry into a Home Assistant config block | Python 3.8+ with PyYAML |
| [`repair_bluetooth_mac.sh`](repair_bluetooth_mac.sh) | Fix the `AA:AA:AA:AA:AA:AA` placeholder-MAC bug | bash + systemd + Python 3 |

---

## `generate_yaml.py`

Hand-editing the template-proxy YAML for many devices is error-prone. This script reads a simple registry file (`devices.yaml`) and emits the full configuration block.

### Setup

```bash
pip install pyyaml
# or: sudo apt install python3-yaml
```

### Usage

```bash
# Print the generated block to stdout
python3 scripts/generate_yaml.py ha-snippets/devices.example.yaml

# Or write directly to a file
python3 scripts/generate_yaml.py ha-snippets/devices.example.yaml -o my-block.yaml
```

### Input shape

See [`ha-snippets/devices.example.yaml`](../ha-snippets/devices.example.yaml). One entry per BLE device:

```yaml
devices:
  - name: "TV LED Back Light"
    ble_source: light.govee_light
    proxy_id: tv_led_back_light_google
    room: Living Room
```

The script validates uniqueness (no two devices can share a `proxy_id` or `ble_source`) and fails loud on missing fields.

### Workflow

1. Add a new entry to your `devices.yaml`
2. Re-run the generator
3. Replace the relevant block in `configuration.yaml`
4. Reload template entities + sync Google Home

You never edit the wrapper YAML by hand again.

---

## `repair_bluetooth_mac.sh`

Repairs the placeholder-MAC failure described in [`docs/TROUBLESHOOTING.md` §B](../docs/TROUBLESHOOTING.md). Stops Home Assistant, backs up `core.config_entries` with a UTC timestamp, replaces the bad bluetooth entry with one bound to the real adapter MAC, restarts Home Assistant.

### Find the real MAC

```bash
hciconfig -a | grep "BD Address"
# or
bluetoothctl show | grep Address
```

### Run it (dry-run first)

```bash
sudo bash scripts/repair_bluetooth_mac.sh \
    --config-dir /mnt/dietpi_userdata/homeassistant/config \
    --service container-homeassistant.service \
    --new-mac DC:A6:32:EA:E4:13 \
    --dry-run
```

The dry-run prints the current vs. desired entry without modifying anything. Once it looks right, drop `--dry-run`.

### Rollback

Every run leaves a `core.config_entries.bak-<UTC>` next to the original. To undo:

```bash
sudo systemctl stop <ha-service>
sudo cp -a /path/to/core.config_entries.bak-<TIMESTAMP> /path/to/core.config_entries
sudo systemctl start <ha-service>
```

### Service-name examples

| HA install style | `--service` value |
| --- | --- |
| Rootful podman + systemd unit (DietPi default) | `container-homeassistant.service` |
| Docker compose | n/a — use `docker compose stop/start` instead |
| HA Core (venv) | `home-assistant@homeassistant.service` (or whatever your unit is) |
| HAOS / Supervised | n/a — use the Supervisor UI; this script is for non-managed installs |
