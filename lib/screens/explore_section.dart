import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'abcd.dart';
import 'subject_screen.dart';

class ExploreSection extends StatefulWidget {
  const ExploreSection({super.key});

  @override
  State<ExploreSection> createState() => _ExploreSectionState();
}

class _ExploreSectionState extends State<ExploreSection> {
  bool isSearching = false;
  final searchCtrl = TextEditingController();
  final Set<String> expandedSections = {};

  final Map<String, List<String>> streams = {
    'Class 9-10th': [
      'Hindi',
      'English',
      'Mathematics',
      'Science',
      'Social Science',
    ],
    'Class 11-12th': [
      'Hindi',
      'English',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
    ],
    'JEE': ['Mathematics', 'Physics', 'Chemistry'],
    'NEET': ['Botany', 'Zoology', 'Physics', 'Chemistry'],
    'CUET': ['Language', 'Mathematics', 'Physics', 'Chemistry'],
    'College': ['B.Tech', 'B.Sc', 'BCA', 'BA'],
    'GATE': [
      'Computer Science & IT',
      'Mechanical Engineering',
      'Electrical Engineering',
      'Electronics & Communication',
      'Civil Engineering',
    ],
    'SSC': [
      'Reasoning',
      'Quantitative Aptitude',
      'General Awareness',
      'English Comprehension',
    ],
  };

  Map<String, List<String>> get filteredStreams {
    if (!isSearching || searchCtrl.text.isEmpty) return streams;

    final q = searchCtrl.text.toLowerCase();
    final Map<String, List<String>> result = {};

    streams.forEach((section, subjects) {
      final matched = subjects
          .where((s) => s.toLowerCase().contains(q))
          .toList();
      if (matched.isNotEmpty) result[section] = matched;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle
                .light // dark theme → white icons
          : SystemUiOverlayStyle.dark, // light theme → dark icons
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: isSearching
              ? TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search subjects',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                )
              : const Text('Library'),
          actions: [
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  isSearching = !isSearching;
                  searchCtrl.clear();
                });
              },
            ),
          ],
        ),
        body: _exploreView(),
      ),
    );
  }

  Widget _exploreView() {
    final data = filteredStreams;
    final children = <Widget>[
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AbcdScreen(),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 1920 / 480,
            child: Image.asset('assets/src/wl.png', fit: BoxFit.cover),
          ),
        ),
      ),
      const SizedBox(height: 14),
    ];
    children.addAll(
      data.entries.map((entry) {
        final subjects = entry.value;
        final showViewAll = subjects.length > 4;
        final isExpanded = expandedSections.contains(entry.key);

        final visible = showViewAll && !isSearching && !isExpanded
            ? subjects.take(4).toList()
            : subjects;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(.6),
                  ),
                ),
                if (showViewAll && !isSearching)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (expandedSections.contains(entry.key)) {
                          expandedSections.remove(entry.key);
                        } else {
                          expandedSections.add(entry.key);
                        }
                      });
                    },
                    child: Text(
                      expandedSections.contains(entry.key)
                          ? 'View less'
                          : 'View all',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
              ),
              itemBuilder: (_, i) =>
                  _SubjectCard(title: visible[i], stream: entry.key),
            ),
            if (entry.key != data.keys.last) const SizedBox(height: 12),
          ],
        );
      }),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: children,
    );
  }
}

class SubjectConfig {
  final Color color;
  final String image;
  const SubjectConfig({required this.color, required this.image});
}

