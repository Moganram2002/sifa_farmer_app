class UserData {
  final int id;
  final String name;
  final String? mobile;
  final int roleId;
  final int status;
  final String? aadharNumber;
  final String? emergencyContact;
  final String? location;
  final String? bloodGroup;
  final String? gender;
  final String? maritalStatus;
  final String? religion;
  final String? occupation;
  final String? skill;
  final String? profileImagePath;
  final String? idDocumentPath;

  UserData({
    required this.id,
    required this.name,
    this.mobile,
    required this.roleId,
    required this.status,
    this.aadharNumber,
    this.emergencyContact,
    this.location,
    this.bloodGroup,
    this.gender,
    this.maritalStatus,
    this.religion,
    this.occupation,
    this.skill,
    this.profileImagePath,
    this.idDocumentPath,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      name: json['name'],
      mobile: json['mobile'],
      roleId: json['role_id'] ?? 0,
      status: json['status'] ?? 0,
      aadharNumber: json['aadhar_number'],
      emergencyContact: json['emergency_contact'],
      location: json['location'],
      bloodGroup: json['blood_group'],
      gender: json['gender'],
      maritalStatus: json['marital_status'],
      religion: json['religion'],
      occupation: json['occupation'],
      skill: json['skill'],
      profileImagePath: json['profile_image_path'],
      idDocumentPath: json['id_document_path'],
    );
  }

  Map<String, dynamic> toRegistrationData() {
    return {
      'name': name,
      'mobile': mobile,
      'aadhar_number': aadharNumber,
      'emergency_contact': emergencyContact,
      'location': location,
      'blood_group': bloodGroup,
      'gender': gender,
      'marital_status': maritalStatus,
      'religion': religion,
      'occupation': occupation,
      'skill': skill,
      'profile_photo_url': profileImagePath,
    };
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'aadhar_number': aadharNumber,
      'role_id': roleId,
      'status': status,
      'emergency_contact': emergencyContact,
      'location': location,
      'blood_group': bloodGroup,
      'gender': gender,
      'marital_status': maritalStatus,
      'religion': religion,
      'occupation': occupation,
      'skill': skill,
      'profile_image_path': profileImagePath,
      'id_document_path': idDocumentPath,
    };
  }
}