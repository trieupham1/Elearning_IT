class Course {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? instructorId;
  final String? instructorName;
  final String? semesterId;
  final String? semesterName;
  final List<String> students;
  final int? sessions;
  final String? color;
  final String? image;
  final int studentCount;

  Course({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.instructorId,
    this.instructorName,
    this.semesterId,
    this.semesterName,
    this.students = const [],
    this.sessions,
    this.color,
    this.image,
    this.studentCount = 0,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      instructorId: json['instructor'] is Map
          ? json['instructor']['_id']?.toString()
          : json['instructor']?.toString(),
      instructorName:
          json['instructorName'] ??
          (json['instructor'] is Map
              ? '${json['instructor']['firstName'] ?? ''} ${json['instructor']['lastName'] ?? ''}'
                    .trim()
              : null),
      semesterId: json['semester'] is Map
          ? json['semester']['_id']?.toString()
          : json['semester']?.toString(),
      semesterName: json['semester'] is Map ? json['semester']['name'] : null,
      students: json['students'] is List
          ? List<String>.from(
              json['students'].map(
                (s) => s is Map ? s['_id']?.toString() ?? '' : s.toString(),
              ),
            )
          : [],
      sessions: json['sessions'],
      color: json['color'] ?? '#1976D2',
      image: json['image'],
      studentCount:
          json['studentCount'] ??
          (json['students'] is List ? json['students'].length : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'instructor': instructorId,
      'semester': semesterId,
      'students': students,
      'sessions': sessions,
      'color': color,
      'image': image,
    };
  }

  // Add getter for instructor
  String get instructor => instructorName ?? 'Unknown';
}
