import 'package:flutter/foundation.dart';

String defaultApiProxyBaseUrl() {
  const configured = String.fromEnvironment('API_PROXY_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kIsWeb && kReleaseMode) return Uri.base.origin;
  return 'http://127.0.0.1:8787';
}
