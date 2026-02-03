// NOTE: Firebase structure + 3 add screens
// collections:
// questions/{postId}
// quizzes/{postId}
// polls/{postId}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ================= COMMON CATEGORY DROPDOWN =================
const List<String> kCategories = [
  'Mathematics',
    'Science',
    'Technology',
    'General Knowledge',
    'Computer',
    'Engineering',
    'Environment',
    'Social Science',
    'Logical Reasoning',
    'Other',
];

Map<String, dynamic> basePostData({
  required String type,
  required String content,
  required String category,
}) {
  final user = FirebaseAuth.instance.currentUser!;

  return {
    'type': type, // question | quiz | poll
    'content': content,
    'category': category,
    'uid': user.uid,
    'username': user.displayName ?? '',
    'likes': 0,
    'comments': 0,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

Future<void> incrementUserPostsCount() async {
  final user = FirebaseAuth.instance.currentUser!;
  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
    'posts': FieldValue.increment(1),
  });
}

// ================= ADD QUESTION SCREEN =================
class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _controller = TextEditingController();
  String? _category;
  bool loading = false;

  Future<void> submit() async {
    if (_controller.text.isEmpty || _category == null) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('questions').add(
          basePostData(
            type: 'question',
            content: _controller.text.trim(),
            category: _category!,
          ),
        );
    await incrementUserPostsCount();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask Question')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                hint: const Text('Category'),
                items: kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write your question...',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text('Post Question'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= ADD POLL SCREEN =================
class AddPollScreen extends StatefulWidget {
  const AddPollScreen({super.key});

  @override
  State<AddPollScreen> createState() => _AddPollScreenState();
}

class _AddPollScreenState extends State<AddPollScreen> {
  final questionCtrl = TextEditingController();
  final optionCtrls = List.generate(4, (_) => TextEditingController());
  String? _category;

  Future<void> submit() async {
    if (questionCtrl.text.isEmpty || _category == null) return;

    await FirebaseFirestore.instance.collection('polls').add({
      ...basePostData(
        type: 'poll',
        content: questionCtrl.text.trim(),
        category: _category!,
      ),
      'options': optionCtrls.map((e) => e.text).toList(),
      'votes': List.filled(4, 0),
      'answeredCount': 0,
    });
    await incrementUserPostsCount();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Poll')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              hint: const Text('Category'),
              items: kCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: questionCtrl,
              decoration: const InputDecoration(
                hintText: 'Poll question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(4, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: optionCtrls[i],
                  decoration: InputDecoration(
                    hintText: 'Option ${i + 1}',
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submit,
              child: const Text('Post Poll'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= ADD QUIZ SCREEN =================
class AddQuizScreen extends StatefulWidget {
  const AddQuizScreen({super.key});

  @override
  State<AddQuizScreen> createState() => _AddQuizScreenState();
}

class _AddQuizScreenState extends State<AddQuizScreen> {
  final questionCtrl = TextEditingController();
  final optionCtrls = List.generate(4, (_) => TextEditingController());
  int? correctIndex;
  String? _category;

  Future<void> submit() async {
    if (questionCtrl.text.isEmpty || correctIndex == null || _category == null)
      return;

    await FirebaseFirestore.instance.collection('quizzes').add({
      ...basePostData(
        type: 'quiz',
        content: questionCtrl.text.trim(),
        category: _category!,
      ),
      'options': optionCtrls.map((e) => e.text).toList(),
      'correctIndex': correctIndex,
      'attemptedCount': 0,
    });
    await incrementUserPostsCount();

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Quiz')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              hint: const Text('Category'),
              items: kCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: questionCtrl,
              decoration: const InputDecoration(
                hintText: 'Quiz question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(4, (i) {
              return RadioListTile<int>(
                value: i,
                groupValue: correctIndex,
                onChanged: (v) => setState(() => correctIndex = v),
                title: TextField(
                  controller: optionCtrls[i],
                  decoration: InputDecoration(
                    hintText: 'Option ${i + 1}',
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submit,
              child: const Text('Post Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
