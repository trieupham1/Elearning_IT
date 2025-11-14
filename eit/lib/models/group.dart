class Group {
  final String id;
  final String name;
  final String courseId;
  final List<Member> members;
  final String createdBy;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Group({
    required this.id,
    required this.name,
    required this.courseId,
    required this.members,
    required this.createdBy,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      courseId: json['courseId'] ?? '',
      members:
          (json['members'] as List<dynamic>?)
              ?.map(
                (m) => m is String
                    ? Member(id: m, fullName: '', email: '', studentId: '')
                    : Member.fromJson(m),
              )
              .toList() ??
          [],
      createdBy: json['createdBy'] ?? '',
      description: json['description'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'courseId': courseId,
      'members': members.map((m) => m.id).toList(),
      'createdBy': createdBy,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class Member {
  final String id;
  final String fullName;
  final String email;
  final String studentId;

  Member({
    required this.id,
    required this.fullName,
    required this.email,
    required this.studentId,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    // Construct fullName from firstName and lastName if available
    String fullName = json['fullName']?.toString() ?? '';

    // If fullName is empty but we have firstName/lastName, construct it
    if (fullName.isEmpty || fullName == 'Unknown User') {
      final firstName = json['firstName']?.toString() ?? '';
      final lastName = json['lastName']?.toString() ?? '';
      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        fullName = '$firstName $lastName'.trim();
      } else {
        fullName = json['username']?.toString() ?? 'Unknown User';
      }
    }

    return Member(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: fullName,
      email: json['email'] ?? '',
      studentId: json['studentId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'studentId': studentId,
    };
  }
}
