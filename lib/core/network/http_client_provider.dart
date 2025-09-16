import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// HTTP 客戶端提供者
/// 提供配置好的 HTTP 客戶端，支援 UTF-8 編碼
class Utf8HttpClient extends http.BaseClient {
  Utf8HttpClient(this._inner);
  
  final http.Client _inner;
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // 確保請求頭包含 UTF-8 編碼設定
    request.headers.putIfAbsent('Accept-Charset', () => 'utf-8');
    request.headers.putIfAbsent('Content-Type', () => 'application/json; charset=utf-8');
    return _inner.send(request);
  }
  
  @override
  void close() => _inner.close();
}

final httpClientProvider = Provider<http.Client>((ref) {
  final baseClient = http.Client();
  final client = Utf8HttpClient(baseClient);
  ref.onDispose(client.close);
  return client;
}, name: 'httpClientProvider');
