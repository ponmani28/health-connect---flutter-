# Health Connect Dashboard

A standalone Flutter demo app that reads health data from **Health Connect** via the [`health`](https://pub.dev/packages/health) package and shows it on a dashboard.

## Setup

1. **Prerequisites**
   - Flutter stable, Android SDK 34+
   - Android phone with the Health Connect app installed (the app offers an install button if it's missing)

2. **Run**
   ```bash
   flutter pub get
   flutter run
   ```

3. **Grant access**
   - Tap **Grant read access** to open the Health Connect permission screen
   - Allow the requested read permissions; data loads automatically afterwards

## Dashboard metrics

| Metric | Source type | Value |
|--------|-------------|-------|
| Steps | `STEPS` (daily native aggregate) | count |
| Active Energy | `ACTIVE_ENERGY_BURNED` | kcal |
| Distance | `DISTANCE_DELTA` | km / m |
| Floors | `FLIGHTS_CLIMBED` | count |
| Heart Rate | `HEART_RATE` | bpm |
| Resting HR | `RESTING_HEART_RATE` | bpm |
| Blood Oxygen | `BLOOD_OXYGEN` | % |
| HRV | `HEART_RATE_VARIABILITY_RMSSD` | ms |
| Weight | `WEIGHT` | kg |
| Height | `HEIGHT` | cm |

Activity types are summed over today; vitals show the latest sample within their lookback window. Pull-to-refresh or use the refresh button to re-read.

## Permissions

- `Read`/`Write` for steps and heart rate, `Read` for the other metrics — declared in `android/app/src/main/AndroidManifest.xml` (`android.permission.health.*`).
- The manifest includes the Health Connect **rationale activity**, a **View Permission Usage** alias (required for the privacy-policy link shown in Health Connect), and the `com.google.android.apps.healthdata` `<queries>` entry.
- Replace the placeholder `health_connect_privacy_policy_url` in `android/app/src/main/res/values/strings.xml` with your real privacy policy URL before publishing.

## Layout

```
lib/
├── main.dart                     Entry point (registers the controller, launches the app)
├── app.dart                      GetMaterialApp root
├── controllers/
│   └── health_controller.dart    GetX controller: availability, permissions, metric reads
├── pages/
│   └── dashboard_page.dart       Reactive UI (Obx) over the controller
└── models/
    └── metric.dart               Dashboard metric with reactive (Rx) value fields
android/
├── manifest           Permissions, rationale activity, queries
├── HealthConnectBridge.kt (legacy native bridge, kept for reference)
└── PermissionsRationaleActivity.kt
```

State management is GetX: `HealthController` (a `GetxController`) owns all health logic and reactive state (`RxBool`, `RxString`, `Rxn`, and per-metric `Rx<double?>`); widgets are stateless and rebuild through `Obx`.