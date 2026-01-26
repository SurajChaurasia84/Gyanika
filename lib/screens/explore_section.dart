import 'package:flutter/material.dart';

class ExploreSection extends StatelessWidget {
  const ExploreSection({super.key});

  // Dummy categories & content
  final List<Map<String, dynamic>> categories = const [
    {
      "title": "SSC",
      "items": ["Math", "Science", "English", "History", "GK"],
    },
    {
      "title": "Bank Exams",
      "items": ["Quantitative Aptitude", "Reasoning", "English", "Current Affairs"],
    },
    {
      "title": "Competitive",
      "items": ["Coding", "Logical Reasoning", "Math", "General Knowledge"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Explore"),
          automaticallyImplyLeading: false,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final items = category["items"] as List<String>;

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Title
                  Text(
                    category["title"],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horizontal Scrollable Cards
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, itemIndex) {
                        final item = items[itemIndex];

                        return GestureDetector(
                          onTap: () {
                            // Navigate to content page
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Open $item content")),
                            );
                          },
                          child: Container(
                            width: 140,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.folder_open,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
