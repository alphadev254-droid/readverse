// TODO: Replace with real API calls when backend is ready
// All methods currently return mock data

class ApiService {
  static String? _token;

  static void setToken(String token) => _token = token;
  static void clearToken() => _token = null;
  static String? get token => _token;

  // TODO: Implement real login — POST /auth/login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (email.isNotEmpty && password.length >= 6) {
      return {
        'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        'user': {
          'id': 'user_001',
          'name': email.split('@').first,
          'email': email,
          'avatarUrl': null,
        }
      };
    }
    throw Exception('Invalid credentials');
  }

  // TODO: Implement real signup — POST /auth/signup
  static Future<Map<String, dynamic>> signup(
      String email, String password, String name) async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'user': {
        'id': 'user_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'email': email,
        'avatarUrl': null,
      }
    };
  }

  // TODO: Implement real forgot password — POST /auth/forgot-password
  static Future<void> forgotPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  // TODO: GET /documents
  static Future<List<Map<String, dynamic>>> getDocuments() async => [];

  // TODO: PUT /documents/:docId/progress
  static Future<void> updateProgress(String docId, int lastPage) async {}
}
