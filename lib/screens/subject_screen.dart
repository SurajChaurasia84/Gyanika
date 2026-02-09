import 'package:flutter/material.dart';

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
    final showWelcomeImage = subjectName.toUpperCase() == 'ABCD';
    final isAbcd = showWelcomeImage;
    const totalLevels = 5;
    const currentLevel = 1;
    const completedLevels = <int>{};
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(subjectName),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (showWelcomeImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 1920 / 480,
                child: Image.asset(
                  'assets/src/wl.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (isAbcd) ...[
            const SizedBox(height: 16),
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
              'Complete level to unlock next level!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            _LevelPath(
              totalLevels: totalLevels,
              currentLevel: currentLevel,
              completedLevels: completedLevels,
            ),
            const SizedBox(height: 18),
            if (currentLevel >= 1 && currentLevel <= totalLevels)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Start Level $currentLevel'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LevelBubble extends StatelessWidget {
  final int level;
  final bool isCompleted;
  final bool isUnlocked;
  final bool isCurrent;

  const _LevelBubble({
    required this.level,
    required this.isCompleted,
    required this.isUnlocked,
    required this.isCurrent,
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
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            // color: baseColor.withOpacity(0.18),
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
          child: Image.asset(
            'assets/src/A.png',
            width: 30,
            height: 30,
          ),
        ),
        if (isCompleted)
          const Positioned(
            right: -2,
            top: -2,
            child: Icon(Icons.check_circle, color: Colors.green, size: 20),
          ),
        if (!isUnlocked)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 12, color: Colors.white),
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

  const _LevelPath({
    required this.totalLevels,
    required this.currentLevel,
    required this.completedLevels,
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
        path.cubicTo(
          prevX,
          midY,
          x,
          midY,
          x,
          y,
        );
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
