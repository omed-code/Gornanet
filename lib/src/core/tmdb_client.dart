import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum AppErrorType { configuration, unauthorized, network, server, invalidData }

class AppException implements Exception {
  const AppException(this.type, this.message);

  final AppErrorType type;
  final String message;

  @override
  String toString() => message;
}

class TmdbClient {
  TmdbClient({
    required String accessToken,
    String apiKey = '',
    http.Client? client,
  }) : _accessToken = apiKey.trim().isEmpty
           ? _normalizeBearerToken(accessToken)
           : '',
       _apiKey = _resolveApiKey(accessToken: accessToken, apiKey: apiKey),
       _client = client ?? http.Client();

  static const _baseUrl = 'api.themoviedb.org';
  final String _accessToken;
  final String _apiKey;
  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const <String, String>{},
  }) async {
    if (_accessToken.isEmpty && _apiKey.isEmpty) {
      throw const AppException(
        AppErrorType.configuration,
        'Add your TMDB API Key or long API Read Access Token to continue.',
      );
    }

    final uri = Uri.https(_baseUrl, '/3$path', <String, String>{
      'language': 'en-US',
      if (_apiKey.isNotEmpty) 'api_key': _apiKey,
      ...query,
    });

    try {
      final response = await _client
          .get(
            uri,
            headers: <String, String>{
              if (_accessToken.isNotEmpty)
                'Authorization': 'Bearer $_accessToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AppException(
          AppErrorType.unauthorized,
          'TMDB rejected this credential. Paste the actual API Key or long API Read Access Token—not its name or a placeholder.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppException(
          AppErrorType.server,
          'TMDB is unavailable right now (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AppException(
          AppErrorType.invalidData,
          'TMDB returned an unexpected response.',
        );
      }
      return decoded;
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(
        AppErrorType.network,
        'The request timed out. Check your connection and try again.',
      );
    } on SocketException {
      throw const AppException(
        AppErrorType.network,
        'You appear to be offline. Check your connection and try again.',
      );
    } on FormatException {
      throw const AppException(
        AppErrorType.invalidData,
        'TMDB returned unreadable data.',
      );
    } on http.ClientException {
      throw const AppException(
        AppErrorType.network,
        'Could not reach TMDB. Check your connection and try again.',
      );
    }
  }

  static String _normalizeBearerToken(String value) {
    final trimmed = value.trim();
    final withoutPrefix = trimmed.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    return _looksLikeV3ApiKey(withoutPrefix) ? '' : withoutPrefix;
  }

  static String _resolveApiKey({
    required String accessToken,
    required String apiKey,
  }) {
    final explicitApiKey = apiKey.trim();
    if (explicitApiKey.isNotEmpty) return explicitApiKey;
    final tokenValue = accessToken.trim().replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    return _looksLikeV3ApiKey(tokenValue) ? tokenValue : '';
  }

  static bool _looksLikeV3ApiKey(String value) =>
      RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value);

  void close() => _client.close();
}
