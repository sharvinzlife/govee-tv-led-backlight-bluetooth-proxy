# Device Profile

This file captures the known-good live device metadata from the working setup.

## Primary Device

- Friendly name: `TV LED Back Light`
- Home Assistant source entity: `light.govee_light`
- Google-facing proxy entity: `light.tv_led_back_light_google`
- Govee model: `H617C`
- BLE unique ID: `CC3333356529`
- Likely BLE MAC: `CC:33:33:35:65:29`
- Room: `Living Room`
- Current Google project ID: `dietpi-home-assistant`

## Why This Matters

These values speed up migration by preserving:

- the expected model
- the expected entity names
- the Google-facing proxy shape
- the current naming used inside Google Home

## Source Of Truth

Machine-readable copy:

- `notes/device-info.yaml`
