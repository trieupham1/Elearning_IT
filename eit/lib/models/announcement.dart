// models/announcement.dart

/// Main Announcement model with full tracking support
class Announcement {
  final String id;
  final String courseId;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final List<String> groupIds;
  final List<AnnouncementAttachment> attachments;
  final List<AnnouncementComment> comments;
  final List<AnnouncementView> viewedBy;
  final List<AnnouncementDownload> downloadedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated fields (optional)
  final List<GroupInfo>? groups;

  Announcement({
    required this.id,
    required this.courseId,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.groupIds,
    required this.attachments,
    required this.comments,
    required this.viewedBy,
    required this.downloadedBy,
    required this.createdAt,
    required this.updatedAt,
    this.groups,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorId: json['authorId'] is String
          ? json['authorId']
          : (json['authorId']?['_id']?.toString() ?? ''),
      authorName:
          json['authorName'] ??
          (json['authorId'] is Map
              ? json['authorId']['fullName'] ??
                    json['authorId']['username'] ??
                    'Unknown'
              : 'Unknown'),
      authorAvatar:
          json['authorAvatar'] ??
          (json['authorId'] is Map ? json['authorId']['avatar'] : null),
      groupIds: json['groupIds'] != null
          ? List<String>.from(
              json['groupIds'].map(
                (g) => g is String ? g : g['_id']?.toString() ?? '',
              ),
            )
          : [],
      attachments: json['attachments'] != null
          ? List<AnnouncementAttachment>.from(
              (json['attachments'] as List).map(
                (a) => AnnouncementAttachment.fromJson(a),
              ),
            )
          : [],
      comments: json['comments'] != null
          ? List<AnnouncementComment>.from(
              (json['comments'] as List).map(
                (c) => AnnouncementComment.fromJson(c),
              ),
            )
          : [],
      viewedBy: json['viewedBy'] != null
          ? List<AnnouncementView>.from(
              (json['viewedBy'] as List).map(
                (v) => AnnouncementView.fromJson(v),
              ),
            )
          : [],
      downloadedBy: json['downloadedBy'] != null
          ? List<AnnouncementDownload>.from(
              (json['downloadedBy'] as List).map(
                (d) => AnnouncementDownload.fromJson(d),
              ),
            )
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      groups: json['groupIds'] != null && json['groupIds'].isNotEmpty
          ? List<GroupInfo>.from(
              (json['groupIds'] as List)
                  .where((g) => g is Map)
                  .map((g) => GroupInfo.fromJson(g)),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'courseId': courseId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'groupIds': groupIds,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'comments': comments.map((c) => c.toJson()).toList(),
      'viewedBy': viewedBy.map((v) => v.toJson()).toList(),
      'downloadedBy': downloadedBy.map((d) => d.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  int get viewCount => viewedBy.length;
  int get uniqueViewerCount => viewedBy.map((v) => v.userId).toSet().length;
  int get downloadCount => downloadedBy.length;
  int get uniqueDownloaderCount =>
      downloadedBy.map((d) => d.userId).toSet().length;
  int get commentCount => comments.length;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get isForAllGroups => groupIds.isEmpty;

  String get groupDisplay {
    if (isForAllGroups) return 'All Students';
    if (groups != null && groups!.isNotEmpty) {
      return groups!.map((g) => g.name).join(', ');
    }
    return '${groupIds.length} group(s)';
  }

  // Check if user has viewed
  bool hasUserViewed(String userId) {
    return viewedBy.any((v) => v.userId == userId);
  }

  // Check if user has downloaded a file
  bool hasUserDownloadedFile(String userId, String fileName) {
    return downloadedBy.any(
      (d) => d.userId == userId && d.fileName == fileName,
    );
  }

  // Get download count for a specific file
  int getFileDownloadCount(String fileName) {
    return downloadedBy.where((d) => d.fileName == fileName).length;
  }
}

/// Attachment model for files attached to announcements
class AnnouncementAttachment {
  final String name;
  final String url;
  final int size;

  AnnouncementAttachment({
    required this.name,
    required this.url,
    required this.size,
  });

  factory AnnouncementAttachment.fromJson(Map<String, dynamic> json) {
    return AnnouncementAttachment(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      size: json['size'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'url': url, 'size': size};
  }

  // Format file size for display
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Get file extension
  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  // Check if file is an image
  bool get isImage {
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return imageExtensions.contains(extension);
  }

  // Check if file is a document
  bool get isDocument {
    const docExtensions = [
      'pdf',
      'doc',
      'docx',
      'txt',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
    ];
    return docExtensions.contains(extension);
  }
}

/// Comment model for announcement discussions
class AnnouncementComment {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String text;
  final DateTime createdAt;

  AnnouncementComment({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.text,
    required this.createdAt,
  });

  factory AnnouncementComment.fromJson(Map<String, dynamic> json) {
    return AnnouncementComment(
      userId: json['userId'] is String
          ? json['userId']
          : (json['userId']?['_id']?.toString() ?? ''),
      userName:
          json['userName'] ??
          (json['userId'] is Map
              ? json['userId']['fullName'] ??
                    json['userId']['username'] ??
                    'Unknown'
              : 'Unknown'),
      userAvatar:
          json['userAvatar'] ??
          (json['userId'] is Map ? json['userId']['avatar'] : null),
      text: json['text'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// View tracking model
class AnnouncementView {
  final String userId;
  final DateTime viewedAt;

  AnnouncementView({required this.userId, required this.viewedAt});

  factory AnnouncementView.fromJson(Map<String, dynamic> json) {
    return AnnouncementView(
      userId: json['userId'] is String
          ? json['userId']
          : (json['userId']?['_id']?.toString() ?? ''),
      viewedAt: json['viewedAt'] != null
          ? DateTime.parse(json['viewedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'viewedAt': viewedAt.toIso8601String()};
  }
}

/// Download tracking model
class AnnouncementDownload {
  final String userId;
  final String fileName;
  final DateTime downloadedAt;

  AnnouncementDownload({
    required this.userId,
    required this.fileName,
    required this.downloadedAt,
  });

  factory AnnouncementDownload.fromJson(Map<String, dynamic> json) {
    return AnnouncementDownload(
      userId: json['userId'] is String
          ? json['userId']
          : (json['userId']?['_id']?.toString() ?? ''),
      fileName: json['fileName'] ?? '',
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.parse(json['downloadedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fileName': fileName,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }
}

/// Group info model for populated group data
class GroupInfo {
  final String id;
  final String name;

  GroupInfo({required this.id, required this.name});

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      id: json['_id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Group',
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name};
  }
}
