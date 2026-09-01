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
  TmdbClient({required String accessToken, http.Client? client})
    : _accessToken = accessToken,
      _client = client ?? http.Client();

  static const _baseUrl = 'api.themoviedb.org';
  final String _accessToken;
  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const <String, String>{},
  }) async {
    if (_accessToken.trim().isEmpty) {
      throw const AppException(
        AppErrorType.configuration,
        'TMDB access token is missing. Start the app with --dart-define=TMDB_ACCESS_TOKEN=your_token.',
      );
    }

    final uri = Uri.https(_baseUrl, '/3$path', <String, String>{
      'language': 'en-US',
      ...query,
    });

    try {
      final response = await _client
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $_accessToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AppException(
          AppErrorType.unauthorized,
          'TMDB rejected the access token. Check your API Read Access Token.',
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

  void close() => _client.close();
}
