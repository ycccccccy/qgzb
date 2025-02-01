import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      routes: {
        '/page2': (context) => Page2(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:Center(
          child:Text(
            '鸿雁心笺',
            style: TextStyle(
              fontSize: 50.0, // Set the font size here
              fontWeight: FontWeight.w500, // Optional: Make the text bold
            ),
            )
        ) ,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // First Button
            CustomButton(
              imagePath: 'assets/images/custom_icon1.png', // Custom image path
              topText: '节日寄语',
              bottomText: '互送节日祝福，传递温馨寄语，让心意在指尖流转。',
              onPressed: () {
                Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => HomeScreen()));
              },
            ),
            SizedBox(height: 20.0), // Spacing between buttons
            // Second Button
            CustomButton(
              imagePath: 'assets/images/custom_icon2.png', // Custom image path
              topText: '时空胶囊',
              bottomText: '此刻指尖轻点，封存青春絮语，待金榜题名时，重启时光密语。',
              onPressed: () {
                                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Center(child:Text('确认跳转')), // Dialog title
                      content: Text('此功能仅限初三、高三学生使用'), // Dialog content
                      actions: [
                        TextButton(
                          onPressed: () {
                            // Close the dialog
                            Navigator.of(context).pop();
                          },
                          child: Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            // Close the dialog and navigate to Page 2
                            Navigator.of(context).pop(); // Close the dialog
                            Navigator.pushNamed(context, '/page2'); // Navigate to Page 2
                          },
                          child: Text('确认'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String imagePath; // Path to the custom image
  final String topText;
  final String bottomText;
  final VoidCallback onPressed;

  CustomButton({
    required this.imagePath,
    required this.topText,
    required this.bottomText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 400.0, // Increased width for the button
        padding: EdgeInsets.all(20.0), // Increased padding
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            // Left side with custom image and top text
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  imagePath, // Load custom image
                  width: 50.0, // Increased image width
                  height: 50.0, // Increased image height
                ),
                SizedBox(height: 8.0), // Increased spacing
                Text(
                  topText,
                  style: TextStyle(fontSize: 18.0), // Increased font size
                ),
              ],
            ),
            // Vertical divider
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.0), // Increased margin
              height: 60.0, // Increased height
              width: 1.0,
              color: Colors.grey,
            ),
            // Right side with bottom text
            Expanded(
              child: Text(
                bottomText,
                style: TextStyle(fontSize: 18.0), // Increased font size
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// Page 2
class Page2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page 2'),
      ),
      body: Center(
        child: Text('Welcome to Page 2!'),
      ),
    );
  }
}