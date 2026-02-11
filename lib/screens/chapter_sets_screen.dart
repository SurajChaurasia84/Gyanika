import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SetAttemptResult {
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int marks;
  final int timeTakenSeconds;
  final int submittedAtEpochMs;
  final List<int> selectedAnswers;

  const SetAttemptResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.marks,
    required this.timeTakenSeconds,
    required this.submittedAtEpochMs,
    required this.selectedAnswers,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'marks': marks,
      'timeTakenSeconds': timeTakenSeconds,
      'submittedAtEpochMs': submittedAtEpochMs,
      'selectedAnswers': selectedAnswers,
    };
  }

  static SetAttemptResult? fromRaw(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    return SetAttemptResult(
      totalQuestions: _asInt(data['totalQuestions']),
      correctAnswers: _asInt(data['correctAnswers']),
      wrongAnswers: _asInt(data['wrongAnswers']),
      marks: _asInt(data['marks']),
      timeTakenSeconds: _asInt(data['timeTakenSeconds']),
      submittedAtEpochMs: _asInt(data['submittedAtEpochMs']),
      selectedAnswers: List<int>.from(data['selectedAnswers'] as List? ?? const []),
    );
  }
}

class ChapterSetsScreen extends StatefulWidget {
  final String chapterTitle;
  final String chapterHindiTitle;
  final Query<Map<String, dynamic>> setsQuery;

  const ChapterSetsScreen({
    super.key,
    required this.chapterTitle,
    required this.chapterHindiTitle,
    required this.setsQuery,
  });

  @override
  State<ChapterSetsScreen> createState() => _ChapterSetsScreenState();
}

class _ChapterSetsScreenState extends State<ChapterSetsScreen> {
  Box? _attemptBox;
  String? _expandedSetId;

  @override
  void initState() {
    super.initState();
    _initAttemptBox();
  }

  Future<void> _initAttemptBox() async {
    final box = await Hive.openBox('progress');
    if (!mounted) return;
    setState(() => _attemptBox = box);
  }

  String _attemptKeyFor(DocumentReference<Map<String, dynamic>> setRef) {
    return 'set_attempt_${setRef.path}';
  }

  SetAttemptResult? _attemptFor(DocumentReference<Map<String, dynamic>> setRef) {
    final box = _attemptBox;
    if (box == null) return null;
    return SetAttemptResult.fromRaw(box.get(_attemptKeyFor(setRef)));
  }

  Future<void> _saveAttempt(
    DocumentReference<Map<String, dynamic>> setRef,
    SetAttemptResult result,
  ) async {
    final box = _attemptBox ?? await Hive.openBox('progress');
    await box.put(_attemptKeyFor(setRef), result.toMap());
    if (!mounted) return;
    setState(() => _attemptBox = box);
  }

