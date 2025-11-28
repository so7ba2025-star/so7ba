import 'package:so7ba/models/match_models.dart';

enum RoomStatus {
  waiting,
  inGame,
  finished,
}

enum RoomPrivacyType {
  public,
  private,
}

enum RoomJoinMode {
  instant,
  code,
  approval,
  codePlusApproval,
}

enum RoomLogoSource {
  preset,
  upload,
}

// Removed RoomGameMode. Game type will be chosen when starting a match, not at room level.

class RoomMember {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isHost;
  final bool isReady;
  final bool isSpectator;
  final Team? team;

  RoomMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isHost = false,
    this.isReady = false,
    this.isSpectator = false,
    this.team,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      isHost: json['is_host'] as bool? ?? false,
      isReady: json['is_ready'] as bool? ?? false,
      isSpectator: json['is_spectator'] as bool? ?? false,
      team: json['team'] != null ? Team.values.byName(json['team']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'is_host': isHost,
      'is_ready': isReady,
      'is_spectator': isSpectator,
      'team': team?.name,
    };
  }

  RoomMember copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    bool? isHost,
    bool? isReady,
    bool? isSpectator,
    Team? team,
  }) {
    return RoomMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isSpectator: isSpectator ?? this.isSpectator,
      team: team ?? this.team,
    );
  }
}

class Room {
  final String id;
  final String code;
  final String name;
  final String hostId;
  final RoomStatus status;
  final RoomPrivacyType privacyType;
  final RoomJoinMode joinMode;
  final bool discoverable;
  final String? description;
  final RoomLogoSource logoSource;
  final String? logoAssetKey;
  final String? logoUrl;
  final int? maxMembers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RoomMember> members;
  final List<RoomMessage> messages;
  final Map<String, dynamic> metadata;
  final DateTime? codeRotatedAt;

