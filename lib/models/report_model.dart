import 'dart:convert';

class Report {
  final String id;
  final String userId;
  final String reporterName;
  final String description;
  final String status;
  final String category; // NEW
  final String adminNote;
  final String? imageUrl;
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  Report({
    required this.id,
    required this.userId,
    required this.reporterName,
    required this.description,
    required this.status,
    required this.category, // NEW
    required this.adminNote,
    this.imageUrl,
    required this.imageUrls,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  static List<String> _extractImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];

    void addUrl(dynamic value) {
      final url = value?.toString().trim() ?? '';
      if (url.isNotEmpty) {
        urls.add(url);
      }
    }

    addUrl(json['image_url']);

    final raw = json['image_urls'];
    if (raw is List) {
      for (final item in raw) {
        addUrl(item);
      }
    } else if (raw is String) {
      final text = raw.trim();
      if (text.startsWith('[') && text.endsWith(']')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) {
            for (final item in decoded) {
              addUrl(item);
            }
          }
        } catch (_) {
          addUrl(raw);
        }
      } else {
        addUrl(raw);
      }
    }

    return urls.toSet().toList();
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    final images = _extractImageUrls(json);
    final primaryImage =
        (json['image_url']?.toString().trim().isNotEmpty ?? false)
        ? json['image_url']?.toString()
        : (images.isNotEmpty ? images.first : null);

    return Report(
      id: json['id'],
      userId: json['user_id'] ?? '',
      reporterName: json['reporter_name'] ?? 'Unknown resident',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      category: json['category'] ?? 'Others', // NEW
      adminNote: json['admin_note']?.toString() ?? '',
      imageUrl: primaryImage,
      imageUrls: images,
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
