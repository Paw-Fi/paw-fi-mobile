/// Household entity representing a shared financial space
class Household {
  final String id;
  final String name;
  final String ownerId;
  final String? coverImageUrl; // Changed from emoji - stores full URL to uploaded image
  final String? themeColor;
  final String currency; // ISO 4217 (e.g., USD)
  final DateTime createdAt;
  final DateTime updatedAt;

  const Household({
    required this.id,
    required this.name,
    required this.ownerId,
    this.coverImageUrl,
    this.themeColor,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      themeColor: json['theme_color'] as String?,
      currency: (json['currency'] as String).toUpperCase(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'cover_image_url': coverImageUrl,
      'theme_color': themeColor,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Household copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? coverImageUrl,
    String? themeColor,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      themeColor: themeColor ?? this.themeColor,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Household &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          ownerId == other.ownerId &&
          coverImageUrl == other.coverImageUrl &&
          themeColor == other.themeColor &&
          currency == other.currency &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      ownerId.hashCode ^
      coverImageUrl.hashCode ^
      themeColor.hashCode ^
      currency.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}

/// Household member role enum
enum HouseholdRole {
  owner,
  admin,
  member;

  String toJson() {
    switch (this) {
      case HouseholdRole.owner:
        return 'owner';
      case HouseholdRole.admin:
        return 'admin';
      case HouseholdRole.member:
        return 'member';
    }
  }

  static HouseholdRole fromJson(String value) {
    switch (value) {
      case 'owner':
        return HouseholdRole.owner;
      case 'admin':
        return HouseholdRole.admin;
      case 'member':
        return HouseholdRole.member;
      default:
        throw ArgumentError('Unknown HouseholdRole: $value');
    }
  }
}

/// Household member entity
class HouseholdMember {
  final String id;
  final String householdId;
  final String userId;
  final HouseholdRole role;
  final DateTime joinedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userEmail;
  final String? userName;
  final String? avatarUrl;

  const HouseholdMember({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.createdAt,
    required this.updatedAt,
    this.userEmail,
    this.userName,
    this.avatarUrl,
  });

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    // Extract user data from nested users object if available
    final userData = json['users'] as Map<String, dynamic>?;
    
    return HouseholdMember(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      userId: json['user_id'] as String,
      role: HouseholdRole.fromJson(json['role'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userEmail: userData?['email'] as String? ?? json['user_email'] as String?,
      userName: userData?['full_name'] as String? ?? json['user_name'] as String?,
      avatarUrl: userData?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'user_id': userId,
      'role': role.toJson(),
      'joined_at': joinedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_email': userEmail,
      'user_name': userName,
      'avatar_url': avatarUrl,
    };
  }

  HouseholdMember copyWith({
    String? id,
    String? householdId,
    String? userId,
    HouseholdRole? role,
    DateTime? joinedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userEmail,
    String? userName,
    String? avatarUrl,
  }) {
    return HouseholdMember(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdMember &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Invite status enum
enum InviteStatus {
  pending,
  accepted,
  revoked,
  expired;

  String toJson() {
    switch (this) {
      case InviteStatus.pending:
        return 'pending';
      case InviteStatus.accepted:
        return 'accepted';
      case InviteStatus.revoked:
        return 'revoked';
      case InviteStatus.expired:
        return 'expired';
    }
  }

  static InviteStatus fromJson(String value) {
    switch (value) {
      case 'pending':
        return InviteStatus.pending;
      case 'accepted':
        return InviteStatus.accepted;
      case 'revoked':
        return InviteStatus.revoked;
      case 'expired':
        return InviteStatus.expired;
      default:
        throw ArgumentError('Unknown InviteStatus: $value');
    }
  }
}

/// Household invite entity
class HouseholdInvite {
  final String id;
  final String token;
  final String householdId;
  final String inviterId;
  final String? invitedUserId;
  final InviteStatus status;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String? invitedEmail;
  final String? personalMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? inviterEmail;
  final String? householdName;

  const HouseholdInvite({
    required this.id,
    required this.token,
    required this.householdId,
    required this.inviterId,
    this.invitedUserId,
    required this.status,
    this.expiresAt,
    this.acceptedAt,
    this.invitedEmail,
    this.personalMessage,
    required this.createdAt,
    required this.updatedAt,
    this.inviterEmail,
    this.householdName,
  });

  factory HouseholdInvite.fromJson(Map<String, dynamic> json) {
    return HouseholdInvite(
      id: json['id'] as String,
      token: json['token'] as String,
      householdId: json['household_id'] as String,
      inviterId: json['inviter_id'] as String,
      invitedUserId: json['invited_user_id'] as String?,
      status: InviteStatus.fromJson(json['status'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      invitedEmail: json['invited_email'] as String?,
      personalMessage: json['personal_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      inviterEmail: json['inviter_email'] as String?,
      householdName: json['household_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token': token,
      'household_id': householdId,
      'inviter_id': inviterId,
      'invited_user_id': invitedUserId,
      'status': status.toJson(),
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'invited_email': invitedEmail,
      'personal_message': personalMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'inviter_email': inviterEmail,
      'household_name': householdName,
    };
  }

  HouseholdInvite copyWith({
    String? id,
    String? token,
    String? householdId,
    String? inviterId,
    String? invitedUserId,
    InviteStatus? status,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    String? invitedEmail,
    String? personalMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? inviterEmail,
    String? householdName,
  }) {
    return HouseholdInvite(
      id: id ?? this.id,
      token: token ?? this.token,
      householdId: householdId ?? this.householdId,
      inviterId: inviterId ?? this.inviterId,
      invitedUserId: invitedUserId ?? this.invitedUserId,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      personalMessage: personalMessage ?? this.personalMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      inviterEmail: inviterEmail ?? this.inviterEmail,
      householdName: householdName ?? this.householdName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdInvite &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
