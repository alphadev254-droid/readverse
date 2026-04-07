class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
      };

  UserModel copyWith({String? name, String? avatarUrl}) => UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}
