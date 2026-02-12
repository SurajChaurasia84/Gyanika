import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'chapter_sets_screen.dart';

class SubjectScreen extends StatefulWidget {
  final String subjectName;
  final String stream;

  const SubjectScreen({
    super.key,
    required this.subjectName,
    required this.stream,
  });

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  static const totalLevels = 5;
  int currentLevel = 1;
  final Set<int> completedLevels = <int>{};
  Box? _progressBox;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  String get _progressKeyPrefix =>
      '${widget.subjectName}_${widget.stream}'.toLowerCase();

  Future<void> _loadProgress() async {
    final box = await Hive.openBox('progress');
    _progressBox = box;
    final storedCompleted =
        box.get('completed_$_progressKeyPrefix', defaultValue: <int>[]);
    final storedCurrent =
        box.get('current_$_progressKeyPrefix', defaultValue: 1);

    if (!mounted) return;
    setState(() {
      completedLevels
        ..clear()
        ..addAll(List<int>.from(storedCompleted as List));
      currentLevel = (storedCurrent as int).clamp(1, totalLevels);
    });
  }

  Future<void> _saveProgress() async {
    final box = _progressBox ?? await Hive.openBox('progress');
    await box.put('completed_$_progressKeyPrefix', completedLevels.toList());
    await box.put('current_$_progressKeyPrefix', currentLevel);
  }

  @override
  Widget build(BuildContext context) {
    final isAbcd = widget.subjectName.toUpperCase() == 'ABCD';
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.subjectName),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (isAbcd) ...[
              Text(
                'Choose Your Level',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete tasks to unlock all levels!',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _LevelPath(
                totalLevels: totalLevels,
                currentLevel: currentLevel,
                completedLevels: completedLevels,
                onCompleteLevel: (level) {
                  setState(() {
                    completedLevels.add(level);
                    final nextLevel = level + 1;
                    if (nextLevel <= totalLevels) {
                      currentLevel = nextLevel;
                    }
                  });
                  _saveProgress();
                },
              ),
              const SizedBox(height: 18),
            ],
            _AdminSetsSection(
              subjectName: widget.subjectName,
              stream: widget.stream,
            ),
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

class _LevelBubble extends StatelessWidget {
  final int level;
  final bool isCompleted;
  final bool isUnlocked;
  final bool isCurrent;
  final String iconPath;
  final VoidCallback? onTap;

  const _LevelBubble({
    required this.level,
    required this.isCompleted,
    required this.isUnlocked,
    required this.isCurrent,
    required this.iconPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isCompleted
        ? Colors.green
        : isCurrent
        ? Colors.orange
        : isUnlocked
        ? Colors.blue
        : Colors.grey;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: baseColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(iconPath, width: 30, height: 30),
            ),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: (isUnlocked || isCompleted)
                  ? Colors.green
                  : Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted
                  ? Icons.check
                  : isUnlocked
                  ? Icons.lock_open
                  : Icons.lock,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelPath extends StatelessWidget {
  final int totalLevels;
  final int currentLevel;
  final Set<int> completedLevels;
  final ValueChanged<int> onCompleteLevel;

  const _LevelPath({
    required this.totalLevels,
    required this.currentLevel,
    required this.completedLevels,
    required this.onCompleteLevel,
  });

  @override
  Widget build(BuildContext context) {
    const itemHeight = 110.0;
    const bubbleSize = 64.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final leftX = bubbleSize / 2 + 12;
        final rightX = width - (bubbleSize / 2 + 12);

        return SizedBox(
          height: totalLevels * itemHeight,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(width, totalLevels * itemHeight),
                painter: _SnakePathPainter(
                  totalLevels: totalLevels,
                  itemHeight: itemHeight,
                  leftX: leftX,
                  rightX: rightX,
                ),
              ),
              ...List.generate(totalLevels, (i) {
                final level = i + 1;
                final isCompleted = completedLevels.contains(level);
                final isUnlocked =
                    level == 1 || isCompleted || level == currentLevel;
                final isCurrent = level == currentLevel;
                final alignLeft = i.isEven;
                final x = alignLeft ? leftX : rightX;
                final y = (i * itemHeight) + (itemHeight / 2);
                final iconPath = _levelIconFor(level);

                return Positioned(
                  left: x - (bubbleSize / 2),
                  top: y - (bubbleSize / 2),
                  child: Column(
                    children: [
                      _LevelBubble(
                        level: level,
                        isCompleted: isCompleted,
                        isUnlocked: isUnlocked,
                        isCurrent: isCurrent,
                        iconPath: iconPath,
                        onTap: () async {
                          if (!isUnlocked) return;
                          final completed = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LevelDetailScreen(level: level),
                            ),
                          );
                          if (completed == true) {
                            onCompleteLevel(level);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Level $level',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

String _levelIconFor(int level) {
  const icons = [
    'assets/src/start.png',
    'assets/src/B.png',
    'assets/src/C.png',
    'assets/src/D.png',
    'assets/src/finish.png',
  ];
  final index = (level - 1) % icons.length;
  return icons[index];
}

class _SnakePathPainter extends CustomPainter {
  final int totalLevels;
  final double itemHeight;
  final double leftX;
  final double rightX;

  _SnakePathPainter({
    required this.totalLevels,
    required this.itemHeight,
    required this.leftX,
    required this.rightX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.35)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < totalLevels; i++) {
      final y = (i * itemHeight) + (itemHeight / 2);
      final isLeft = i.isEven;
      final x = isLeft ? leftX : rightX;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevY = ((i - 1) * itemHeight) + (itemHeight / 2);
        final prevX = (i - 1).isEven ? leftX : rightX;
        final midY = (prevY + y) / 2;
        path.cubicTo(prevX, midY, x, midY, x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LevelDetailScreen extends StatelessWidget {
  final int level;

  const LevelDetailScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final isLevelOne = level == 1;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Level $level'),
        actions: [
          TextButton(
            onPressed: () async {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Level Completed'),
                  content: const Text('Next level unlocked.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              Navigator.of(context).pop(true);
            },
            child: const Text(
              'Complete',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: isLevelOne
                  ? _LevelOneGrid()
                  : Center(
                      child: Text(
                        'Level $level',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelOneGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      'assets/src/A.png',
      'assets/src/B.png',
      'assets/src/C.png',
      'assets/src/D.png',
      'assets/src/E.png',
      'assets/src/F.png',
      'assets/src/G.png',
      'assets/src/H.png',
      'assets/src/I.png',
      'assets/src/J.png',
      'assets/src/K.png',
      'assets/src/L.png',
      'assets/src/M.png',
      'assets/src/N.png',
      'assets/src/O.png',
      'assets/src/P.png',
      'assets/src/Q.png',
      'assets/src/R.png',
      'assets/src/S.png',
      'assets/src/T.png',
      'assets/src/U.png',
      'assets/src/V.png',
      'assets/src/W.png',
      'assets/src/X.png',
      'assets/src/Y.png',
      'assets/src/Z.png',
    ];
    return GridView.builder(
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Image.asset(
            items[index],
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
