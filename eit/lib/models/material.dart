class MaterialFile {
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String mimeType;

  MaterialFile({
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
  });

  factory MaterialFile.fromJson(Map<String, dynamic> json) {
    return MaterialFile(
      fileName: json['fileName']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
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

class MaterialView {
  final String userId;
  final DateTime viewedAt;

  MaterialView({
    required this.userId,
    required this.viewedAt,
  });

  factory MaterialView.fromJson(Map<String, dynamic> json) {
    return MaterialView(
      userId: json['userId']?.toString() ?? '',
      viewedAt: json['viewedAt'] != null 
          ? DateTime.tryParse(json['viewedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'viewedAt': viewedAt.toIso8601String(),
    };
  }
}

class MaterialDownload {
  final String userId;
  final String fileName;
  final DateTime downloadedAt;

  MaterialDownload({
    required this.userId,
    required this.fileName,
    required this.downloadedAt,
  });

  factory MaterialDownload.fromJson(Map<String, dynamic> json) {
    return MaterialDownload(
      userId: json['userId']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      downloadedAt: json['downloadedAt'] != null 
          ? DateTime.tryParse(json['downloadedAt'].toString()) ?? DateTime.now()
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

class Material {
  final String id;
  final String courseId;
  final String createdBy;
  final String title;
  final String? description;
  final List<MaterialFile> files;
  final List<String> links;
  final List<MaterialView> viewedBy;
  final List<MaterialDownload> downloadedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional fields for display
  final String? type; // For classwork integration
  final String? authorName; // Populated createdBy name

  Material({
    required this.id,
    required this.courseId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.files,
    required this.links,
    required this.viewedBy,
    required this.downloadedBy,
    required this.createdAt,
    required this.updatedAt,
    this.type,
    this.authorName,
  });

  factory Material.fromJson(Map<String, dynamic> json) {
    // Handle backend response format
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    
    // Handle populated createdBy field
    String createdBy = '';
    String? authorName;
    if (json['createdBy'] is String) {
      createdBy = json['createdBy'];
    } else if (json['createdBy'] is Map) {
      final createdByMap = json['createdBy'] as Map<String, dynamic>;
      createdBy = createdByMap['_id']?.toString() ?? '';
      // Create author name from populated data
      if (createdByMap['firstName'] != null || createdByMap['lastName'] != null) {
        authorName = '${createdByMap['firstName'] ?? ''} ${createdByMap['lastName'] ?? ''}'.trim();
      } else {
        authorName = createdByMap['username']?.toString() ?? createdByMap['email']?.toString();
      }
    }

    // Parse files array
    final List<MaterialFile> files = [];
    if (json['files'] is List) {
      for (final fileJson in json['files']) {
        if (fileJson is Map<String, dynamic>) {
          files.add(MaterialFile.fromJson(fileJson));
        }
      }
    }

    // Parse links array
    final List<String> links = [];
    if (json['links'] is List) {
      for (final link in json['links']) {
        if (link is String) {
          links.add(link);
        }
      }
    }

    // Parse viewedBy array
    final List<MaterialView> viewedBy = [];
    if (json['viewedBy'] is List) {
      for (final viewJson in json['viewedBy']) {
        if (viewJson is Map<String, dynamic>) {
          viewedBy.add(MaterialView.fromJson(viewJson));
        }
      }
    }

    // Parse downloadedBy array
    final List<MaterialDownload> downloadedBy = [];
    if (json['downloadedBy'] is List) {
      for (final downloadJson in json['downloadedBy']) {
        if (downloadJson is Map<String, dynamic>) {
          downloadedBy.add(MaterialDownload.fromJson(downloadJson));
        }
      }
    }

    return Material(
      id: id,
      courseId: json['courseId']?.toString() ?? '',
      createdBy: createdBy,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      files: files,
      links: links,
      viewedBy: viewedBy,
      downloadedBy: downloadedBy,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      type: json['type']?.toString(),
      authorName: authorName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'files': files.map((f) => f.toJson()).toList(),
      'links': links,
      'viewedBy': viewedBy.map((v) => v.toJson()).toList(),
      'downloadedBy': downloadedBy.map((d) => d.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'type': type,
      'authorName': authorName,
    };
  }

  // Helper methods
  int get totalViews => viewedBy.length;
  int get totalDownloads => downloadedBy.length;
  bool get hasFiles => files.isNotEmpty;
  bool get hasLinks => links.isNotEmpty;
  
  String get displayAuthor => authorName ?? createdBy;
  
  // Get file types for display
  List<String> get fileTypes {
    return files.map((f) => f.mimeType.split('/').first).toSet().toList();
  }
  
  // Get total file size
  int get totalFileSize {
    return files.fold(0, (sum, file) => sum + file.fileSize);
  }
  
  // Format file size for display
  String get formattedFileSize {
    final bytes = totalFileSize;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}