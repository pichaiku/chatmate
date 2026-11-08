import 'package:uuid/uuid.dart';

enum MessageType {
  text,
  image,
  audio,
  video,
}

class Message {
  final int id;
  final String message_type;
  final String content;  
  final bool is_from_user;
  final DateTime created_at;

  Message({
    required this.id,
    required this.message_type,
    required this.content,
    required this.is_from_user,
    DateTime? created_at,
  }) : created_at = created_at ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: int.parse(json['id'].toString()),
      message_type: json['message_type'],
      content: json['content'],
      is_from_user: json['is_from_user'] == 1,
      created_at: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_type': message_type,
      'content': content,
      'is_from_user': is_from_user ? 1 : 0,
      'created_at': created_at.toIso8601String(),
    };
  }
} 