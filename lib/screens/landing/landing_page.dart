import 'package:flutter/material.dart';
import '../auth/admin_login_screen.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9E3E8),

      body: Column(
        children: [
          /// NAVBAR
          Container(
            height: 80,
            color: const Color(0xFF2F3946),
            padding: const EdgeInsets.symmetric(horizontal: 40),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "BARANGAY BANCAO-BANCAO COMMUNITY SERVICES",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                /// LOGIN BUTTON
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminLoginScreen(),
                      ),
                    );
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0087EF),
                  ),

                  child: const Text("Log-in"),
                ),
              ],
            ),
          ),

          /// HERO SECTION
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,

                children: const [
                  Text(
                    "Get Access To Barangay\nServices Online!",
                    style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 20),

                  SizedBox(
                    width: 600,
                    child: Text(
                      "Download the mobile app to report concerns, request certificates, and stay connected with your barangay. Simple, fast, and reliable.",
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
