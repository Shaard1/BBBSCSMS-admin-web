import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resident_model.dart';

class ResidentService {
  final supabase = Supabase.instance.client;

  /// GET ALL RESIDENTS
  Future<List<Resident>> fetchResidents() async {
    final response = await supabase
        .from('residents')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((json) => Resident.fromJson(json)).toList();
  }

  /// APPROVE RESIDENT
  Future approveResident(String id) async {
    await supabase
        .from('residents')
        .update({'status': 'approved', 'rejection_reason': null})
        .eq('id', id);

    // Best-effort sync: some projects restrict admin writes to profiles via RLS.
    // Approval should still succeed even if this profile insert is blocked.
    try {
      final resident = await supabase
          .from('residents')
          .select('id, full_name')
          .eq('id', id)
          .single();

      await supabase.from('profiles').insert({
        'id': resident['id'],
        'full_name': resident['full_name'] ?? '',
        'role': 'resident',
      });
    } catch (_) {
      // Ignore and allow mobile app fallback to create the resident profile.
    }
  }

  /// REJECT RESIDENT
  Future rejectResident(String id, String reason) async {
    await supabase
        .from('residents')
        .update({'status': 'rejected', 'rejection_reason': reason})
        .eq('id', id);
  }
}
