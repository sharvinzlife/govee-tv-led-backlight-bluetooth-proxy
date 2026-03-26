# Migration Guide

This guide documents the cleanest way to move the working Govee TV backlight setup from one Home Assistant host to another.

## Goal

Move these behaviors together:

1. The custom BLE integration for the Govee backlight
2. The restore-state patch that prevents `unknown` on restart
3. The Google-visible template proxy entity
4. The `google_assistant` configuration that reports state back to Google Home

## What You Need

- A working Home Assistant installation on the target host
- Bluetooth support on that host
- The ability to copy files into the Home Assistant config directory
- Your own `SERVICE_ACCOUNT.json`
- Access to your Google Home / Home Assistant project

## Files To Bring Over

- `custom_components/govee_ble_lights/`
- `ha-snippets/google_tv_led_back_light.yaml`
- `notes/device-info.yaml`

Do not copy:

- `SERVICE_ACCOUNT.json` from another machine unless you explicitly want to reuse the same Google project
- Unrelated Home Assistant secrets or `.storage` blobs

## Migration Steps

### 1. Copy the custom component

Copy the entire `custom_components/govee_ble_lights/` folder into:

```text
<home-assistant-config>/custom_components/govee_ble_lights/
```

This includes the patched `light.py` that restores the last state during startup.

### 2. Merge the YAML snippet

Merge the contents of `ha-snippets/google_tv_led_back_light.yaml` into the target `configuration.yaml`.

Update these values first:

- `external_url`
- `internal_url`
- `project_id`
- display name and room if you want different naming

### 3. Add the Google service account file

Place your `SERVICE_ACCOUNT.json` in the target Home Assistant config directory.

Expected path:

```text
<home-assistant-config>/SERVICE_ACCOUNT.json
```

### 4. Restart Home Assistant

Restart the instance so Home Assistant loads:

- the custom component
- the template light
- the Google Assistant configuration

### 5. Re-add the Govee BLE integration

In Home Assistant:

1. Open `Settings -> Devices & Services`
2. Add the `govee_ble_lights` integration
3. Select the correct model
4. Confirm the device appears as `light.govee_light`

For this live setup, the known model is:

```text
H617C
```

### 6. Verify the proxy entity

After restart and integration setup, confirm both entities exist:

- `light.govee_light`
- `light.tv_led_back_light_google`

The proxy is the one intended for Google Home exposure.

### 7. Sync Google Home

Use one of these:

- Say: `Hey Google, sync my devices`
- Call the Home Assistant `google_assistant.request_sync` service
- Re-link the Home Assistant project inside Google Home if needed

## Validation Checklist

- The backlight can be turned on and off from Home Assistant
- The proxy light appears in Google Home
- The device does not come back as offline after Home Assistant restart
- Brightness and color changes pass through the proxy entity

## Known Working Entity Mapping

| Purpose | Entity |
| --- | --- |
| Raw BLE light | `light.govee_light` |
| Google-facing proxy | `light.tv_led_back_light_google` |

## Notes For Unraid

If you move Home Assistant to Unraid:

- Make sure the Home Assistant container or VM has working Bluetooth access
- If using a USB Bluetooth adapter, pass it through to the VM or container
- Keep the Home Assistant config directory persistent so the restore-state behavior remains useful across restarts

## Troubleshooting

### Google Home still shows the light as offline

Check:

- `report_state: true` is set
- the proxy entity exists
- the raw BLE entity is no longer stuck at `unknown`

### The raw light entity is missing

Check:

- the `govee_ble_lights` integration was added again
- Bluetooth is accessible on the target host
- the correct model was selected

### Sync fails but device control still works

That is often a Google test-mode issue, not a Home Assistant issue. See [GOOGLE_HOME_TEST_MODE.md](GOOGLE_HOME_TEST_MODE.md).
