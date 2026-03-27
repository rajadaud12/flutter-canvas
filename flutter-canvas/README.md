# flutter_canvas

Flutter Web app embedded in the MYTH design builder (`DesignCanvas` iframe at `/flutter-canvas/`).

## Build output (required for Next.js)

Static files must exist under **`frontend/public/flutter-canvas/`** (served by the app). You do **not** need Flutter installed locally if you use GitHub Actions + the backend sync below.

### Env (backend `config/.env`)

- **`GITHUB_ACCESS_TOKEN`** – PAT with `repo` scope (already used for user app builds).
- **`GITHUB_FLUTTER_CANVAS_REPO`** – GitHub repo name **without** owner (default: `flutter-canvas`). The repo must belong to the same account as **`GITHUB_USER_NAME`** (used with `GITHUB_ACCESS_TOKEN`).
- Optional: **`FLUTTER_CANVAS_PULL_ON_BOOT=true`** – after server start, download `public/flutter-canvas` from the GitHub repo into MYTH (waits ~12s; requires a successful prior CI run).
- Optional: **`FLUTTER_CANVAS_PULL_DELAY_MS`** – delay before boot pull (default `12000`).

### One-time / updates (admin JWT)

All routes: **`POST /api/v1/flutter/canvas/...`** (base URL = your backend). Use an **admin** Bearer token.

| Endpoint | Purpose |
|----------|--------|
| **`/canvas/setup`** | Push MYTH `frontend/flutter-canvas` sources to `flutter-canvas/` on GitHub, push `.github/workflows/flutter-canvas.yml`, dispatch Actions. |
| **`/canvas/push-sources`** | Sources only. |
| **`/canvas/push-workflow`** | Workflow YAML only. |
| **`/canvas/dispatch-workflow`** | Re-run Actions without pushing sources. |
| **`/canvas/pull-public`** | Download **`public/flutter-canvas`** from the repo into **`frontend/public/flutter-canvas`** (run after CI finishes). |

Example body (optional): `{ "repo": "flutter-canvas" }` if different from `GITHUB_FLUTTER_CANVAS_REPO`.

**Typical flow:** `setup` → wait for GitHub Actions on the canvas repo → `pull-public` → restart or redeploy frontend so `/flutter-canvas/` loads the new bundle.

### Workflow template

The YAML committed to GitHub is **`backend/utils/flutterCanvasTemplateWorkflow.yml`** (expects `flutter-canvas/` at repo root and writes `public/flutter-canvas/` in that repo).

### Local build (optional)

```bash
cd frontend/flutter-canvas
flutter pub get
flutter build web --release --base-href /flutter-canvas/
# Then copy build/web/* → ../public/flutter-canvas/
```

## Getting Started

This project is a starting point for a Flutter application.

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
