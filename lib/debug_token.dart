import 'package:flutter/material.dart';
import 'hive_service.dart';
import 'services/contact_service.dart';
import 'services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Debug экран для проверки токена и API
class DebugTokenScreen extends StatefulWidget {
  const DebugTokenScreen({Key? key}) : super(key: key);

  @override
  State<DebugTokenScreen> createState() => _DebugTokenScreenState();
}

class _DebugTokenScreenState extends State<DebugTokenScreen> {
  String _debugInfo = 'Loading...';

  @override
  void initState() {
    super.initState();
    _checkTokenAndAPI();
  }

  Future<void> _checkTokenAndAPI() async {
    try {
      final token = HiveService.getUserData('token') as String?;

      String info = '';
      info += '🔐 TOKEN CHECK\n';
      info += '═══════════════════════════════════\n';
      info += 'Token exists: ${token != null}\n';

      if (token != null) {
        info += 'Token length: ${token.length}\n';
        info += 'Full token: $token\n';
        info += 'Token type: ${token.startsWith('eyJ') ? 'JWT' : 'Unknown'}\n';
      }

      info += '\n📞 TESTING GET /me/settings/phones\n';
      info += '═══════════════════════════════════\n';

      if (token != null) {
        try {
          final phones = await ContactService.getPhones(token: token);
          info += '✅ GET phones successful\n';
          info += 'Phones count: ${phones.data.length}\n';
          for (int i = 0; i < phones.data.length; i++) {
            info +=
                '  Phone ${i + 1}: ${phones.data[i].phone} (ID: ${phones.data[i].id})\n';
          }
        } catch (e) {
          info += '❌ GET phones failed: $e\n';
        }

        // Также проверяем emails
        info += '\n📧 TESTING GET /me/settings/emails\n';
        info += '═══════════════════════════════════\n';
        try {
          final emails = await ContactService.getEmails(token: token);
          info += '✅ GET emails successful\n';
          info += 'Emails count: ${emails.data.length}\n';
          for (int i = 0; i < emails.data.length; i++) {
            info +=
                '  Email ${i + 1}: ${emails.data[i].email} (ID: ${emails.data[i].id})\n';
          }
        } catch (e) {
          info += '❌ GET emails failed: $e\n';
        }
      } else {
        info += '⚠️ No token to test\n';
      }

      setState(() {
        _debugInfo = info;
      });
      // Дополнительные тесты: GET /me и POST /me/settings/emails
      await _testGetMe();
      await _testPostEmail();
    } catch (e) {
      setState(() {
        _debugInfo = 'Error: $e';
      });
    }
  }

  Future<void> _testGetMe() async {
    final token = HiveService.getUserData('token') as String?;
    String info = '\n🔎 TEST GET /me\n═══════════════════════════════════\n';
    if (token == null) {
      info += 'No token\n';
      setState(() => _debugInfo += info);
      return;
    }

    final headers = {...ApiService.defaultHeaders};
    headers['Authorization'] = 'Bearer $token';

    try {
      final res = await http
          .get(Uri.parse('${ApiService.baseUrl}/me'), headers: headers)
          .timeout(const Duration(seconds: 30));
      info += 'Status: ${res.statusCode}\nBody: ${res.body}\n';
    } catch (e) {
      info += 'Error: $e\n';
    }

    setState(() => _debugInfo += info);
  }

  Future<String?> _attemptRefreshToken() async {
    // Попробуем найти refresh token в Hive под разными ключами
    final refresh =
        HiveService.getUserData('refreshToken') ??
        HiveService.getUserData('refresh_token');

    if (refresh == null) {
      setState(
        () => _debugInfo +=
            '\nℹ️ No refresh token stored in Hive. Skip refresh attempt.\n',
      );
      return null;
    }

    final headers = {...ApiService.defaultHeaders};
    final body = {'refresh_token': refresh};

    try {
      final res = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/auth/refresh-token'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      setState(
        () => _debugInfo +=
            '\n🔁 Refresh token status: ${res.statusCode}\nBody: ${res.body}\n',
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        // Попробуем найти access token в ответе
        final newToken = data['data']?['access_token'] ?? data['access_token'];
        if (newToken is String) {
          await HiveService.saveUserData('token', newToken);
          return newToken;
        }
      }
    } catch (e) {
      setState(() => _debugInfo += '\n❌ Refresh token request failed: $e\n');
    }
    return null;
  }

  Future<void> _testPostEmail() async {
    String info =
        '\n✉️ TEST POST /me/settings/emails\n═══════════════════════════════════\n';

    String? token = HiveService.getUserData('token') as String?;
    if (token == null) {
      info += 'No token\n';
      setState(() => _debugInfo += info);
      return;
    }

    final headers = {...ApiService.defaultHeaders};
    headers['Authorization'] = 'Bearer $token';

    final body = {'email': 'debug+test@example.com'};

    try {
      var res = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/me/settings/emails'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      info += 'First attempt - Status: ${res.statusCode}\nBody: ${res.body}\n';

      // Если сервер явно отвечает unauthorized, попробуем refresh-token и ретрай
      if (res.statusCode == 401 ||
          (res.statusCode == 500 &&
              res.body.contains('This action is unauthorized'))) {
        info +=
            '\nDetected unauthorized response, attempting refresh-token...\n';
        final newToken = await _attemptRefreshToken();
        if (newToken != null) {
          token = newToken;
          final headers2 = {...ApiService.defaultHeaders};
          headers2['Authorization'] = 'Bearer $token';
          try {
            res = await http
                .post(
                  Uri.parse('${ApiService.baseUrl}/me/settings/emails'),
                  headers: headers2,
                  body: jsonEncode(body),
                )
                .timeout(const Duration(seconds: 30));
            info +=
                'Retry attempt - Status: ${res.statusCode}\nBody: ${res.body}\n';
          } catch (e) {
            info += 'Retry attempt failed: $e\n';
          }
        } else {
          info += 'Refresh token not available or refresh failed.\n';
        }
      }
    } catch (e) {
      info += 'Error: $e\n';
    }

    // После POST - проверяем, что email появился в списке
    try {
      final emails = await ContactService.getEmails(token: token);
      info += '\n🔎 Verification GET /me/settings/emails\n';
      info += 'Emails count: ${emails.data.length}\n';
      for (int i = 0; i < emails.data.length; i++) {
        info +=
            '  Email ${i + 1}: ${emails.data[i].email} (ID: ${emails.data[i].id})\n';
      }
    } catch (e) {
      info += '\n❌ Verification GET failed: $e\n';
    }

    setState(() => _debugInfo += info);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Token & API')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _debugInfo,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkTokenAndAPI,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
