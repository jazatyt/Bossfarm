# 🌱 BOSS FARM — Smart Farm Dashboard

A Flutter Web dashboard for monitoring smart-farm sensors (environment, soil, and NPK/mineral nodes) in real time, with alarms, history, farm-layout building, and user management. Backed by a PHP (`farmapi`) service and per-device REST/InfluxDB sensor feeds.

## Tech Stack

![Flutter](https://img.shields.io/badge/Flutter-3.41.6-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)
![Material 3](https://img.shields.io/badge/Material%203-757575?logo=materialdesign&logoColor=white)
![go_router](https://img.shields.io/badge/go__router-14.8-0468D7)
![Hive](https://img.shields.io/badge/Hive-2.2-FFC107?logo=databricks&logoColor=black)
![fl_chart](https://img.shields.io/badge/fl__chart-0.68-4CAF50)
![http](https://img.shields.io/badge/http-REST-009688)
![PHP backend](https://img.shields.io/badge/backend-PHP%20farmapi-777BB4?logo=php&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Web%20%7C%20Android%20%7C%20iOS%20%7C%20Desktop-lightgrey)

| Concern | Package / Tool |
|---|---|
| UI framework | Flutter (Material 3, `google_fonts` — Inter) |
| **Routing** | `go_router` (URL-synced routes, hash strategy) |
| Local storage | `hive` / `hive_flutter` (auth + sensor state) |
| Networking | `http` (REST to `farmapi` + per-device sensor APIs) |
| Charts | `fl_chart` (line charts, NPK pie) |
| Icons | `phosphor_flutter`, Material Icons |
| Export / import | `file_picker`, `excel`, `path_provider` |
| Misc | `intl`, `crop_your_image`, `universal_html` |

## Routing

Navigation uses **`go_router`** with **hash-based URLs** (e.g. `/#/settings`). Each top-level page has its own URL, so **refreshing the browser keeps you on the current page** instead of resetting to the dashboard. A single `redirect` guard in [`lib/main.dart`](lib/main.dart) enforces auth: if you're not logged in, any route except `/login` and `/register` bounces to `/login`.

| Route | Page | Notes |
|---|---|---|
| `/` | `DashboardPage` | Home — sensor overview |
| `/login` | `LoginPage` | Public |
| `/register` | `RegisterPage` | Public |
| `/alarms` | `AlarmsPage` | Optional `initialIndex` via `extra` |
| `/history` | `HistoryViewPage` | Historical charts |
| `/layout` | `FarmLayoutBuilderPage` | Drag-and-drop farm layout |
| `/settings` | `UserManagementPage` | Admin only |
| `/farms` | `AllFarmsPage` | Optional `filterType` via `extra` |

## Dashboard Structure

The dashboard ([`lib/dashboard_page.dart`](lib/dashboard_page.dart)) is a scrollable feed built from these blocks, top to bottom:

- **Top bar** ([`widgets/top_bar.dart`](lib/widgets/top_bar.dart)) — brand logo (tap → home), theme toggle, alarms bell (with active-alarm badge), history, farm-layout, and admin management buttons, user badge, and logout.
- **Dashboard Overview** — sensor summary with the alarm banner ([`widgets/alarm_banner_widget.dart`](lib/widgets/alarm_banner_widget.dart)) and metric cards.
- **Environment Nodes** — a row of farm cards (`filterType: environment`); "View All" → `/farms`.
- **Soil Sensors** — soil metric cards and charts (`filterType: soil`).
- **Mineral Sensor** — NPK pie chart card (`filterType: mineral`).
- **Time-range selector** — refetches history for the selected window.

Data flows through `SensorDataManager` and per-device `SensorApiService`; the top bar polls `AlarmService` every 30s.

## Project Structure

```
lib/
├── main.dart                 # App entry, GoRouter config + auth guard
├── dashboard_page.dart       # Home dashboard
├── login_page.dart / register_page.dart
├── alarms_page.dart          # /alarms
├── history_view_page.dart    # /history
├── farm_layout_builder_page.dart  # /layout
├── user_management_page.dart  # /settings (admin)
├── all_farms_page.dart / all_devices_page.dart  # /farms, device lists
├── sensor_page.dart / sensor_detail_page.dart
├── models/                   # Hive models (sensors, slots, zones)
├── services/                 # auth, sensor/layout APIs, influx, export, hive
└── widgets/                  # top_bar, cards, charts, maps, alarm banner
```

## Getting Started

### Prerequisites
- **Flutter 3.41.6** (stable) — this project is pinned to that revision in [`.metadata`](.metadata). Newer Flutter breaks `phosphor_flutter 2.1.0` (`IconData` became a final class), so use this version.
- A running **`farmapi` PHP backend** at `http://localhost/farmapi` (login, users, layout). Without it, login and data fetches fail — see [`lib/services/auth_service.dart`](lib/services/auth_service.dart).

### Run (Web)
```bash
flutter pub get
flutter run -d chrome
```
The app serves at `http://localhost:<port>/#/`. Because routing uses the hash strategy, refresh works on any static host with **no server rewrite config**.

### Build for release
```bash
flutter build web        # output in build/web/
```

### Notes
- Routing was migrated from imperative `Navigator.push` to `go_router`; navigate with `context.go('/path')` (replace) or `context.push('/path', extra: …)` (stack). Back buttons use `context.canPop() ? context.pop() : context.go('/')`.
- Sensor data cards render empty until the backend and device APIs are reachable — this is expected offline and unrelated to routing.
