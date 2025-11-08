/// Model for announcement tracking analytics
/// Used by instructor tracking dashboard
class AnnouncementTracking {
  final String announcementId;
  final String title;
  final DateTime createdAt;
  final ViewStatistics viewStats;
  final DownloadStatistics downloadStats;
  final Map<String, FileStatistics> fileStats;

  AnnouncementTracking({
    required this.announcementId,
    required this.title,
    required this.createdAt,
    required this.viewStats,
    required this.downloadStats,
    required this.fileStats,
  });

  factory AnnouncementTracking.fromJson(Map<String, dynamic> json) {
    return AnnouncementTracking(
      announcementId: json['announcementId']?.toString() ?? '',
      title: json['title'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      viewStats: ViewStatistics.fromJson(json['viewStats'] ?? {}),
      downloadStats: DownloadStatistics.fromJson(json['downloadStats'] ?? {}),
      fileStats: json['fileStats'] != null
          ? (json['fileStats'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, FileStatistics.fromJson(value)),
            )
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'announcementId': announcementId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'viewStats': viewStats.toJson(),
      'downloadStats': downloadStats.toJson(),
      'fileStats': fileStats.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

/// View statistics
class ViewStatistics {
  final int totalViews;
  final int uniqueViewers;
  final List<ViewerInfo> viewers;

  ViewStatistics({
    required this.totalViews,
    required this.uniqueViewers,
    required this.viewers,
  });

  factory ViewStatistics.fromJson(Map<String, dynamic> json) {
    return ViewStatistics(
      totalViews: json['totalViews'] ?? 0,
      uniqueViewers: json['uniqueViewers'] ?? 0,
      viewers: json['viewers'] != null
          ? List<ViewerInfo>.from(
              (json['viewers'] as List).map((v) => ViewerInfo.fromJson(v)),
            )
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalViews': totalViews,
      'uniqueViewers': uniqueViewers,
      'viewers': viewers.map((v) => v.toJson()).toList(),
    };
  }

  double get viewRate {
    if (uniqueViewers == 0) return 0.0;
    return totalViews / uniqueViewers;
  }
}

/// Download statistics
class DownloadStatistics {
  final int totalDownloads;
  final int uniqueDownloaders;
  final List<DownloadInfo> downloads;

  DownloadStatistics({
    required this.totalDownloads,
    required this.uniqueDownloaders,
    required this.downloads,
  });

  factory DownloadStatistics.fromJson(Map<String, dynamic> json) {
    return DownloadStatistics(
      totalDownloads: json['totalDownloads'] ?? 0,
      uniqueDownloaders: json['uniqueDownloaders'] ?? 0,
      downloads: json['downloads'] != null
          ? List<DownloadInfo>.from(
              (json['downloads'] as List).map((d) => DownloadInfo.fromJson(d)),
            )
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDownloads': totalDownloads,
      'uniqueDownloaders': uniqueDownloaders,
      'downloads': downloads.map((d) => d.toJson()).toList(),
    };
  }

  double get downloadRate {
    if (uniqueDownloaders == 0) return 0.0;
    return totalDownloads / uniqueDownloaders;
  }
}

/// Individual viewer information
class ViewerInfo {
  final String userId;
  final String fullName;
  final String? email;
  final String? studentId;
  final DateTime viewedAt;

  ViewerInfo({
    required this.userId,
    required this.fullName,
    this.email,
    this.studentId,
    required this.viewedAt,
  });

  factory ViewerInfo.fromJson(Map<String, dynamic> json) {
    return ViewerInfo(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] ?? 'Unknown',
      email: json['email'],
      studentId: json['studentId'],
      viewedAt: json['viewedAt'] != null
          ? DateTime.parse(json['viewedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'studentId': studentId,
      'viewedAt': viewedAt.toIso8601String(),
    };
  }

  String get displayName =>
      studentId != null ? '$fullName ($studentId)' : fullName;
}

/// Individual download information
class DownloadInfo {
  final String userId;
  final String fullName;
  final String? email;
  final String? studentId;
  final String fileName;
  final DateTime downloadedAt;

  DownloadInfo({
    required this.userId,
    required this.fullName,
    this.email,
    this.studentId,
    required this.fileName,
    required this.downloadedAt,
  });

  factory DownloadInfo.fromJson(Map<String, dynamic> json) {
    return DownloadInfo(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] ?? 'Unknown',
      email: json['email'],
      studentId: json['studentId'],
      fileName: json['fileName'] ?? '',
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.parse(json['downloadedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'studentId': studentId,
      'fileName': fileName,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  String get displayName =>
      studentId != null ? '$fullName ($studentId)' : fullName;
}

/// File-specific statistics
class FileStatistics {
  final int totalDownloads;
  final int uniqueDownloaders;

  FileStatistics({
    required this.totalDownloads,
    required this.uniqueDownloaders,
  });

  factory FileStatistics.fromJson(Map<String, dynamic> json) {
    return FileStatistics(
      totalDownloads: json['totalDownloads'] ?? 0,
      uniqueDownloaders: json['uniqueDownloaders'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDownloads': totalDownloads,
      'uniqueDownloaders': uniqueDownloaders,
    };
  }

  double get downloadRate {
    if (uniqueDownloaders == 0) return 0.0;
    return totalDownloads / uniqueDownloaders;
  }
}
