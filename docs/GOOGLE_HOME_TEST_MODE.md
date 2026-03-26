# Google Home Test-Mode Notes

This project uses the manual Home Assistant to Google Assistant setup path, which commonly appears in Google Home as a `[test]` app.

## What That Means

Google test-mode projects are fine for personal setups, but they are not as durable as a fully published production integration.

## Practical Limitations

- Only approved test users can link the app
- Device sync can stop working after some time
- The most common failure mode is:
  `Unable to sync Home Assistant`

In practice, control may continue working while sync starts failing.

## Known Recovery

If sync starts failing:

1. Open the Google Home / Google Developer project for this integration
2. Go to `TEST`
3. Open `Simulator`
4. Regenerate the draft test app
5. Ask Google to sync devices again

## Household Sharing

If you want more users in the same home to link the test app:

1. Add them to the Google project
2. Give them access to the project
3. Have them add the `[test]` integration from their account

## Recommendation

For personal use, test mode is usually good enough.

If you want a more durable setup later:

- keep this repo as the portable source of truth
- preserve your Google project details
- consider a cleaner production-style project flow if you outgrow the current test setup
