// lib/contact.dart
import 'package:flutter/material.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const _contactText = """
For inquiries, support, or collaboration opportunities, feel free to reach out to us through the following channels:

📧 Email: support@medichine.com
📱 Phone: +63 912 345 6789
🌐 Website: www.medichine.com
📍 Address: Pangasinan State University, Lingayen Campus, Philippines

Follow us on social media for updates and news:
🔹 Facebook: facebook.com/medichineapp
🔹 Twitter: twitter.com/medichineapp
🔹 Instagram: instagram.com/medichineapp

We’d love to hear your feedback and suggestions to improve the MediChine App. Thank you for supporting our project!
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact Us',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge!.color,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Logo or contact image above the text
              Image.asset(
                'assets/med.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 16),
              Text(
                _contactText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
