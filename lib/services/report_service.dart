import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_model.dart';

class ReportService {
  final supabase = Supabase.instance.client;

  /// FETCH REPORTS
  Future<List<Report>> fetchReports() async {
    final response = await supabase
        .from('reports')
        .select()
        .order('created_at', ascending: false);

    final reportRows = List<Map<String, dynamic>>.from(response);
    final userIds = reportRows
        .map((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, String> nameByUserId = {};

    if (userIds.isNotEmpty) {
      try {
        final residents = await supabase
            .from('residents')
            .select('id, full_name')
            .inFilter('id', userIds);

        for (final resident in residents as List) {
          final id = resident['id']?.toString() ?? '';
          final name = resident['full_name']?.toString() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) {
            nameByUserId[id] = name;
          }
        }
      } catch (_) {}

      try {
        final profiles = await supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', userIds);

        for (final profile in profiles as List) {
          final id = profile['id']?.toString() ?? '';
          final name = profile['full_name']?.toString() ?? '';
          if (id.isNotEmpty &&
              name.isNotEmpty &&
              !nameByUserId.containsKey(id)) {
            nameByUserId[id] = name;
          }
        }
      } catch (_) {}
    }

    final enrichedReports = reportRows.map((row) {
      final userId = row['user_id']?.toString() ?? '';
      row['reporter_name'] = nameByUserId[userId] ?? 'Unknown resident';
      return row;
    }).toList();

    return enrichedReports.map(Report.fromJson).toList();
  }

  /// UPDATE STATUS
  Future<void> updateStatus(String reportId, String status) async {
    await supabase
        .from('reports')
        .update({'status': status})
        .eq('id', reportId);
  }

  /// NEW: UPDATE CATEGORY
  Future<void> updateCategory(String reportId, String category) async {
    await supabase
        .from('reports')
        .update({'category': category})
        .eq('id', reportId);
  }

  Future<void> updateAdminNote(String reportId, String adminNote) async {
    await supabase
        .from('reports')
        .update({'admin_note': adminNote.trim()})
        .eq('id', reportId);
  }

  /// DELETE REPORT
  Future<void> deleteReport(String reportId) async {
    await supabase.from('reports').delete().eq('id', reportId);
  }
}
