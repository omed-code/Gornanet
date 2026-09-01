# Spider Movie

A polished Flutter application for browsing daily trending movies, searching TMDB, and keeping an offline watchlist. The app targets Flutter 3.32+ and Dart 3.8+ with sound null safety.

## Features

- Three primary destinations: Trending, Search, and Watchlist
- Infinite scrolling with duplicate prevention and pull-to-refresh
- Debounced title search with adult results disabled
- Movie details with runtime, genres, release year, rating, and overview
- Offline watchlist persistence, including the movie summary needed for offline display
- System, light, and dark themes with a persisted preference
- Loading, empty, missing-image, invalid-token, offline, server, and pagination-error states
- Safe-area and bottom-inset handling for notches, cutouts, and gesture navigation
- Accessible labels, tooltips, and responsive Material 3 presentation

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.32 or newer
- Dart 3.8 or newer (included with Flutter)
- A TMDB **API Read Access Token** from the [TMDB developer portal](https://developer.themoviedb.org/)
- Android Studio/Xcode and a configured emulator or physical device

Verify the installed SDK:

```sh
flutter --version
```

## Run the app

Clone the repository and install dependencies:

```sh
git clone https://github.com/omed-code/Gornanet.git
cd Gornanet
flutter pub get
```

Start normally, then select **Add credential** on the setup screen (or the key icon in the app bar) and paste your TMDB API Key or API Read Access Token:

```sh
flutter run
```

The credential is encrypted by the platform secure-storage service (iOS Keychain or Android Keystore-backed storage) and reused on future launches.

For CI or command-line configuration, pass the long TMDB **API Read Access Token** at build time. Copy the token value itself; a pasted `Bearer ` prefix is accepted but is not required. Do not add credentials to source files:

```sh
flutter run --dart-define=TMDB_ACCESS_TOKEN=YOUR_TMDB_API_READ_ACCESS_TOKEN
```

Alternatively, use the shorter 32-character v3 API key:

```sh
flutter run --dart-define=TMDB_API_KEY=YOUR_TMDB_V3_API_KEY
```

Choose a device explicitly when needed:

```sh
flutter devices
flutter run -d DEVICE_ID --dart-define=TMDB_ACCESS_TOKEN=YOUR_TOKEN
```

If the credential is missing or rejected, the app opens an in-app correction path instead of repeatedly retrying a request that cannot succeed. A full restart is required only after changing `--dart-define`; credentials entered inside the app take effect immediately. `--dart-define` keeps the credential out of Git; as with any client application, values compiled into a distributed binary should not be treated as a server-side secret.

## Architecture and state management

The project uses a small layered architecture:

```text
UI screens/widgets
        ↓
Riverpod notifiers/providers
        ↓
Movie, watchlist, and theme repositories
        ↓
TMDB HTTP client / shared_preferences
```

Riverpod was chosen because it makes asynchronous loading/error state explicit, keeps business state outside widgets, and lets tests replace repositories without code generation. The main providers own:

- trending pagination and refresh
- debounced search results and search pagination
- locally persisted watchlist state
- locally persisted theme mode
- auto-disposed movie-detail requests

The UI owns only presentation-specific resources such as `TextEditingController`, debounce `Timer`, and `ScrollController`; each is initialized and disposed with its screen lifecycle.

## Offline behavior

The watchlist is encoded as JSON and stored with `shared_preferences`. Each saved entry includes its TMDB ID, title, overview, image paths, release date, rating, runtime, and genres. Saved titles therefore remain browsable offline, while network-only detail enrichment shows a non-blocking offline banner. Trending and search results are intentionally not cached.

Theme mode is stored separately and restored at startup. Use the brightness icon in the app bar to choose System, Light, or Dark.

## Quality checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define=TMDB_ACCESS_TOKEN=test-token
```

The test suite covers defensive model parsing, typed API failures, pagination merging, preference persistence, loading/error/empty behavior, debounced search, watchlist updates, offline rendering, theme switching, safe areas, infinite scrolling, and controller disposal.

## Project layout

```text
lib/
  main.dart
  src/
    core/          # TMDB client and typed errors
    models/        # Immutable movie and page models
    repositories/  # Network and local persistence contracts
    state/         # Riverpod providers and notifiers
    theme/         # Material 3 light/dark themes
    ui/            # Tabs, detail route, and reusable widgets
test/              # Unit and widget tests
```

## API and attribution

The application uses TMDB's daily trending and popular movie/TV lists, movie/TV/multi-search, TV discovery, and movie/TV detail endpoints with English (`en-US`) responses. Anime browsing and search use TMDB's Animation genre classification. This product uses the TMDB API but is not endorsed or certified by TMDB.
