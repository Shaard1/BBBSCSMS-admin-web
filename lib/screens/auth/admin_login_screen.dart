import 'package:flutter/material.dart';
import '../admin/admin_dashboard.dart';
import '../../services/admin_auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final AdminAuthService _adminAuthService = AdminAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email and password are required.');
      return;
    }

    setState(() => _loading = true);

    try {
      final bool isAdmin = await _adminAuthService.signInAsAdmin(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        _showMessage('Only admin accounts can log in to this web portal.');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(30),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ***** Login Header Start *****
              const Text(
                "Barangay Admin Login",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // ***** Login Header End *****

              const SizedBox(height: 30),

              // ***** Login Fields Start *****
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontFamily: 'Inter'),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(fontFamily: 'Inter'),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(fontFamily: 'Inter'),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(fontFamily: 'Inter'),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              // ***** Login Fields End *****

              const SizedBox(height: 30),

              // ***** Login Button Start *****
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "Login",
                        style: TextStyle(fontFamily: 'Inter'),
                      ),
              ),
              // ***** Login Button End *****
            ],
          ),
        ),
      ),
    );
  }
}
