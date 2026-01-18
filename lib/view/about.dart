// lib/about.dart
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _aboutText = """
The MediChine App is a smart medication management system designed to help users easily track and organize their daily medicine intake. Developed by a team of Computer Science students from Pangasinan State University Lingayen Campus, this project aims to provide a simple yet effective solution for medication adherence.

With the MediChine App, users can:
✅ Set Medication Reminders: Schedule exact times for taking medication with an easy-to-use time and calendar interface.
✅ Customize Containers: Label containers (e.g., Morning Meds, Afternoon Meds, Evening Meds) for easy identification.
✅ Sync with the MediChine Dispenser: The app sends scheduled reminders to the Arduino-powered pill dispenser, ensuring timely alerts when it's time to take medicine.

When it's time for a scheduled dose, the MediChine App will send commands to the Arduino to dispense medicine, and the MediChine Dispenser will play an alert sound, making it easier to stick to a medication routine.

Our goal is to simplify medication management and make it more accessible for everyone. Whether you are managing your own medication or assisting a loved one, the MediChine App provides a user-friendly way to stay on track.

Developed by Werner, Kisha, Jocelyn, Melody,& Ann, a team committed to creating smart and practical health solutions.
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
          'About MediChine',
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
              // App logo above the text
              Image.asset(
                'assets/med.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 16),

              // The about description
              Text(
                _aboutText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
