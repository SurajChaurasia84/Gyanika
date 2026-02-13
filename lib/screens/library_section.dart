import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'profile_screen.dart';
import 'package:gyanika/helpers/notification_helper.dart';

Future<String> _currentUserLabel() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return 'Someone';
  }
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  final data = snap.data() ?? {};
  final name = (data['name'] ?? '').toString().trim();
  if (name.isNotEmpty) {
    return name;
  }
  final username = (data['username'] ?? '').toString().trim();
  if (username.isNotEmpty) {
    return username;
  }
  return 'Someone';
}

class LibrarySection extends StatefulWidget {
  const LibrarySection({super.key});

  @override
  State<LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends State<LibrarySection> {
  String _filter = 'All';
  bool _showChips = true;
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  static const int _pageSize = 10;
  bool _loading = false;
  bool _hasMoreQuestions = true;
  bool _hasMorePolls = true;
  bool _hasMoreQuizzes = true;
  DocumentSnapshot? _lastQuestion;
  DocumentSnapshot? _lastPoll;
  DocumentSnapshot? _lastQuiz;
  final List<QueryDocumentSnapshot> _questions = [];
  final List<QueryDocumentSnapshot> _polls = [];
  final List<QueryDocumentSnapshot> _quizzes = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search username...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Explore'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching && _searchCtrl.text.trim().isNotEmpty)
            _UserSearchSuggestions(query: _searchCtrl.text.trim()),
          if (!_isSearching)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _showChips
                  ? Column(
                      children: [
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All',
                                selected: _filter == 'All',
                                onTap: () => _setFilter('All'),
                              ),
                              _FilterChip(
                                label: 'Questions',
                                selected: _filter == 'Questions',
                                onTap: () => _setFilter('Questions'),
                              ),
                              _FilterChip(
                                label: 'Quizzes',
                                selected: _filter == 'Quizzes',
                                onTap: () => _setFilter('Quizzes'),
                              ),
                              _FilterChip(
                                label: 'Polls',
                                selected: _filter == 'Polls',
                                onTap: () => _setFilter('Polls'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          if (!_isSearching)
            Expanded(
              child: _buildFeedList(),
            ),
        ],
      ),
    );
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) {
      return;
    }
    final max = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.position.pixels;
    if (current >= max - 200) {
      _loadMore();
    }
  }

  void _setFilter(String value) {
    if (_filter == value) {
      return;
    }
    setState(() => _filter = value);
    _resetAndLoad();
  }

  void _resetAndLoad() {
    _questions.clear();
    _polls.clear();
    _quizzes.clear();
    _lastQuestion = null;
    _lastPoll = null;
    _lastQuiz = null;
    _hasMoreQuestions = true;
    _hasMorePolls = true;
    _hasMoreQuizzes = true;
    _loadInitial();
  }

  Future<void> _refreshFeed() async {
    _questions.clear();
    _polls.clear();
    _quizzes.clear();
    _lastQuestion = null;
    _lastPoll = null;
    _lastQuiz = null;
    _hasMoreQuestions = true;
    _hasMorePolls = true;
    _hasMoreQuizzes = true;
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    await _loadForFilter();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loading) {
      return;
    }
    if (_filter == 'Questions' && !_hasMoreQuestions) {
      return;
    }
    if (_filter == 'Polls' && !_hasMorePolls) {
      return;
    }
    if (_filter == 'Quizzes' && !_hasMoreQuizzes) {
      return;
    }
    if (_filter == 'All' &&
        !_hasMoreQuestions &&
        !_hasMorePolls &&
        !_hasMoreQuizzes) {
      return;
    }
    setState(() => _loading = true);
    await _loadForFilter();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadForFilter() async {
    if (_filter == 'Questions') {
      await _loadCollection(
        collection: 'questions',
        target: _questions,
        last: _lastQuestion,
        setLast: (doc) => _lastQuestion = doc,
        setHasMore: (v) => _hasMoreQuestions = v,
      );
      return;
    }
    if (_filter == 'Polls') {
      await _loadCollection(
        collection: 'polls',
        target: _polls,
        last: _lastPoll,
        setLast: (doc) => _lastPoll = doc,
        setHasMore: (v) => _hasMorePolls = v,
      );
      return;
    }
    if (_filter == 'Quizzes') {
      await _loadCollection(
        collection: 'quizzes',
        target: _quizzes,
        last: _lastQuiz,
        setLast: (doc) => _lastQuiz = doc,
        setHasMore: (v) => _hasMoreQuizzes = v,
      );
      return;
    }

    await _loadCollection(
      collection: 'questions',
      target: _questions,
      last: _lastQuestion,
      setLast: (doc) => _lastQuestion = doc,
      setHasMore: (v) => _hasMoreQuestions = v,
    );
    await _loadCollection(
      collection: 'polls',
      target: _polls,
      last: _lastPoll,
      setLast: (doc) => _lastPoll = doc,
      setHasMore: (v) => _hasMorePolls = v,
    );
    await _loadCollection(
      collection: 'quizzes',
      target: _quizzes,
      last: _lastQuiz,
      setLast: (doc) => _lastQuiz = doc,
      setHasMore: (v) => _hasMoreQuizzes = v,
    );
  }

  Future<void> _loadCollection({
    required String collection,
    required List<QueryDocumentSnapshot> target,
    required DocumentSnapshot? last,
    required void Function(DocumentSnapshot?) setLast,
    required void Function(bool) setHasMore,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);
    if (last != null) {
      query = query.startAfterDocument(last);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) {
      setHasMore(false);
      return;
    }
    target.addAll(snap.docs);
    setLast(snap.docs.last);
    setHasMore(snap.docs.length == _pageSize);
  }

  List<QueryDocumentSnapshot> _currentDocs() {
    final docs = <QueryDocumentSnapshot>[];
    if (_filter == 'Questions' || _filter == 'All') {
      docs.addAll(_questions);
    }
    if (_filter == 'Polls' || _filter == 'All') {
      docs.addAll(_polls);
    }
    if (_filter == 'Quizzes' || _filter == 'All') {
      docs.addAll(_quizzes);
    }
    docs.sort((a, b) {
      final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aTs == null && bTs == null) {
        return 0;
      }
      if (aTs == null) {
        return 1;
      }
      if (bTs == null) {
        return -1;
      }
      return bTs.compareTo(aTs);
    });
    return docs;
  }

  Widget _buildFeedList() {
    final docs = _currentDocs();
    if (_loading && docs.isEmpty) {
      return const _LibraryFeedSkeleton();
    }
    if (docs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshFeed,
        child: ListView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: const [
            SizedBox(height: 160),
            Center(
              child: Text(
                'No posts found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.reverse && _showChips) {
          setState(() => _showChips = false);
        } else if (notification.direction == ScrollDirection.forward &&
            !_showChips) {
          setState(() => _showChips = true);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: ListView.builder(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: docs.length + (_loading ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= docs.length) {
              return const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final doc = docs[i];
            return StreamBuilder<DocumentSnapshot>(
              stream: doc.reference.snapshots(),
              builder: (context, snap) {
                final data =
                    (snap.data?.data() as Map<String, dynamic>?) ??
                    (doc.data() as Map<String, dynamic>);
                return FeedCard(data: data, id: doc.id);
              },
            );
          },
        ),
      ),
    );
  }
}

class _LibraryFeedSkeleton extends StatelessWidget {
  const _LibraryFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFF1E2440);
    const highlight = Color(0xFF313A63);

    Widget bar({
      required double height,
      double radius = 10,
      double? width,
      EdgeInsetsGeometry margin = EdgeInsets.zero,
    }) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget skeletonCard() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: base.withOpacity(0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: highlight.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                bar(height: 26, width: 26, radius: 999),
                const SizedBox(width: 8),
                Expanded(child: bar(height: 12, width: 110)),
                const SizedBox(width: 8),
                bar(height: 22, width: 64, radius: 999),
              ],
            ),
            const SizedBox(height: 14),
            bar(height: 16, width: double.infinity),
            const SizedBox(height: 10),
            bar(height: 16, width: 220),
            const SizedBox(height: 16),
            bar(
              height: 44,
              radius: 14,
              margin: const EdgeInsets.only(bottom: 10),
            ),
            Row(
              children: [
                bar(height: 18, width: 56),
                const Spacer(),
                bar(height: 18, width: 86),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF0C1020),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 140),
          children: [
            skeletonCard(),
            const SizedBox(height: 12),
            skeletonCard(),
            const SizedBox(height: 12),
            skeletonCard(),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surface;
    final textColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserSearchSuggestions extends StatelessWidget {
  final String query;
  const _UserSearchSuggestions({required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final ref = FirebaseFirestore.instance
        .collection('users')
        .orderBy('username')
        .startAt([q])
        .endAt(['$q\uf8ff']);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.limit(10).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('No users found', style: TextStyle(color: Colors.grey)),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final uid = docs[i].id;
              final name = (data['name'] ?? '').toString();
              final username = (data['username'] ?? '').toString();
              final letter = username.isNotEmpty
                  ? username[0].toUpperCase()
                  : 'U';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Text(
                    letter,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(name.isNotEmpty ? name : username),
                subtitle: Text('@$username'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ================= FEED CARD =================
class FeedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String id;
  const FeedCard({super.key, required this.data, required this.id});

  @override
  Widget build(BuildContext context) {
    final type = data['type'];
    final collection = type == 'quiz' ? 'quizzes' : '${type}s';
    final typeLabel = type == 'quiz'
        ? 'Quiz'
        : type == 'poll'
        ? 'Poll'
        : 'Question';
    final username = (data['username'] ?? '').toString();
    final safeName = username.isNotEmpty ? username : 'User';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= UPDATED HEADER ROW =================
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(uid: data['uid']),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Text(
                      safeName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: data['uid']),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          safeName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${type.toUpperCase()} • ${data['category']} • ${timeAgo(data['createdAt'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FollowButton(targetUid: data['uid']),
              ],
            ),

            const SizedBox(height: 10),
            Text('Que. ${data['content'] ?? ''}'),

            if (type == 'question')
              AnswerBox(postId: id, ownerUid: data['uid']),
            if (type == 'poll' || type == 'quiz') ...[
              const SizedBox(height: 10),
              const Text(
                'Options',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _OptionStatsList(
                postId: id,
                type: type,
                options: (data['options'] as List?) ?? const [],
                correctIndex: data['correctIndex'] as int?,
                ownerUid: data['uid'],
                content: (data['content'] ?? '').toString(),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    LikeButton(
                      postId: id,
                      collection: collection,
                      ownerUid: data['uid'],
                      content: (data['content'] ?? '').toString(),
                    ),
                    Text(formatCount(data['likes'] ?? 0)),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          postId: id,
                          collection: collection,
                          type: typeLabel,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        _answerLabel(
                          type: type,
                          count: data['answeredCount'] ?? 0,
                        ),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionStatsList extends StatelessWidget {
  final String postId;
  final String type;
  final List options;
  final int? correctIndex;
  final String ownerUid;
  final String content;

  const _OptionStatsList({
    required this.postId,
    required this.type,
    required this.options,
    required this.correctIndex,
    required this.ownerUid,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Text('No options available');
    }

    final collection = type == 'quiz' ? 'quizzes' : 'polls';
    final subcollection = type == 'quiz' ? 'attempts' : 'votes';
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(postId)
        .collection(subcollection)
        .doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final answered = userSnap.data?.exists ?? false;
        final selected =
            (userSnap.data?.data() as Map<String, dynamic>?)?[type == 'quiz'
                ? 'index'
                : 'option'];

        if (!answered) {
          return Column(
            children: List.generate(options.length, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: ListTile(
                  title: Text(options[i].toString()),
                  onTap: () async {
                    if (type == 'quiz') {
                      await userRef.set({'index': i});
                      await FirebaseFirestore.instance
                          .collection('quizzes')
                          .doc(postId)
                          .update({'answeredCount': FieldValue.increment(1)});
                    } else {
                      await userRef.set({'option': options[i].toString()});
                      await FirebaseFirestore.instance
                          .collection('polls')
                          .doc(postId)
                          .update({'answeredCount': FieldValue.increment(1)});
                    }

                    final myUid = FirebaseAuth.instance.currentUser?.uid;
                    if (myUid != null && myUid != ownerUid) {
                      final myName = await _currentUserLabel();
                      final voteTitle = type == 'quiz'
                          ? '$myName answered your quiz.'
                          : '$myName votes on your poll.';
                      await NotificationHelper.addActivity(
                        targetUid: ownerUid,
                        type: 'vote',
                        title: voteTitle,
                        actorUid: myUid,
                        postId: postId,
                        postType: type,
                        content: content,
                      );
                    }
                  },
                ),
              );
            }),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collection)
              .doc(postId)
              .collection(subcollection)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            final counts = List<int>.filled(options.length, 0);
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              if (type == 'quiz') {
                final index = data['index'];
                if (index is int && index >= 0 && index < counts.length) {
                  counts[index] += 1;
                }
              } else {
                final option = data['option'];
                if (option is String) {
                  final idx = options.indexOf(option);
                  if (idx != -1) counts[idx] += 1;
                }
              }
            }

            final total = counts.fold<int>(0, (a, b) => a + b);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(options.length, (i) {
                  final percent = total == 0
                      ? 0
                      : ((counts[i] / total) * 100).round();
                  final isCorrect = type == 'quiz' && correctIndex == i;
                  final isSelected = type == 'quiz'
                      ? selected == i
                      : selected == options[i].toString();
                  final fillColor = type == 'quiz'
                      ? (isCorrect
                            ? Colors.green.withOpacity(0.18)
                            : Colors.red.withOpacity(0.12))
                      : Theme.of(context).colorScheme.primary.withOpacity(0.10);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: percent / 100,
                            alignment: Alignment.centerLeft,
                            child: Container(height: 44, color: fillColor),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    options[i].toString(),
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isCorrect
                                          ? Colors.green
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$percent%',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

// ================= QUIZ =================
class QuizWidget extends StatelessWidget {
  final String postId;
  final List options;
  final int correct;

  const QuizWidget({
    super.key,
    required this.postId,
    required this.options,
    required this.correct,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('quizzes')
        .doc(postId)
        .collection('attempts')
        .doc(uid);

    if (options.isEmpty) {
      return const Text('No quiz options');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final answered = snap.data?.exists ?? false;
        final selected = (snap.data?.data() as Map<String, dynamic>?)?['index'];

        return Column(
          children: List.generate(options.length, (i) {
            Color? bg;
            if (answered) {
              if (i == correct) {
                bg = Colors.green.withOpacity(.2);
              }
              if (i == selected && i != correct) {
                bg = Colors.red.withOpacity(.2);
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(options[i]),
                onTap: answered
                    ? null
                    : () async {
                        await ref.set({'index': i});
                        await FirebaseFirestore.instance
                            .collection('quizzes')
                            .doc(postId)
                            .update({'answeredCount': FieldValue.increment(1)});
                      },
              ),
            );
          }),
        );
      },
    );
  }
}

// ================= POLL =================
class PollWidget extends StatelessWidget {
  final String postId;
  final List options;
  const PollWidget({super.key, required this.postId, required this.options});

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const Text('No poll options');
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection('polls')
        .doc(postId)
        .collection('votes')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, s) {
        final voted = s.data?.exists ?? false;
        return Column(
          children: options
              .map(
                (o) => ListTile(
                  title: Text(o),
                  trailing: voted
                      ? const Icon(Icons.check, color: Colors.indigo)
                      : null,
                  onTap: voted
                      ? null
                      : () async {
                          await ref.set({'option': o});
                          await FirebaseFirestore.instance
                              .collection('polls')
                              .doc(postId)
                              .update({
                                'answeredCount': FieldValue.increment(1),
                              });
                        },
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ================= LIKE =================
class LikeButton extends StatelessWidget {
  final String postId;
  final String collection;
  final String ownerUid;
  final String content;
  const LikeButton({
    super.key,
    required this.postId,
    required this.collection,
    required this.ownerUid,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance
        .collection(collection)
        .doc(postId)
        .collection('likes')
        .doc(uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, s) {
        final liked = s.data?.exists ?? false;
        return IconButton(
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? Colors.indigo : Colors.grey,
          ),
          onPressed: () async {
            final post = FirebaseFirestore.instance
                .collection(collection)
                .doc(postId);
            await FirebaseFirestore.instance.runTransaction((tx) async {
              liked ? tx.delete(ref) : tx.set(ref, {'uid': uid});
              tx.update(post, {'likes': FieldValue.increment(liked ? -1 : 1)});
            });

            if (uid == ownerUid) {
              return;
            }

            if (liked) {
              await NotificationHelper.removeLikeActivity(
                targetUid: ownerUid,
                actorUid: uid,
                postId: postId,
                postType: collection,
              );
            } else {
              final myName = await _currentUserLabel();
              final likeLabel = collection == 'questions'
                  ? 'question'
                  : collection == 'polls'
                  ? 'poll'
                  : 'quiz';
              await NotificationHelper.upsertLikeActivity(
                targetUid: ownerUid,
                title: '$myName likes your $likeLabel.',
                actorUid: uid,
                postId: postId,
                postType: collection,
                content: content,
              );
            }
          },
        );
      },
    );
  }
}

// ================= ANSWER =================
class AnswerBox extends StatefulWidget {
  final String postId;
  final String ownerUid;
  const AnswerBox({super.key, required this.postId, required this.ownerUid});

  @override
  State<AnswerBox> createState() => _AnswerBoxState();
}

class _AnswerBoxState extends State<AnswerBox> {
  final c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Answer...'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_upward, color: Colors.indigo),
          onPressed: () async {
            if (c.text.trim().isEmpty) {
              return;
            }
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final ref = FirebaseFirestore.instance
                .collection('questions')
                .doc(widget.postId)
                .collection('answers')
                .doc(uid);

            if ((await ref.get()).exists) {
              return;
            }
            await ref.set({
              'text': c.text.trim(),
              'uid': uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
            await FirebaseFirestore.instance
                .collection('questions')
                .doc(widget.postId)
                .update({'answeredCount': FieldValue.increment(1)});

            if (uid != widget.ownerUid) {
              final myName = await _currentUserLabel();
              await NotificationHelper.addActivity(
                targetUid: widget.ownerUid,
                type: 'answer',
                title: '$myName answered your question.',
                actorUid: uid,
                postId: widget.postId,
                postType: 'question',
                content: c.text.trim(),
              );
            }
            c.clear();
          },
        ),
      ],
    );
  }
}

// ================= FOLLOW BUTTON WIDGET =================
class FollowButton extends StatelessWidget {
  final String targetUid;
  const FollowButton({super.key, required this.targetUid});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    if (myUid == targetUid) {
      return const SizedBox();
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(myUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final isFollowing = snap.data?.exists ?? false;
        return InkWell(
          onTap: () async {
            final batch = FirebaseFirestore.instance.batch();
            final myRef = FirebaseFirestore.instance
                .collection('users')
                .doc(myUid)
                .collection('following')
                .doc(targetUid);

            if (isFollowing) {
              batch.delete(ref);
              batch.delete(myRef);
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(targetUid),
                {'followers': FieldValue.increment(-1)},
                SetOptions(merge: true),
              );
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(myUid),
                {'following': FieldValue.increment(-1)},
                SetOptions(merge: true),
              );
            } else {
              batch.set(ref, {'time': Timestamp.now()});
              batch.set(myRef, {'time': Timestamp.now()});
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(targetUid),
                {'followers': FieldValue.increment(1)},
                SetOptions(merge: true),
              );
              batch.set(
                FirebaseFirestore.instance.collection('users').doc(myUid),
                {'following': FieldValue.increment(1)},
                SetOptions(merge: true),
              );
            }
            await batch.commit();

            if (myUid == targetUid) {
              return;
            }

            if (isFollowing) {
              await NotificationHelper.removeFollowActivity(
                targetUid: targetUid,
                actorUid: myUid,
              );
            } else {
              final myName = await _currentUserLabel();
              await NotificationHelper.upsertFollowActivity(
                targetUid: targetUid,
                title: '$myName started followed you',
                actorUid: myUid,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.grey.shade200 : Colors.indigo,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: TextStyle(
                fontSize: 12,
                color: isFollowing ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================= USER PROFILE SCREEN =================
class UserProfileScreen extends StatelessWidget {
  final String uid;
  const UserProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userRef.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snap.data!.data() as Map<String, dynamic>;
          final username = user['username'] ?? 'User';

          return Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.indigo,
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Count(uid: uid, label: 'Posts'),
                  _Count(uid: uid, label: 'Followers'),
                  _Count(uid: uid, label: 'Following'),
                ],
              ),
              const Divider(height: 30),
              Expanded(child: _UserPosts(uid: uid)),
            ],
          );
        },
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String uid;
  final String label;
  const _Count({required this.uid, required this.label});

  @override
  Widget build(BuildContext context) {
    final ref = label == 'Followers'
        ? FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('followers')
        : label == 'Following'
        ? FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('following')
        : FirebaseFirestore.instance
              .collection('questions')
              .where('uid', isEqualTo: uid);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}

class _UserPosts extends StatelessWidget {
  final String uid;
  const _UserPosts({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('questions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        return ListView.builder(
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            final data = snap.data!.docs[i].data() as Map<String, dynamic>;
            return ListTile(title: Text(data['content'] ?? ''));
          },
        );
      },
    );
  }
}

// ================= HELPERS =================
String formatCount(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}K';
  }
  return n.toString();
}

String timeAgo(Timestamp t) {
  final d = DateTime.now().difference(t.toDate());
  if (d.inMinutes < 1) {
    return 'just now';
  }
  if (d.inMinutes < 60) {
    return '${d.inMinutes}m ago';
  }
  if (d.inHours < 24) {
    return '${d.inHours}h ago';
  }
  return '${d.inDays}d ago';
}

String _answerLabel({required String type, required int count}) {
  if (type == 'question') {
    return '$count answers';
  }
  if (type == 'quiz') {
    return '$count answers';
  }
  if (type == 'poll') {
    return '$count votes';
  }
  return '$count';
}
