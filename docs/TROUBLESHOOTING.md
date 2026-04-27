# Troubleshooting

A living catalog of failures we've actually hit on this stack, with concrete fixes. Each entry has the same shape: **symptom → cause → fix → verification**.

---

## Google Home shows the light as "offline" or "unavailable"

This is the umbrella symptom. There are several distinct root causes. Work down this list in order — each is more invasive than the last.

### A. The BLE entity boots into `unknown`

**Symptom.** Right after a Home Assistant restart, `light.govee_light` is in state `unknown` until the device sends the next BLE advertisement. The template proxy uses an availability template that treats `unknown` as offline, so Google Home reports the light unavailable.

**Cause.** Default Home Assistant entity behavior — entities that haven't received any state since the restart sit at `unknown`.

**Fix.** Already shipped in this repo. The patched `custom_components/govee_ble_lights/light.py` extends `RestoreEntity` and calls `async_get_last_state()` at setup, so the entity boots back into its previous on/off + brightness + color state.

**Verify.** Restart HA. The proxy entity should never visibly transition through `unknown` — it should hold its previous state until BLE updates it.

---

### B. The bluetooth integration is bound to a placeholder MAC `AA:AA:AA:AA:AA:AA`

**Symptom.** `light.govee_light` is permanently `unavailable` (not `unknown`). HA log has zero `bluetooth`, `bleak`, or `hci` entries — silent failure. `bluetoothctl` on the host sees the Govee fine. Inside the HA container, `BleakScanner.discover()` also sees it. But HA itself never receives advertisements.

**Cause.** When Home Assistant boots faster than `bluez`, the bluetooth integration queries the adapter before bluez has finished initialization. `bluez` returns the placeholder MAC `AA:AA:AA:AA:AA:AA` instead of the real adapter MAC. Home Assistant caches this placeholder in `core.config_entries` as the integration's `unique_id`, then forever after sees "bluetooth already configured" and skips real-adapter discovery.

You can spot this in `<config>/.storage/core.config_entries`:

```json
{
  "domain": "bluetooth",
  "unique_id": "AA:AA:AA:AA:AA:AA",
  "title": "brcm bcm43438-bt (AA:AA:AA:AA:AA:AA)",
  "data": {}
}
```

**Fix — automated.** Use the helper script:

```bash
sudo bash scripts/repair_bluetooth_mac.sh \
  --config-dir /path/to/homeassistant/config \
  --service container-homeassistant.service \
  --new-mac DC:A6:32:EA:E4:13
```

The script stops HA, backs up `core.config_entries`, replaces the placeholder entry with a real-MAC entry, restarts HA. Backups are timestamped so a rollback is one `cp` away.

**Fix — manual.** If you'd rather do it by hand, the equivalent steps are:

1. `sudo systemctl stop <ha-service>` (or `docker compose stop`, etc.)
2. `cp <config>/.storage/core.config_entries <config>/.storage/core.config_entries.bak-$(date -u +%Y%m%dT%H%M%SZ)`
3. Edit `core.config_entries`. Either delete the placeholder bluetooth entry **or** replace its `unique_id` and `title` with the real MAC. Real MAC comes from `hciconfig -a` or `bluetoothctl show`.
4. `sudo systemctl start <ha-service>`

**Verify.**

```bash
# 1. Config entry now has the real MAC
grep -A2 '"domain": "bluetooth"' <config>/.storage/core.config_entries

# 2. BLE entity moves off unavailable
sudo podman exec homeassistant python3 -c "
import sqlite3
c = sqlite3.connect('/config/home-assistant_v2.db')
for row in c.execute(\"SELECT sm.entity_id, state, datetime(last_updated_ts, 'unixepoch') FROM states s JOIN states_meta sm ON s.metadata_id = sm.metadata_id WHERE sm.entity_id LIKE 'light.govee%' ORDER BY last_updated_ts DESC LIMIT 4\"):
    print(row)
"
```

You should see a fresh `('light.govee_light', 'off', ...)` row within ~60 seconds of restart.

---

### C. Google's report_state cache is stale

**Symptom.** Both `light.govee_light` and the template proxy show correct on/off in HA, but Google Home still says offline for a few minutes.

**Cause.** Google Home maintains a cloud-side device-state cache. After the proxy entity flips back from `unavailable` to a real state, it can take 1–5 minutes for Google to re-poll.

**Fix.** Force a sync:

- Voice: "Hey Google, sync my devices"
- HA service: `google_assistant.request_sync`
- Or toggle the proxy entity from HA (forces a state change push)

**Verify.** Open Google Home — the device card should show on/off and respond to control.

---

## BLE entity stays unavailable even after a restart that should have helped

**Symptom.** You did the right thing (e.g. fix B above) but `light.govee_light` is still `unavailable` 5+ minutes after restart.

**Likely causes.**

1. **Govee out of BLE range.** The H617C has a small antenna — walls and metal cabinets are brutal. Move the device or the host adapter.
2. **BLE adapter saturated.** Onboard Pi adapters typically support 1–2 simultaneous BLE connections. If you have several integrations holding connections, the Govee may be queued. Check `bluetoothctl devices Connected` on the host.
3. **Govee firmware-paired to phone app.** If the Govee Home app has an active session, the device may refuse HA's connection. Force-quit the Govee Home app.
4. **Passive scanner not enabled.** In HA, **Settings → Devices & Services → Bluetooth → Configure** — turn on "passive scanning" if it's off.

---

## "State attributes for light.govee_light exceed maximum size of 16384 bytes"

**Symptom.** Recurring warning in the HA log every time the entity sets state.

**Cause.** The govee_ble_lights integration ships its full effects catalog as a state attribute. The catalog is enormous (>16 KB). HA's recorder refuses to write attributes that big.

**Impact.** Cosmetic. The entity still works fine — you just can't query historical effect data via the recorder.

**Fix.** None required. If the warning bothers you, exclude the attribute via `recorder:` config:

```yaml
recorder:
  exclude:
    entity_globs:
      - light.govee_light*
```

(But this also drops on/off history for those entities — usually not worth it.)

---

## "Detected blocking call to scandir" warning at integration setup

**Symptom.** A long traceback mentioning `govee_ble_lights/config_flow.py` line 37 in HA logs.

**Cause.** Upstream `govee_ble_lights` integration uses synchronous file IO during config flow setup. HA's stricter event-loop checks flag this.

**Impact.** Cosmetic — the integration loads fine.

**Fix.** None on our side. Ignored unless upstream patches it.

---

## Need to roll back the placeholder MAC fix

The repair script writes a backup before any change. To roll back:

```bash
ls -la <config>/.storage/core.config_entries.bak-*

# pick the timestamp you want, then:
sudo systemctl stop <ha-service>
sudo cp <config>/.storage/core.config_entries.bak-<TIMESTAMP> <config>/.storage/core.config_entries
sudo systemctl start <ha-service>
```

---

## Still stuck?

Open an issue with:

- HA version (`<config>/.HA_VERSION`)
- output of `bluetoothctl show` on the host
- the relevant `bluetooth` block from `core.config_entries`
- the most recent 50 lines of `home-assistant.log` filtered with `grep -iE "bluetooth|bleak|govee|hci"`
