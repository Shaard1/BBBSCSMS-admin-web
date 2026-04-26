import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      return false;
    }

    final isAdmin = await isCurrentUserAdmin();

    if (!isAdmin) {
      await _client.auth.signOut();
    }

    return isAdmin;
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return false;
    }

    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    return profile?['role'] == 'admin';
  }
}
