import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class HelpSupportFeedbackScreen extends StatefulWidget {
  const HelpSupportFeedbackScreen({super.key});

  @override
  State<HelpSupportFeedbackScreen> createState() =>
      _HelpSupportFeedbackScreenState();
}

class _HelpSupportFeedbackScreenState
    extends State<HelpSupportFeedbackScreen> {
  final TextEditingController _feedbackCtrl = TextEditingController();
  final TextEditingController _problemCtrl = TextEditingController();
  bool _feedbackOpen = false;
  bool _problemOpen = false;
  bool _sendingFeedback = false;
  bool _sendingProblem = false;
  String? _thanksMessage;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _problemCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({
    required String category,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').toString();
    final collection = category == 'Problem' ? 'problems' : 'feedbacks';
    final docId = email.isNotEmpty ? email : (user?.uid ?? 'anonymous');
    final now = Timestamp.now();

    await FirebaseFirestore.instance.collection(collection).doc(docId).set({
      'email': email,
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'category': category,
      'messages': FieldValue.arrayUnion([
        {
          'message': text,
          'createdAt': now,
        }
      ]),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() {
      _thanksMessage = category == 'Problem'
          ? 'Thanks for reporting a problem,\nwe will fix soon.'
          : 'Thanks for giving feedback.';
    });

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'How can we help?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _expandTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Send Feedback'),
                subtitle: const Text('Tell us what you think'),
                isOpen: _feedbackOpen,
                onTap: () =>
                    setState(() => _feedbackOpen = !_feedbackOpen),
                child: _inputRow(
                  controller: _feedbackCtrl,
                  enabled: !_sendingFeedback,
                  hint: 'Write feedback',
                  onSend: _sendingFeedback
                      ? null
                      : () async {
                          final text = _feedbackCtrl.text.trim();
                          if (text.isEmpty) return;
                          setState(() => _sendingFeedback = true);
                          await _submit(category: 'Feedback', text: text);
                          if (!mounted) return;
                          setState(() => _sendingFeedback = false);
                        },
                ),
              ),
              const SizedBox(height: 10),
              _expandTile(
                leading: const Icon(Icons.support_agent_outlined),
                title: const Text('Contact Support'),
                subtitle: const Text('Report a problem'),
                isOpen: _problemOpen,
                onTap: () =>
                    setState(() => _problemOpen = !_problemOpen),
                child: _inputRow(
                  controller: _problemCtrl,
                  enabled: !_sendingProblem,
                  hint: 'Write problem',
                  onSend: _sendingProblem
                      ? null
                      : () async {
                          final text = _problemCtrl.text.trim();
                          if (text.isEmpty) return;
                          setState(() => _sendingProblem = true);
                          await _submit(
                            category: 'Problem',
                            text: text,
                          );
                          if (!mounted) return;
                          setState(() => _sendingProblem = false);
                        },
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _thanksMessage == null
                ? const SizedBox.shrink()
                : Container(
                    key: const ValueKey('thanks'),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.indigo,
                            size: 54,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _thanksMessage ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _expandTile({
    required Widget leading,
    required Widget title,
    required Widget subtitle,
    required bool isOpen,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 2),
                      DefaultTextStyle(
                        style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey) ??
                            const TextStyle(color: Colors.grey),
                        child: subtitle,
                      ),
                    ],
                  ),
                ),
                Icon(
                  isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }

  Widget _inputRow({
    required TextEditingController controller,
    required bool enabled,
    required String hint,
    required VoidCallback? onSend,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 3,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: enabled
              ? const Icon(Icons.send, color: Colors.indigo)
              : const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          onPressed: enabled ? onSend : null,
        ),
      ],
    );
  }
}