  Room({
    required this.id,
    required this.code,
    required this.name,
    required this.hostId,
    this.status = RoomStatus.waiting,
    this.privacyType = RoomPrivacyType.public,
    this.joinMode = RoomJoinMode.instant,
    this.discoverable = true,
    this.description,
    this.logoSource = RoomLogoSource.preset,
    this.logoAssetKey,
    this.logoUrl,
    this.maxMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoomMember>? members,
    List<RoomMessage>? messages,
    Map<String, dynamic>? metadata,
    DateTime? codeRotatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        members = members ?? const [],
        messages = messages ?? const [],
        metadata = metadata != null ? Map<String, dynamic>.from(metadata) : const {},
        codeRotatedAt = codeRotatedAt ?? (createdAt ?? DateTime.now());

  bool get isPrivate => privacyType == RoomPrivacyType.private;
  bool get isPublic => privacyType == RoomPrivacyType.public;
  bool get requiresJoinApproval =>
      joinMode == RoomJoinMode.approval || joinMode == RoomJoinMode.codePlusApproval;
  bool get requiresJoinCode =>
      joinMode == RoomJoinMode.code || joinMode == RoomJoinMode.codePlusApproval;

  factory Room.fromJson(Map<String, dynamic> json) {
    final isPrivateLegacy = json['is_private'] as bool? ?? false;
    final privacyValue = (json['privacy_type'] ?? (isPrivateLegacy ? 'private' : 'public'))
        .toString()
        .toLowerCase();
    final privacyType = RoomPrivacyType.values.firstWhere(
      (e) => e.name == privacyValue,
      orElse: () => isPrivateLegacy ? RoomPrivacyType.private : RoomPrivacyType.public,
    );

    final joinValue = json['join_mode']?.toString().toLowerCase();
    final fallbackJoin = privacyType == RoomPrivacyType.public
        ? RoomJoinMode.instant
        : RoomJoinMode.approval;
    final joinMode = joinValue != null
        ? RoomJoinMode.values.firstWhere(
            (mode) => mode.name.toLowerCase() == joinValue,
            orElse: () => fallbackJoin,
          )
        : fallbackJoin;

    final logoSourceValue = json['logo_source']?.toString().toLowerCase();
    final hasLogoUrl = (json['logo_url'] as String?)?.isNotEmpty ?? false;
    final defaultLogoSource = hasLogoUrl ? RoomLogoSource.upload : RoomLogoSource.preset;
    final logoSource = logoSourceValue != null
        ? RoomLogoSource.values.firstWhere(
            (source) => source.name.toLowerCase() == logoSourceValue,
            orElse: () => defaultLogoSource,
          )
        : defaultLogoSource;

    final rawMetadata = json['metadata'];
    Map<String, dynamic> metadata = const {};
    if (rawMetadata is Map) {
      metadata = Map<String, dynamic>.from(rawMetadata);
    }

    DateTime? codeRotatedAt;
    final codeRotatedAtRaw = metadata['code_rotated_at'];
    if (codeRotatedAtRaw is String) {
      codeRotatedAt = DateTime.tryParse(codeRotatedAtRaw);
    } else if (codeRotatedAtRaw is DateTime) {
      codeRotatedAt = codeRotatedAtRaw;
    }

    return Room(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? 'غرفة بدون اسم',
      hostId: json['host_id'] as String? ?? '',
      status: RoomStatus.values.firstWhere(
        (e) => e.toString() == 'RoomStatus.${json['status']}',
        orElse: () => RoomStatus.waiting,
      ),
      privacyType: privacyType,
      joinMode: joinMode,
      discoverable: json['discoverable'] as bool? ?? true,
      description: json['description'] as String?,
      logoSource: logoSource,
      logoAssetKey: json['logo_asset_key'] as String?,
      logoUrl: json['logo_url'] as String?,
      maxMembers: json['max_members'] as int?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : (json['created_at'] is DateTime)
              ? json['created_at'] as DateTime
              : DateTime.now(),
      updatedAt: json['updated_at'] is String
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : (json['updated_at'] is DateTime)
              ? json['updated_at'] as DateTime
              : DateTime.now(),
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => RoomMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => RoomMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      metadata: metadata,
      codeRotatedAt: codeRotatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'host_id': hostId,
      'status': status.toString().split('.').last,
      'privacy_type': privacyType.name,
      'join_mode': joinMode.name,
      'discoverable': discoverable,
      if (description != null && description!.isNotEmpty) 'description': description,
      'logo_source': logoSource.name,
      if (logoAssetKey != null) 'logo_asset_key': logoAssetKey,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (maxMembers != null) 'max_members': maxMembers,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'members': members.map((e) => e.toJson()).toList(),
      'messages': messages.map((e) => e.toJson()).toList(),
      'metadata': metadata,
      if (codeRotatedAt != null) 'code_rotated_at': codeRotatedAt!.toIso8601String(),
    };
  }

  Room copyWith({
    String? id,
    String? code,
    String? name,
    String? hostId,
    RoomStatus? status,
    RoomPrivacyType? privacyType,
    RoomJoinMode? joinMode,
    bool? discoverable,
    String? description,
    RoomLogoSource? logoSource,
    String? logoAssetKey,
    String? logoUrl,
    int? maxMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoomMember>? members,
    List<RoomMessage>? messages,
    Map<String, dynamic>? metadata,
    DateTime? codeRotatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      privacyType: privacyType ?? this.privacyType,
      joinMode: joinMode ?? this.joinMode,
      discoverable: discoverable ?? this.discoverable,
      description: description ?? this.description,
      logoSource: logoSource ?? this.logoSource,
      logoAssetKey: logoAssetKey ?? this.logoAssetKey,
      logoUrl: logoUrl ?? this.logoUrl,
      maxMembers: maxMembers ?? this.maxMembers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      messages: messages ?? this.messages,
      metadata: metadata ?? this.metadata,
      codeRotatedAt: codeRotatedAt ?? this.codeRotatedAt,
    );
  }

  bool get canStartGame {
    // Generic rule: at least 2 ready non-host players to allow starting a match.
    final readyPlayers = members.where((m) => !m.isHost && m.isReady).length;
    return readyPlayers >= 2;
  }

  RoomMember? getHost() {
    try {
      return members.firstWhere((m) => m.isHost);
    } catch (e) {
      return null;
    }
  }
}

class RoomMessage {
  final String id;
  final String roomId;
  final String userId;
  final String displayName;
  final String content;
  final DateTime sentAt;
  final bool isSystem;
  final String? avatarUrl;
  final String? emoji;
  final List<String>? images;
  final List<String>? animatedImages;
  final Map<String, List<String>> reactions;
  final String? audioUrl;
  final int? audioDurationMs;

  RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.content,
    required this.sentAt,
    this.isSystem = false,
    this.avatarUrl,
    this.emoji,
    this.images,
    this.animatedImages,
    this.audioUrl,
    this.audioDurationMs,
    Map<String, List<String>>? reactions,
  }) : reactions = _normalizeReactions(reactions);

