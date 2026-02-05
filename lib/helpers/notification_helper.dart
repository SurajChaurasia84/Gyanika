import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationHelper {
  static CollectionReference<Map<String, dynamic>> _activityRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('activities');
  }

  static Future<void> addActivity({
    required String targetUid,
    required String type,
    required String title,
    String? actorUid,
    String? actorName,
    String? postId,
    String? postType,
    String? content,
    Map<String, dynamic>? extra,
  }) async {
    final uid = actorUid ?? FirebaseAuth.instance.currentUser?.uid;
    final data = <String, dynamic>{
      'type': type,
      'title': title,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    if (uid != null) data['actorUid'] = uid;
    if (actorName != null && actorName.trim().isNotEmpty) {
      data['actorName'] = actorName.trim();
    }
    if (postId != null) data['postId'] = postId;
    if (postType != null) data['postType'] = postType;
    if (content != null && content.trim().isNotEmpty) {
      data['content'] = content.trim();
    }
    if (extra != null && extra.isNotEmpty) data.addAll(extra);

    await _activityRef(targetUid).add(data);
  }

  static Future<void> addActivitiesForUsers({
    required List<String> targetUids,
    required String type,
    required String title,
    String? actorUid,
    String? actorName,
    String? postId,
    String? postType,
    String? content,
    Map<String, dynamic>? extra,
  }) async {
    if (targetUids.isEmpty) return;

    final uid = actorUid ?? FirebaseAuth.instance.currentUser?.uid;
    final data = <String, dynamic>{
      'type': type,
      'title': title,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    if (uid != null) data['actorUid'] = uid;
    if (actorName != null && actorName.trim().isNotEmpty) {
      data['actorName'] = actorName.trim();
    }
    if (postId != null) data['postId'] = postId;
    if (postType != null) data['postType'] = postType;
    if (content != null && content.trim().isNotEmpty) {
      data['content'] = content.trim();
    }
    if (extra != null && extra.isNotEmpty) data.addAll(extra);

    final batch = FirebaseFirestore.instance.batch();
    for (final targetUid in targetUids) {
      final doc = _activityRef(targetUid).doc();
      batch.set(doc, data);
    }
    await batch.commit();
  }
}
