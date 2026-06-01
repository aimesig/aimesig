// lib/core/models/user_model.dart

class UserModel {
  final String  id;
  final String  email;
  final String  name;
  final String  role; // tenant_admin | staff | member
  final String  tenantId;
  final bool    mustChangePassword;
  final String? linkedStaffId;
  final String? linkedMemberId;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.tenantId,
    this.mustChangePassword = false,
    this.linkedStaffId,
    this.linkedMemberId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:                 json['id']           as String,
        email:              json['email']         as String,
        name:               json['name']          as String,
        role:               json['role']          as String,
        tenantId:           (json['tenant_id'] ?? '') as String,
        mustChangePassword: (json['must_change_password'] as bool?) ?? false,
        linkedStaffId:      json['linked_staff_id']  as String?,
        linkedMemberId:     json['linked_member_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id':                   id,
        'email':                email,
        'name':                 name,
        'role':                 role,
        'tenant_id':            tenantId,
        'must_change_password': mustChangePassword,
        if (linkedStaffId  != null) 'linked_staff_id':  linkedStaffId,
        if (linkedMemberId != null) 'linked_member_id': linkedMemberId,
      };

  bool get isAdmin  => role == 'tenant_admin';
  bool get isStaff  => role == 'staff';
  bool get isMember => role == 'member';
}

// ── Tenant model ──────────────────────────────────────────────────────────────
class TenantModel {
  final String id;
  final String name;
  final String slug;

  const TenantModel({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) => TenantModel(
        id:   json['id']   as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}