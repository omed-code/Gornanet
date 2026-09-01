import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie.dart';

abstract class PreferencesStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

class SharedPreferencesStore implements PreferencesStore {
  @override
  Future<String?> getString(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, value);
  }
}

abstract class WatchlistRepository {
  Future<List<Movie>> load();
  Future<void> save(List<Movie> movies);
}

class LocalWatchlistRepository implements WatchlistRepository {
  const LocalWatchlistRepository(this._store);

  static const _key = 'watchlist_v1';
  final PreferencesStore _store;

  @override
  Future<List<Movie>> load() async {
    final value = await _store.getString(_key);
    if (value == null || value.isEmpty) return const <Movie>[];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const <Movie>[];
      return decoded
          .whereType<Map>()
          .map((item) => Movie.fromStoredJson(Map<String, dynamic>.from(item)))
          .where((movie) => movie.id > 0)
          .toList(growable: false);
    } on FormatException {
      return const <Movie>[];
    }
  }

  @override
  Future<void> save(List<Movie> movies) => _store.setString(
    _key,
    jsonEncode(movies.map((movie) => movie.toStoredJson()).toList()),
  );
}

abstract class ThemeRepository {
  Future<ThemeMode> load();
  Future<void> save(ThemeMode mode);
}

class LocalThemeRepository implements ThemeRepository {
  const LocalThemeRepository(this._store);

  static const _key = 'theme_mode';
  final PreferencesStore _store;

  @override
  Future<ThemeMode> load() async {
    final value = await _store.getString(_key);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> save(ThemeMode mode) => _store.setString(_key, mode.name);
}
