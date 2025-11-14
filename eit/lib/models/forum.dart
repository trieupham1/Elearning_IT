// models/forum.dart

class ForumTopic {
  final String id;
  final String courseId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String title;
  final String content;
  final List<ForumAttachment> attachments;
  bool isPinned;
  bool isLocked;
  final int views;
  final List<String> likes;
  final int replyCount;
  final DateTime lastActivityAt;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  ForumTopic({
    required this.id,
    required this.courseId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.title,
    required this.content,
    required this.attachments,
    required this.isPinned,
    required this.isLocked,
    required this.views,
    required this.likes,
    required this.replyCount,
    required this.lastActivityAt,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumTopic.fromJson(Map<String, dynamic> json) {
    return ForumTopic(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Unknown',
      authorRole: json['authorRole']?.toString() ?? 'student',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((a) => ForumAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      isPinned: json['isPinned'] == true,
      isLocked: json['isLocked'] == true,
      views: int.tryParse(json['views']?.toString() ?? '0') ?? 0,
      likes:
          (json['likes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      replyCount: int.tryParse(json['replyCount']?.toString() ?? '0') ?? 0,
      lastActivityAt:
          DateTime.tryParse(json['lastActivityAt']?.toString() ?? '') ??
          DateTime.now(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'courseId': courseId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'title': title,
      'content': content,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'isPinned': isPinned,
      'isLocked': isLocked,
      'views': views,
      'likes': likes,
      'replyCount': replyCount,
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ForumReply {
  final String id;
  final String topicId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String content;
  final String? parentReplyId;
  final List<ForumAttachment> attachments;
  final List<String> likes;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ForumReply({
    required this.id,
    required this.topicId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    this.parentReplyId,
    required this.attachments,
    required this.likes,
    required this.isEdited,
    this.editedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      topicId: json['topicId']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Unknown',
      authorRole: json['authorRole']?.toString() ?? 'student',
      content: json['content']?.toString() ?? '',
      parentReplyId: json['parentReplyId']?.toString(),
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((a) => ForumAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      likes:
          (json['likes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isEdited: json['isEdited'] == true,
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'].toString())
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'topicId': topicId,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'content': content,
      'parentReplyId': parentReplyId,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'likes': likes,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ForumAttachment {
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String mimeType;

  ForumAttachment({
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
  });

  factory ForumAttachment.fromJson(Map<String, dynamic> json) {
    return ForumAttachment(
      fileName: json['fileName'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      mimeType: json['mimeType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'mimeType': mimeType,
    };
  }
}

class ForumPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  ForumPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory ForumPagination.fromJson(Map<String, dynamic> json) {
    return ForumPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
