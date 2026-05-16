String resolveApiBaseUrl() {
  const configuredUrl = String.fromEnvironment('API_BASE_URL');
  if (configuredUrl.isNotEmpty) {
    return configuredUrl;
  }
  return 'http://localhost:8000';
}
