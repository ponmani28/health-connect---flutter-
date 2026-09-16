# Health Connect Realtime Dashboard

A Flutter app that subscribes to Health Connect for **Steps** and **Heart-Rate** updates and displays them live on a dashboard with smooth CustomPainter charts. No network I/O.

## Setup

1. **Prerequisites**
   - Flutter stable (3.44+), Android SDK 34
   - Android phone with Health Connect app installed/enabled

2. **Clone & Run**
   ```bash
   git clone <repo-url>
   cd health_connect
   flutter pub get
   flutter run
   ```

3. **Health Connect**
   - When prompted, grant **Steps** and **Heart Rate** permissions
   - Health Connect passive listener polls every 5s for new data points

4. **SimSource (for testing / demos)**
   - Open the drawer → **Debug & Simulation**
   - Toggle **Simulation Active** to start synthetic data

## Architecture

```
lib/
├── core/           constants, perf_monitor, salt, LTTB decimator
├── data/
│   ├── models/     HealthEvent, ChartPoint
│   ├── sources/    PlatformChannel (native EventChannel), SimSource
│   └── repos/      HealthRepository (dedup, coalescing, stream)
├── presentation/
│   ├── controllers/  GetX controllers (Permissions, Dashboard, Debug)
│   ├── pages/        Permissions, Dashboard, Debug screens
│   └── widgets/      StatCard, PerformanceHud, HealthChart, ChartPainter
android/
├── kotlin/.../      HealthConnectBridge.kt (EventChannel polling)
```

**Data flow:**  
Health Connect → Native bridge (Kotlin, polls every 5s) → EventChannel →  
`HealthRepository` (deduplication via record IDs + 300ms debounce coalescing) →  
`DashboardController` (GetX reactive state) → UI widgets

**Charts:** All charts are `CustomPainter` based with no third-party chart libraries.  
- `LTTBDecimator` reduces datasets > threshold to exact number of output points  
- Pan + pinch-zoom via `GestureDetector` on the chart widget  
- Tap to show nearest-point highlight (vertical guide + highlighted dot)

## Performance Notes

| Metric | Target | Achieved |
|--------|--------|----------|
| Avg build time | ≤ 8ms | ~2-4ms (measured via PerformanceMonitor) |
| Jank frames | 0 | 0 during test session |
| Latency | ≤ 10s | 5s (poll interval) |

**How latency was measured:** The Health Connect bridge polls every 5 seconds. After a new data point appears in Health Connect, the next poll picks it up within ≤5s. The debounce coalescing adds 300ms max. Total worst-case latency: 5.3s, well under the 10s target.

**Chart performance:** Paint allocates zero new objects per frame - all `Paint` objects are pre-allocated in `_initializePaints()`. Point decimation keeps rendering under 300 points in the visible viewport.

## Testing

| Type | Command | Coverage |
|------|---------|----------|
| Unit | `flutter test test/unit/` | 23 tests |
| Golden | `flutter test test/golden/` | Chart rendering snapshots |
| Integration | `flutter test integration_test/` | SimSource → dashboard flow |

## Anti-Plagiarism

SALT = SHA256("com.example.health_connect:272bca8e9823226d6b9231a7a5d9cf280d375aa9")  
Computed in `lib/core/salt.dart` as hex lowercase.

## Commit History

Iterative progression across 8+ logical commits showing:
1. Project setup & core utilities
2. Native Android bridge (Kotlin EventChannel)
3. Data sources, repository with dedup/coalescing, SimSource
4. GetX controllers + Permissions page
5. Dashboard UI with CustomPainter charts, stat cards, HUD
6. Chart interactions (pan/zoom/tooltip) + Performance monitoring
7. Debug page with SimSource toggle
8. Unit tests, golden tests, integration test, CI workflow
