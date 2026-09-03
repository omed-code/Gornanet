# Spider Movie

Spider Movie is a Flutter application built for the Sevennet mobile-development challenge. It uses the TMDB API to present trending movies, browse movies, series, and anime, search for titles, open detailed title information, and maintain an offline watchlist.

The application has three primary destinations:

- **Trending** — daily movies, popular series, anime, and genre-based recommendations
- **Search** — debounced search, category browsing, filters, pagination, and random suggestions
- **Watchlist** — locally saved titles that remain available without a network connection

Movie cards open a detail route with artwork, rating, release year, runtime, genres, overview, and a watchlist action. Each Trending section also provides a **See all** route for its currently loaded titles.

## Technology

- Flutter 3.41.7
- Dart 3.11.5 with sound null safety
- Material 3
- Riverpod for application state
- `http` for TMDB requests
- `shared_preferences` for watchlist and theme persistence
- `flutter_secure_storage` for credentials entered inside the app
- `material_symbols_icons` for interface icons

The project satisfies the requested Flutter 3.32+ and Dart 3.8+ language requirements by using newer stable SDK versions. The current `pubspec.yaml` requires Dart 3.11.5 or newer.

## Features

- Daily TMDB trending movies
- Popular movie, series, and anime browsing
- Genre-based movie discovery
- Debounced movie, series, and anime search
- Release year, minimum rating, genre, artwork, and audience filters
- Search pagination with duplicate-result prevention
- `ListView.builder` for every dynamic movie collection
- Pull-to-refresh on network result lists
- Movie and television detail endpoints
- Random title recommendations
- Offline watchlist persistence
- System, Light, and Dark theme modes with persisted selection
- Loading, empty, invalid-credential, offline, server, image, and pagination-error states
- Safe-area handling for notches, cutouts, and gesture navigation
- Accessible semantics, labels, and tooltips

## Project structure

```text
lib/
  main.dart
  src/
    app.dart
    core/
      tmdb_client.dart
    models/
      movie.dart
      movie_page.dart
      search_filters.dart
    repositories/
      movie_repository.dart
      preferences_repositories.dart
    state/
      app_providers.dart
    theme/
      app_theme.dart
    ui/
      home_shell.dart
      trending_screen.dart
      search_screen.dart
      watchlist_screen.dart
      movie_detail_screen.dart
      all_titles_screen.dart
      widgets/
test/
  model_and_state_test.dart
  repository_test.dart
  widget_test.dart
```

## Architecture and state management

The project uses a small layered architecture so that widgets do not communicate with TMDB or local storage directly:

```text
UI screens and reusable widgets
              ↓
Riverpod providers and notifiers
              ↓
Repository interfaces and implementations
              ↓
TMDB HTTP client / SharedPreferences / Secure Storage
```

Riverpod was chosen because it keeps business state outside widgets, represents asynchronous loading and error states explicitly, and makes repositories easy to replace in tests without code generation.

### Providers and notifiers

- `tmdbCredentialProvider` restores the saved TMDB credential before dependent requests proceed. Updating the credential rebuilds the TMDB client.
- `tmdbClientProvider` owns the HTTP client and closes it automatically when Riverpod disposes the provider.
- `movieRepositoryProvider` exposes TMDB operations through the `MovieRepository` interface.
- `homeFeedProvider` loads the Trending screen's movie, series, anime, and initial genre sections concurrently. It also handles refreshes and genre changes.
- `searchProvider` owns the selected category, query, filters, result state, and pagination. Request identifiers prevent an older response from overwriting a newer search.
- `watchlistProvider` loads the local watchlist and applies optimistic add/remove updates. It restores the previous state if persistence fails.
- `themeModeProvider` restores and persists the selected System, Light, or Dark mode.
- `movieDetailsProvider` is an auto-disposed family provider that loads details for the selected movie or series.

### Widget-owned state

Widgets retain only presentation-specific resources:

- `SearchScreen` owns its `TextEditingController`, `ScrollController`, `FocusNode`, debounce timer, and animated-hint timer.
- `MovieDetailScreen` owns the scroll controller used by its collapsing title behavior.
- Trending carousels own their scroll controllers and auto-advance timers.
- The home shell owns the controller for the bottom-navigation transition.
- The credential dialog and release-year picker own their input controllers.

Every controller, listener, focus node, and timer is initialized in the appropriate lifecycle method and disposed when its widget is removed.

## TMDB configuration

Create an API credential from the [TMDB developer portal](https://developer.themoviedb.org/). The application accepts either:

- A 32-character TMDB v3 API key
- A long TMDB API Read Access Token

### Option 1: Enter the credential inside the app

Run the application without a credential:

```sh
flutter run
```

The initial error state displays **Add credential**. Select it and enter the API key or Read Access Token. The value is stored using the platform secure-storage service and restored on future launches.

### Option 2: Supply the credential at build time

Using an API Read Access Token:

```sh
flutter run --dart-define=TMDB_ACCESS_TOKEN=YOUR_TMDB_API_READ_ACCESS_TOKEN
```

Using a v3 API key:

```sh
flutter run --dart-define=TMDB_API_KEY=YOUR_TMDB_V3_API_KEY
```

A pasted `Bearer ` prefix is normalized automatically. Credentials must not be committed to source control. Values supplied with `--dart-define` are compiled into the application and should not be treated as server-side secrets.

## Running the project

Clone the public repository:

```sh
git clone https://github.com/omed-code/Gornanet.git
cd Gornanet
```

Install dependencies:

```sh
flutter pub get
```

Check available targets and run the application:

```sh
flutter devices
flutter run -d DEVICE_ID
```

If no credential has been saved, use the in-app **Add credential** action or include one of the `--dart-define` options described above.

## Offline behavior

The watchlist is encoded as JSON and persisted with `shared_preferences`. Each saved entry contains the information required to reconstruct its local summary:

- TMDB identifier and media type
- Title and overview
- Poster and backdrop paths
- Release date and rating
- Runtime
- Genre names and identifiers
- Audience flag

Saved title information therefore remains available offline. Artwork is loaded from TMDB's image service and may fall back to a local placeholder when the network is unavailable. Opening a saved title still displays its stored summary while detail enrichment shows a non-blocking offline message.

Trending and search responses are not cached. The selected theme mode is persisted separately and is also restored offline.

## Loading and error handling

The TMDB client maps failures into readable application errors for:

- Missing credentials
- Rejected credentials
- Connection failures
- Request timeouts
- Non-successful server responses
- Invalid JSON responses

Trending and Search provide retry or credential-correction actions. Empty search results, empty feeds, empty watchlists, unavailable recommendations, missing images, and pagination failures each have dedicated UI states. A movie already stored in the watchlist remains usable if its online detail request fails.

## Quality checks

Format and analyze the project:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
```

Run the automated tests:

```sh
flutter test
```

Generate line coverage:

```sh
flutter test --coverage
```

Build a debug Android APK without committing a real credential:

```sh
flutter build apk --debug --dart-define=TMDB_ACCESS_TOKEN=test-token
```

The test suite covers defensive JSON parsing, API authentication, endpoint selection, filters, pagination merging, local persistence, offline watchlist rendering, search debouncing, category switching, error and empty states, theme persistence, safe areas, navigation, carousel behavior, and controller disposal.

## TMDB attribution

This product uses the TMDB API but is not endorsed or certified by TMDB.

TMDB data and images are provided by [The Movie Database](https://www.themoviedb.org/).
