class UserData {
  final int id;
  final String name;
  final String? mobile;
  final int roleId;
  final int status; // NEW: To track user approval state (0=pending, 1=active)

  UserData({
    required this.id,
    required this.name,
    this.mobile,
    required this.roleId,
    required this.status, // NEW
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      name: json['name'],
      mobile: json['mobile'],
      roleId: json['role_id'] ?? 0,
      status: json['status'] ?? 0, // NEW: Default to pending if null
    );
  }
}