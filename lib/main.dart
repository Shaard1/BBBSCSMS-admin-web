import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/landing/landing_page.dart';
import 'screens/admin/admin_dashboard.dart';
import 'services/admin_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ntjvtnnerjevsucjdajp.supabase.co',
    anonKey: 'sb_publishable_s5X6pvsR_YCRuSINxFmImA_P3WYNQ6x',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barangay Admin Dashboard',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0087EF)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: home ?? const AdminAccessGate(),
    );
  }
}

class AdminAccessGate extends StatefulWidget {
  const AdminAccessGate({super.key});

  @override
  State<AdminAccessGate> createState() => _AdminAccessGateState();
}

class _AdminAccessGateState extends State<AdminAccessGate> {
  final adminAuthService = AdminAuthService();

  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final isAdmin = await adminAuthService.isCurrentUserAdmin();

    if (!isAdmin) {
      await Supabase.instance.client.auth.signOut();
    }

    if (!mounted) return;

    setState(() {
      _isAdmin = isAdmin;
      _isLoading = false;
    });

    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Only admin accounts can access this web portal."),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAdmin) {
      return const AdminDashboard();
    }

    return const LandingPage();
  }
}
