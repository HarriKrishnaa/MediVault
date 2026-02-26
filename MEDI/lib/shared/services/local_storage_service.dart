class LocalStorageService {
  Future<void> saveToken(String token) async {
    print('Token saved: $token');
  }

  Future<String?> getToken() async {
    return 'mock_token';
  }

  Future<void> clear() async {
    print('Storage cleared');
  }
}
