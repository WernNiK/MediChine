import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> tutorialData = const [
    {
      'image': 'assets/med.png',
      'title': '👋 Welcome to MediChine!',
      'description': 'Welcome to MediChine! Swipe left to explore our features and get started.',
    },
    {
      'image': 'assets/home.png',
      'title': '🏠 Home Dashboard',
      'description': """The central hub of the app where users can navigate to major features like setting schedules, viewing history, reading tutorials, and modifying settings.

🔘 SET SCHEDULE – Navigate to container selection to create new reminders.
🔘 HISTORY – View logs of completed medications.
🔘 TUTORIALS – Learn how to use the app.
🔘 SETTINGS – Personalize preferences like theme, notifications, and more."""
    },
    {
      'image': 'assets/container.png',
      'title': '📦 Select Container',
      'description': """This screen allows users to choose from four available containers to assign their medication schedules. Each container acts as a virtual compartment that helps organize and separate different prescriptions. The color-coded design makes navigation intuitive and visually clear."""
    },
    {
      'image': 'assets/list.png',
      'title': '📋 Schedule List per Container',
      'description': """After selecting a container, this screen displays the list of schedules stored within it. If there are no schedules yet, users are encouraged to add new ones.

🔘 Delete – Removes all entries in the container.
🔘 Add – Opens the form to create a new schedule.
🔘 Refresh – Updates the displayed list."""
    },
    {
      'image': 'assets/create.png',
      'title': '📝 Add Medication Schedule',
      'description': """Users can add a new medication schedule here by entering a label name, selecting a time, choosing specific days or 'Everyday', and setting the dosage quantity.

🔘 Add Name – Input the medicine name.
🔘 Select Time – Pick the time of intake.
🔘 Select Days – Choose the days to take the medicine.
🔘 Add Quantity – Set how many doses to take.
🔘 SAVE – Confirms and saves the schedule.
🔘 CANCEL – Exits without saving changes."""
    },
    {
      'image': 'assets/view.png',
      'title': '🗂️ View Container Schedule',
      'description': """This screen shows how scheduled medications appear inside a container. Users can view the medicine label, time, days of intake, and dosage quantity.

🔘 Edit – Opens the edit form with current schedule values pre-filled.
🔘 Delete – Removes the specific schedule."""
    },
    {
      'image': 'assets/history.png',
      'title': '📊 Completed Schedules History',
      'description': """This screen displays a history log of completed medication schedules. If no completed schedules exist yet, a placeholder message is shown.

🔘 Delete All – Clears all history entries.
🔘 Refresh – Reloads the history data from the backend or local store."""
    },
    {
      'image': 'assets/settings.png',
      'title': '⚙️ Settings Overview',
      'description': """Users can explore Preferences, learn more About the app, view Contact information, or access Testing utilities. The layout remains color-coordinated and user-friendly across both light and dark modes, ensuring consistency.

🔘 PREFERENCES – Modify app appearance and behavior.
🔘 ABOUT – Learn about the MediChine app.
🔘 CONTACT US – View how to reach support or give feedback.
🔘 TESTING – Access development or debug utilities."""
    },
    {
      'image': 'assets/prefer.png',
      'title': '🌓 Preferences in Settings',
      'description': """This screen allows users to toggle between light and dark modes, customizing their viewing experience. It's tailored to enhance comfort—especially in low-light conditions—and gives a personalized feel to the app usage."""
    },
    {
      'image': 'assets/contact.png',
      'title': '📞 Contact Us',
      'description': """This screen provides users with multiple ways to reach the MediChine team for inquiries, support, or collaboration. Users can find the official email, phone number, website, and location address. Additionally, social media links are provided for staying updated. This section ensures users feel connected and supported, enhancing trust and accessibility."""
    },
    {
      'image': 'assets/test.png',
      'title': '🔬 Testing Module',
      'description': """This dedicated section enables users or developers to test each container and its schedule settings. It's especially useful for debugging or demoing functionality without affecting real reminders."""
    },
  ];

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.titleLarge?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "TUTORIALS",
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: titleColor),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: tutorialData.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final item = tutorialData[index]; // ✅ This is the correct way
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                tutorialImage(item),
                const SizedBox(height: 24),
                tutorialTitle(item, titleColor),
                const SizedBox(height: 20),
                tutorialDesc(item, textColor),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget tutorialImage(Map<String, String> item) {
    return SizedBox(
      height: 400,
      child: Image.asset(
        item['image']!,
        fit: BoxFit.contain,
        width: double.infinity,
      ),
    );
  }

  Widget tutorialTitle(Map<String, String> item, Color? color) {
    return Text(
      item['title']!,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
        color: color,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget tutorialDesc(Map<String, String> item, Color? color) {
    return Text(
      item['description']!,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.6,
        color: color,
      ),
      textAlign: TextAlign.justify,
    );
  }
}
