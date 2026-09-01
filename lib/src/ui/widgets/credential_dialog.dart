import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_providers.dart';

String? validateTmdbCredential(String rawValue) {
  final value = rawValue.trim().replaceFirst(
    RegExp(r'^Bearer\s+', caseSensitive: false),
    '',
  );
  if (value.isEmpty) return 'Paste a credential first.';
  final lowercase = value.toLowerCase();
  if (lowercase.contains('your_') ||
      lowercase.contains('your-') ||
      lowercase == 'test-token' ||
      lowercase == 'token') {
    return 'That is a placeholder, not a real TMDB credential.';
  }
  final isApiKey = RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value);
  final looksLikeReadToken = value.startsWith('eyJ') && value.length >= 80;
  if (!isApiKey && !looksLikeReadToken) {
    return 'Use the 32-character API Key or the long API Read Access Token from TMDB.';
  }
  return null;
}

Future<void> showTmdbCredentialDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => const _CredentialDialog(),
  );
  if (saved == true) {
    ref.invalidate(trendingProvider);
    ref.invalidate(searchProvider);
    ref.invalidate(movieDetailsProvider);
  }
}

class _CredentialDialog extends ConsumerStatefulWidget {
  const _CredentialDialog();

  @override
  ConsumerState<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends ConsumerState<_CredentialDialog> {
  late final TextEditingController _controller;
  bool _obscureText = true;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = validateTmdbCredential(_controller.text);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await ref.read(tmdbCredentialProvider.notifier).save(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = 'Could not save securely. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect to TMDB'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Paste either your 32-character API Key or the long API Read Access Token. It is encrypted in this device’s secure storage.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('tmdb-credential-field'),
              controller: _controller,
              autofocus: true,
              obscureText: _obscureText,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) {
                if (!_saving) _save();
              },
              decoration: InputDecoration(
                labelText: 'TMDB credential',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  tooltip: _obscureText ? 'Show credential' : 'Hide credential',
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-tmdb-credential'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save credential'),
        ),
      ],
    );
  }
}
