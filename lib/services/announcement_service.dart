import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement_model.dart';

class AnnouncementService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Announcement>> fetchAnnouncements() async {
    final response = await supabase
        .from('announcements')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Announcement.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    String thumbnailUrl = '',
    List<String> imageUrls = const [],
    bool isPublished = true,
  }) async {
    final user = supabase.auth.currentUser;

    await supabase.from('announcements').insert({
      'title': title.trim(),
      'content': content.trim(),
      'thumbnail_url': thumbnailUrl.trim(),
      'image_urls': imageUrls,
      'is_published': isPublished,
      'created_by': user?.id,
    });
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    String thumbnailUrl = '',
    List<String> imageUrls = const [],
    required bool isPublished,
  }) async {
    await supabase
        .from('announcements')
        .update({
          'title': title.trim(),
          'content': content.trim(),
          'thumbnail_url': thumbnailUrl.trim(),
          'image_urls': imageUrls,
          'is_published': isPublished,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    await supabase.from('announcements').delete().eq('id', id);
  }
}
