import 'package:flutter/widgets.dart';

/// The signed-in person. Identity comes from phone OTP; the rest is
/// collected during setup.
@immutable
class Account {
  const Account({
    required this.uid,
    required this.phone,
    required this.createdAt,
    this.name = '',
    this.email = '',
    this.onboarded = false,
  });

  final String uid;

  /// E.164, e.g. +919876543210.
  final String phone;
  final String name;
  final String email;
  final bool onboarded;
  final DateTime createdAt;

  bool get hasProfile => name.trim().isNotEmpty;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  Account copyWith({String? name, String? email, bool? onboarded}) => Account(
    uid: uid,
    phone: phone,
    createdAt: createdAt,
    name: name ?? this.name,
    email: email ?? this.email,
    onboarded: onboarded ?? this.onboarded,
  );

  Map<String, Object?> toJson() => {
    'uid': uid,
    'phone': phone,
    'name': name,
    'email': email,
    'onboarded': onboarded,
    'createdAt': createdAt.toIso8601String(),
  };

  static Account fromJson(Map<String, Object?> j) => Account(
    uid: j['uid'] as String,
    phone: j['phone'] as String,
    name: (j['name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    onboarded: (j['onboarded'] as bool?) ?? false,
    createdAt:
        DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? DateTime.now(),
  );
}

enum NoticeKind { welcome, tip, streak, report, pro }

@immutable
class AppNotice {
  const AppNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final NoticeKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  AppNotice markRead() => AppNotice(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    read: true,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  static AppNotice fromJson(Map<String, Object?> j) => AppNotice(
    id: j['id'] as String,
    kind: NoticeKind.values.asNameMap()[j['kind']] ?? NoticeKind.tip,
    title: j['title'] as String,
    body: j['body'] as String,
    createdAt:
        DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? DateTime.now(),
    read: (j['read'] as bool?) ?? false,
  );
}

@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  final String id;
  final String label;
  final int hour;
  final int minute;
  final bool enabled;

  Reminder copyWith({int? hour, int? minute, bool? enabled}) => Reminder(
    id: id,
    label: label,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    enabled: enabled ?? this.enabled,
  );

  static const defaults = [
    Reminder(id: 'breakfast', label: 'Breakfast', hour: 8, minute: 30),
    Reminder(id: 'lunch', label: 'Lunch', hour: 13, minute: 0),
    Reminder(id: 'dinner', label: 'Dinner', hour: 20, minute: 0),
    Reminder(
      id: 'weigh-in',
      label: 'Weekly weigh-in',
      hour: 7,
      minute: 30,
      enabled: false,
    ),
  ];

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
  };

  static Reminder fromJson(Map<String, Object?> j) => Reminder(
    id: j['id'] as String,
    label: j['label'] as String,
    hour: (j['hour'] as num).toInt(),
    minute: (j['minute'] as num).toInt(),
    enabled: (j['enabled'] as bool?) ?? true,
  );
}
