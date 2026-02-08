import 'package:flutter/material.dart';

class SubjectFeedScreen extends StatelessWidget {
  final String subjectName;
  final String stream;

  const SubjectFeedScreen({
    super.key,
    required this.subjectName,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subjectName),
      ),
    );
  }
}
