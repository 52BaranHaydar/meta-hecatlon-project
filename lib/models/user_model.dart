import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum UserRole {
  citizen('citizen', 'Vatandaş', Icons.person_rounded, AppColors.citizenBlue),
  carrier('carrier', 'Lojistik / Taşıyıcı', Icons.local_shipping_rounded, AppColors.carrierOrange),
  admin('admin', 'Kriz Yönetimi (Admin)', Icons.admin_panel_settings_rounded, AppColors.adminPurple);

  final String id;
  final String title;
  final IconData icon;
  final Color color;

  const UserRole(this.id, this.title, this.icon, this.color);

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'carrier':
        return UserRole.carrier;
      case 'admin':
        return UserRole.admin;
      case 'citizen':
      default:
        return UserRole.citizen;
    }
  }
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.id,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return UserModel(
      uid: id ?? map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      role: UserRole.fromString(map['role']),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