final Map<String, SubjectConfig> subjectConfigs = {
  // Languages
  'Hindi': SubjectConfig(
    color: Color(0xFF42A5F5),
    image: 'assets/src/hindi.png',
  ),
  'English': SubjectConfig(
    color: Color(0xFFFF7043),
    image: 'assets/src/english.png',
  ),
  'Maths': SubjectConfig(
    color: Color(0xFFAB47BC),
    image: 'assets/src/maths.png',
  ),
  // Core Subjects
  'Mathematics': SubjectConfig(
    color: Color(0xFF9C5A2E),
    image: 'assets/src/function.png',
  ),
  'Science': SubjectConfig(
    color: Color(0xFF26A69A),
    image: 'assets/src/science.png',
  ),
  'Physics': SubjectConfig(
    color: Color(0xFFFF8A00),
    image: 'assets/src/physics.png',
  ),
  'Chemistry': SubjectConfig(
    color: Color(0xFF3B6EF6),
    image: 'assets/src/chemistry.png',
  ),
  'Biology': SubjectConfig(
    color: Color(0xFF43A047),
    image: 'assets/src/biology.png',
  ),
  'Botany': SubjectConfig(
    color: Color(0xFF1FA971),
    image: 'assets/src/botany.png',
  ),
  'Zoology': SubjectConfig(
    color: Color(0xFF9C5A2E),
    image: 'assets/src/biology.png',
  ),

  // Social Science
  'Social Science': SubjectConfig(
    color: Color(0xFF7E57C2),
    image: 'assets/src/evs.png',
  ),

  'B.Tech': SubjectConfig(
    color: Color(0xFFEC407A),
    image: 'assets/src/certificate.png',
  ),
  'B.Sc': SubjectConfig(
    color: Color(0xFF5C6BC0),
    image: 'assets/src/certificate.png',
  ),
  'BCA': SubjectConfig(
    color: Color(0xFF26C6DA),
    image: 'assets/src/certificate.png',
  ),
  'BA': SubjectConfig(
    color: Color(0xFFFFB300),
    image: 'assets/src/certificate.png',
  ),
  'Language': SubjectConfig(
    color: Color(0xFF8BC34A),
    image: 'assets/src/language.png',
  ),

  // Competitive Exams
  'English Comprehension': SubjectConfig(
    color: Color(0xFF78909C),
    image: 'assets/src/english.png',
  ),
  'Quantitative Aptitude': SubjectConfig(
    color: Color(0xFF6D4C41),
    image: 'assets/src/function.png',
  ),
  'General Awareness': SubjectConfig(
    color: Color(0xFF7CB342),
    image: 'assets/src/gk.png',
  ),
  'Reasoning': SubjectConfig(
    color: Color(0xFFD84315),
    image: 'assets/src/reasoning.png',
  ),

  // Computer / Engineering
  'Computer Science & IT': SubjectConfig(
    color: Color(0xFF546E7A),
    image: 'assets/src/cse.png',
  ),
  'Mechanical Engineering': SubjectConfig(
    color: Color(0xFF00897B),
    image: 'assets/src/me.png',
  ),
  'Civil Engineering': SubjectConfig(
    color: Color(0xFFEC407A),
    image: 'assets/src/civil.png',
  ),
  'Electrical Engineering': SubjectConfig(
    color: Color(0xFFFFB300),
    image: 'assets/src/electrical.png',
  ),
  'Electronics & Communication': SubjectConfig(
    color: Color(0xFF42A5F5),
    image: 'assets/src/electronics.png',
  ),
};

class _SubjectCard extends StatelessWidget {
  final String title;
  final String stream; // JEE / NEET / SSC etc

  const _SubjectCard({required this.title, required this.stream});

  @override
  Widget build(BuildContext context) {
    final config = subjectConfigs[title];
    final bg = config?.color ?? Colors.grey.shade600;
    final image = config?.image ?? 'assets/src/icon.png';

    return InkWell(
      borderRadius: BorderRadius.circular(14),

      /// 🔥 TAP LOGIC
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SubjectScreen(subjectName: title, stream: stream),
          ),
        );
      },

      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                    colors: [
                      Colors.white.withOpacity(.18),
                      Colors.white.withOpacity(.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -8,
              bottom: -8,
              child: Opacity(
                opacity: .18,
                child: Image.asset(image, width: 72, height: 72),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collectionGroup('sets')
                        .where('stream', isEqualTo: stream)
                        .where('subject', isEqualTo: title)
                        .snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final totalQuestions = docs.fold<int>(0, (acc, doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? const {};
                        final q = data['questionCount'];
                        if (q is int) return acc + q;
                        if (q is num) return acc + q.toInt();
                        if (q is String) return acc + (int.tryParse(q) ?? 0);
                        return acc;
                      });
                      return Text(
                        '$totalQuestions questions',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
