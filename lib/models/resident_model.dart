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
    required this.profileImage,
    required this.profileImageOriginal,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  factory Resident.fromJson(Map<String, dynamic> json) {
    return Resident(
      id: json['id'].toString(),
      fullName: json['full_name'] ?? '',
      birthdate: json['birthdate']?.toString() ?? '',
      address: json['address'] ?? '',
      contactNumber: json['contact_number'] ?? '',
      civilStatus: json['civil_status'] ?? '',
      gender: json['gender'] ?? '',
      idType: json['id_type'] ?? '',
      idImage: json['id_image'] ?? '',
      profileImage: json['profile_image'] ?? '',
      profileImageOriginal: json['profile_image_original'] ?? '',
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'] ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
