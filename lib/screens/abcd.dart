import 'package:flutter/material.dart';

class AbcdScreen extends StatelessWidget {
  const AbcdScreen({super.key});

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

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('ABCD'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
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
          ),
        ),
      ),
    );
  }
}
