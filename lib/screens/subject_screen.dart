import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'abcd.dart';
import 'chapter_sets_screen.dart';

class SubjectScreen extends StatelessWidget {
  final String subjectName;
  final String stream;

  const SubjectScreen({
    super.key,
    required this.subjectName,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    if (subjectName.toUpperCase() == 'ABCD') {
      return const AbcdScreen();
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(subjectName),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _AdminSetsSection(subjectName: subjectName, stream: stream),
          ],
        ),
      ),
    );
  }
}

class _AdminSetsSection extends StatelessWidget {
  final String subjectName;
  final String stream;

  const _AdminSetsSection({
    required this.subjectName,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    final cardId = '${stream}__$subjectName'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final chaptersRef = FirebaseFirestore.instance
        .collection('set_cards')
        .doc(cardId)
        .collection('chapters')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chaptersRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (!snap.hasData) return const SizedBox.shrink();
        final chapterDocs = snap.data!.docs;
        if (chapterDocs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Practice Sets',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...chapterDocs.map((chapterDoc) {
              final chapterData = chapterDoc.data();
              final chapterEn = (chapterData['chapterEn'] ?? '').toString();
              final chapterHi = (chapterData['chapterHi'] ?? '').toString();
              final setsRef = chapterDoc.reference
                  .collection('sets')
                  .orderBy('setNumber', descending: false);

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: setsRef.snapshots(),
                builder: (context, setSnap) {
                  final setsCount = setSnap.data?.docs.length ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: setsCount == 0
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChapterSetsScreen(
                                    chapterTitle: chapterEn.isEmpty
                                        ? 'Chapter'
                                        : chapterEn,
                                    chapterHindiTitle: chapterHi,
                                    setsQuery: setsRef,
                                  ),
                                ),
                              );
                            },
                      title: Text(
                        chapterEn.isEmpty ? 'Chapter' : chapterEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: chapterHi.trim().isEmpty
                          ? null
                          : Text(
                              chapterHi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: Text(
                        '$setsCount sets',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: setsCount == 0
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}