  Future<List<QuestionItem>> _loadQuestionsForSet(
    DocumentReference<Map<String, dynamic>> setRef,
  ) async {
    final snap = await setRef
        .collection('questions')
        .orderBy('order', descending: false)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return QuestionItem(
        question: (data['question'] ?? '').toString(),
        options: List<String>.from(data['options'] as List? ?? const []),
        correctIndex: _asInt(data['correctIndex']),
        explanation: (data['explanation'] ?? '').toString(),
      );
    }).toList();
  }

  Future<void> _openTest(
    QueryDocumentSnapshot<Map<String, dynamic>> setDoc,
  ) async {
    final setData = setDoc.data();
    final setNo = _asInt(setData['setNumber']);
    final questions = await _loadQuestionsForSet(setDoc.reference);
    if (!mounted) return;

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions in this set yet')),
      );
      return;
    }

    final result = await Navigator.push<SetAttemptResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SetTestScreen(
          chapterTitle: widget.chapterTitle,
          setLabel: 'Set $setNo',
          questions: questions,
        ),
      ),
    );

    if (result != null) {
      await _saveAttempt(setDoc.reference, result);
    }
  }

  Future<void> _openAnalytics(
    QueryDocumentSnapshot<Map<String, dynamic>> setDoc,
    SetAttemptResult attempt,
  ) async {
    final setNo = _asInt(setDoc.data()['setNumber']);
    final questions = await _loadQuestionsForSet(setDoc.reference);
    if (!mounted) return;

    final wantsRetake =
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SetAnalyticsScreen(
              chapterTitle: widget.chapterTitle,
              setLabel: 'Set $setNo',
              attempt: attempt,
              questions: questions,
              allowRetake: true,
            ),
          ),
        ) ??
        false;

    if (wantsRetake && mounted) {
      await _openTest(setDoc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.chapterTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            if (widget.chapterHindiTitle.trim().isNotEmpty)
              Text(
                widget.chapterHindiTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.setsQuery.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No sets available',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final sets = snap.data!.docs;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: sets.map((setDoc) {
              final setData = setDoc.data();
              final setNo = _asInt(setData['setNumber']);
              final attemptedResult = _attemptFor(setDoc.reference);
              final isAttempted = attemptedResult != null;
              final isExpanded = _expandedSetId == setDoc.id;
              final createdText = _formatCreatedDate(setData['createdAt']);
              final qCount = _asInt(setData['questionCount']);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: isAttempted
                          ? () {
                              setState(() {
                                _expandedSetId = isExpanded ? null : setDoc.id;
                              });
                            }
                          : null,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Set $setNo • $qCount questions',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '$createdText • ${isAttempted ? 'Attempted' : 'Not attempted'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isAttempted && isExpanded)
                      Row(
                        children: [
                          TextButton(
                            onPressed: () =>
                                _openAnalytics(setDoc, attemptedResult),
                            child: const Text('View Analytics'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _openTest(setDoc),
                            child: const Text('Retake Test'),
                          ),
                        ],
                      ),
                    if (!isAttempted)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _openTest(setDoc),
                          child: const Text('Start Test'),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class SetTestScreen extends StatefulWidget {
  final String chapterTitle;
  final String setLabel;
  final List<QuestionItem> questions;

  const SetTestScreen({
    super.key,
    required this.chapterTitle,
    required this.setLabel,
    required this.questions,
  });

  @override
  State<SetTestScreen> createState() => _SetTestScreenState();
}

class _SetTestScreenState extends State<SetTestScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  bool _started = false;
  int _elapsedSeconds = 0;
  int _currentIndex = 0;
  late final List<int> _selectedAnswers;

  @override
  void initState() {
    super.initState();
    _selectedAnswers = List<int>.filled(widget.questions.length, -1);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _startTest() {
    setState(() => _started = true);
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
  }

  Future<void> _submit() async {
    _ticker?.cancel();
    _stopwatch.stop();

    int correct = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_selectedAnswers[i] == widget.questions[i].correctIndex) {
        correct++;
      }
    }
    final total = widget.questions.length;
    final wrong = total - correct;
    final result = SetAttemptResult(
      totalQuestions: total,
      correctAnswers: correct,
      wrongAnswers: wrong,
      marks: correct,
      timeTakenSeconds: _elapsedSeconds,
      submittedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      selectedAnswers: List<int>.from(_selectedAnswers),
    );

    final wantsRetake =
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SetAnalyticsScreen(
              chapterTitle: widget.chapterTitle,
              setLabel: widget.setLabel,
              attempt: result,
              questions: widget.questions,
              allowRetake: true,
            ),
          ),
        ) ??
        false;

    if (!mounted) return;

    if (wantsRetake) {
      setState(() {
        _elapsedSeconds = 0;
        _currentIndex = 0;
        _started = true;
        for (int i = 0; i < _selectedAnswers.length; i++) {
          _selectedAnswers[i] = -1;
        }
      });
      _stopwatch
        ..reset()
        ..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
      });
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    final isLast = _currentIndex == total - 1;
    final selectedValue = _selectedAnswers[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.setLabel),
      ),
      body: SafeArea(
        child: !_started
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chapterTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.questions.length} questions',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startTest,
                            child: const Text('Start Test'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1}/$total',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDuration(_elapsedSeconds),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (_currentIndex + 1) / total),
                  const SizedBox(height: 16),
                  Text(
                    widget.questions[_currentIndex].question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.questions[_currentIndex].options
                      .asMap()
                      .entries
                      .map((entry) {
                        final optionIndex = entry.key;
                        final optionText = entry.value;
                        return RadioListTile<int>(
                          dense: true,
                          value: optionIndex,
                          groupValue: selectedValue < 0 ? null : selectedValue,
                          title: Text(optionText),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(
                              () => _selectedAnswers[_currentIndex] = value,
                            );
                          },
                        );
                      }),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedValue < 0
                          ? null
                          : () {
                              if (isLast) {
                                _submit();
                              } else {
                                setState(() => _currentIndex++);
                              }
                            },
                      child: Text(isLast ? 'Submit' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class SetAnalyticsScreen extends StatelessWidget {
  final String chapterTitle;
  final String setLabel;
  final SetAttemptResult attempt;
  final List<QuestionItem> questions;
  final bool allowRetake;

  const SetAnalyticsScreen({
    super.key,
    required this.chapterTitle,
    required this.setLabel,
    required this.attempt,
    required this.questions,
    required this.allowRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          '$chapterTitle - $setLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attempted Date',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatAttemptedDate(attempt.submittedAtEpochMs),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Taken Time',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                _formatDuration(attempt.timeTakenSeconds),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.14),
                    border: Border.all(color: Colors.green.withOpacity(0.45)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Correct',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${attempt.correctAnswers}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.14),
                    border: Border.all(color: Colors.red.withOpacity(0.45)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Wrong',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${attempt.wrongAnswers}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: allowRetake ? () => Navigator.pop(context, true) : null,
              child: const Text('Retake Test'),
            ),
          ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            final selectedIndex = index < attempt.selectedAnswers.length
                ? attempt.selectedAnswers[index]
                : -1;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Q${index + 1}. ${q.question}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...q.options.asMap().entries.map((optEntry) {
                    final optIndex = optEntry.key;
                    final optText = optEntry.value;
                    final isCorrect = optIndex == q.correctIndex;
                    final isSelected = optIndex == selectedIndex;
                    final wrongSelected = isSelected && !isCorrect;
                    final correctSelected = isSelected && isCorrect;
                    final tileBg = isCorrect
                        ? Colors.green.withOpacity(0.14)
                        : wrongSelected
                        ? Colors.red.withOpacity(0.14)
                        : Colors.transparent;
                    final borderColor = isCorrect
                        ? Colors.green.withOpacity(0.45)
                        : wrongSelected
                        ? Colors.red.withOpacity(0.45)
                        : Theme.of(context).colorScheme.outline.withOpacity(0.25);
                    final textColor = isCorrect
                        ? Colors.green.shade800
                        : wrongSelected
                        ? Colors.red.shade800
                        : Theme.of(context).colorScheme.onSurface;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: correctSelected
                                ? Colors.green
                                : wrongSelected
                                ? Colors.red
                                : Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              optText,
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                fontWeight: (isCorrect || isSelected)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (q.explanation.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Explanation: ${q.explanation}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class QuestionItem {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuestionItem({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  String get correctOptionText {
    if (correctIndex < 0 || correctIndex >= options.length) return '';
    return options[correctIndex];
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _formatCreatedDate(dynamic raw) {
  DateTime? dt;
  if (raw is Timestamp) dt = raw.toDate();
  if (raw is DateTime) dt = raw;
  if (dt == null) return 'date unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  return '$day $month ${dt.year}';
}

String _formatDuration(int seconds) {
  final mins = (seconds ~/ 60).toString().padLeft(2, '0');
  final secs = (seconds % 60).toString().padLeft(2, '0');
  return '$mins:$secs';
}

String _formatAttemptedDate(int epochMs) {
  if (epochMs <= 0) return 'date unavailable';
  final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day $month ${dt.year}, $hour:$minute $amPm';
}
