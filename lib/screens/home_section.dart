import 'package:flutter/material.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),

      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ); 
          },
        ),

        // 🔹 LOGO ONLY (NO APP NAME)
        title: Image.asset(
          'assets/src/name.png', // 👈 your logo file
          height: 32, // ✅ size fixed
          color: Colors.black, // 🎨 change logo color here
          colorBlendMode: BlendMode.srcIn,
        ),

        // centerTitle: true,

        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // TODO: open notifications
            },
          ),

          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () {
                // TODO: open profile
              },
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: create group
        },
        child: const Icon(Icons.add),
      ),

      body: const Center(
        child: Text(
          'Your Groups will appear here',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  // 🔹 LEFT SIDEBAR
  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('My Groups'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Saved Content'),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {},
            ),

            const Spacer(),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
