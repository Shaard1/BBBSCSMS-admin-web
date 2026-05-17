class Resident {
  final String id;
  final String fullName;
  final String birthdate;
  final String address;
  final String contactNumber;
  final String civilStatus;
  final String gender;
  final String idType;
  final String idImage;
  final String idImageFront;
  final String idImageBack;
  final String profileImage;
  final String profileImageOriginal;
  final String status;
  final String rejectionReason;
  final String createdAt;

  Resident({
    required this.id,
    required this.fullName,
    required this.birthdate,
    required this.address,
    required this.contactNumber,
    required this.civilStatus,
    required this.gender,
    required this.idType,
    required this.idImage,
    required this.idImageFront,
    required this.idImageBack,
    required this.profileImage,
    required this.profileImageOriginal,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  static String _asString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  factory Resident.fromJson(Map<String, dynamic> json) {
    final legacyIdImage = _asString(json['id_image']);
    final frontImage = _asString(json['id_image_front']).isEmpty
        ? legacyIdImage
        : _asString(json['id_image_front']);
    final backImage = _asString(json['id_image_back']);

    return Resident(
      id: _asString(json['id']),
      fullName: _asString(json['full_name']),
      birthdate: _asString(json['birthdate']),
      address: _asString(json['address']),
      contactNumber: _asString(json['contact_number']),
      civilStatus: _asString(json['civil_status']),
      gender: _asString(json['gender']),
      idType: _asString(json['id_type']),
      idImage: legacyIdImage,
      idImageFront: frontImage,
      idImageBack: backImage,
      profileImage: _asString(json['profile_image']),
      profileImageOriginal: _asString(json['profile_image_original']),
      status: _asString(json['status']).isEmpty
          ? 'pending'
          : _asString(json['status']),
      rejectionReason: _asString(json['rejection_reason']),
      createdAt: _asString(json['created_at']),
    );
  }
}