  factory RoomMessage.fromJson(Map<String, dynamic> json) {
    DateTime sentAt;
    
    // Handle different date formats
    if (json['sent_at'] is String) {
      String dateStr = json['sent_at'] as String;
      
      // Convert Z format to local format for consistent comparison
      if (dateStr.endsWith('Z')) {
        // Parse UTC time and convert to local
        sentAt = DateTime.parse(dateStr).toLocal();
      } else {
        // Parse local time directly
        sentAt = DateTime.parse(dateStr);
      }
    } else if (json['sent_at'] is DateTime) {
      sentAt = json['sent_at'] as DateTime;
    } else {
      sentAt = DateTime.now();
    }
    
    Map<String, List<String>> reactions = const {};
    final rawReactions = json['reactions'];
    if (rawReactions is Map) {
      reactions = _normalizeReactions(
        rawReactions.map(
          (key, value) => MapEntry(
            key.toString(),
            value is List
                ? value.map((e) => e.toString()).toList()
                : <String>[],
          ),
        ),
      );
    }

    return RoomMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id']?.toString() ?? 'system',
      displayName: json['display_name'] as String,
      content: json['content'] as String,
      sentAt: sentAt,
      isSystem: json['is_system'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
      emoji: json['emoji'] as String?,
      images: (json['images'] as List<dynamic>?)?.cast<String>(),
      animatedImages: (json['animated_images'] as List<dynamic>?)?.cast<String>(),
      audioUrl: json['audio_url'] as String?,
      audioDurationMs: json['audio_duration_ms'] is num
          ? (json['audio_duration_ms'] as num).toInt()
          : int.tryParse('${json['audio_duration_ms']}'),
      reactions: reactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'display_name': displayName,
      'content': content,
      'sent_at': sentAt.toIso8601String(),
      'is_system': isSystem,
      'avatar_url': avatarUrl,
      'emoji': emoji,
      'images': images,
      'animated_images': animatedImages,
      'audio_url': audioUrl,
      'audio_duration_ms': audioDurationMs,
      'reactions': reactions.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
    };
  }

  RoomMessage copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? displayName,
    String? content,
    DateTime? sentAt,
    bool? isSystem,
    String? avatarUrl,
    String? emoji,
    List<String>? images,
    List<String>? animatedImages,
    Map<String, List<String>>? reactions,
    String? audioUrl,
    int? audioDurationMs,
  }) {
    return RoomMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      isSystem: isSystem ?? this.isSystem,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emoji: emoji ?? this.emoji,
      images: images ?? this.images,
      animatedImages: animatedImages ?? this.animatedImages,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      reactions: reactions ?? this.reactions,
    );
  }

  static Map<String, List<String>> normalizeReactions(
    Map<String, List<String>>? source,
  ) => _normalizeReactions(source);

  static Map<String, List<String>> _normalizeReactions(
    Map<String, List<String>>? source,
  ) {
    if (source == null || source.isEmpty) {
      return const {};
    }

    final normalized = <String, List<String>>{};
    source.forEach((key, value) {
      if (key.isEmpty) return;
      final users = value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      if (users.isNotEmpty) {
        normalized[key] = List<String>.unmodifiable(users);
      }
    });

    if (normalized.isEmpty) {
      return const {};
    }

    return Map<String, List<String>>.unmodifiable(normalized);
  }
}
