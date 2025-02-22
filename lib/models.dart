// models.dart

class User {
  final String school;
  final String className;
  final String studentId;
  final String name;
  final String? salt;
  final String password;

  User({
    required this.school,
    required this.className,
    required this.studentId,
    required this.name,
    required this.salt,
    required this.password,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      school: json['school'],
      className: json['class_name'],
      studentId: json['student_id'],
      name: json['name'],
      salt: json['salt'] ?? '', // 处理 null
      password: json['password'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school': school,
      'class_name': className,
      'student_id': studentId,
      'name': name,
      'salt': salt,
      'password': password,
    };
  }
}

class Letter {
  final String? id;
  final String? senderId;
  final String receiverName;
  final String receiverClass;
  final String content;
  final String? sendTime;
  final String isAnonymous;
  final String mySchool;
  final String targetSchool;
  final String? senderName;
  final bool isRead; // 用于标记已读/未读

  Letter({
    this.id,
    this.senderId,
    required this.receiverName,
    required this.receiverClass,
    required this.content,
    this.sendTime,
    required this.isAnonymous,
    required this.mySchool,
    required this.targetSchool,
    this.senderName,
    this.isRead = false, // 默认未读
  });
  
  factory Letter.fromJson(Map<String, dynamic> json) {
    return Letter(
      id: json['id'],
      senderId: json['sender_id'],
      receiverName: json['receiver_name'] ?? '未知收件人', // 处理 null
      receiverClass: json['receiver_class'] ?? '未知班级', // 处理 null
      content: json['content'] ?? '',          // 处理 null
      sendTime: json['send_time'],
      isAnonymous: json['is_anonymous'] ?? 'false',   // 处理 null, 假设默认不是匿名
      mySchool: json['my_school'] ?? '未知学校',        // 处理 null
      targetSchool: json['target_school'] ?? '未知学校',    // 处理 null
      senderName: json['sender_name'] ?? '未知发件人',    // 处理 null
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiver_name': receiverName,
      'receiver_class': receiverClass,
      'content': content,
      'is_anonymous': isAnonymous,
      'my_school': mySchool,
      'target_school': targetSchool,
      'sender_name': senderName,
      'is_read': isRead,
    };
  }
}