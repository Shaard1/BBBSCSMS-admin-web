import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/admin_login_screen.dart';

import 'reports_dashboard_screen.dart';
import 'reports_map_screen.dart';
import 'residents_screen.dart';
import 'analytics_screen.dart';
import 'announcements_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final supabase = Supabase.instance.client;
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _sidebarColor = Color(0xFFF8FAFC);
  static const Color _accentColor = Color(0xFF0087EF);
  static const Color _mutedColor = Color(0xFF6B7280);

  int selectedIndex = 0;
  int pendingReportsCount = 0;
  int pendingResidentsCount = 0;
  String adminName = "Admin";
  String adminRole = "admin";
  Timer? _pollTimer;
  bool _dashboardVisible = false;
  bool _showWelcomeOverlay = true;
  bool _welcomeOverlayFadeOut = false;

  final List<Widget> pages = [
    const ReportsDashboardScreen(),
    const ReportsMapScreen(),
    const ResidentsScreen(),
    const AnalyticsScreen(),
    const AnnouncementsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _startWelcomeIntro();
    _loadAdminHeaderData();
    _refreshNotificationCounts();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshNotificationCounts();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  int get notificationCount => pendingReportsCount + pendingResidentsCount;

  void _startWelcomeIntro() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _dashboardVisible = true;
      });
    });

    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() {
        _welcomeOverlayFadeOut = true;
      });
    });

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() {
        _showWelcomeOverlay = false;
      });
    });
  }

  String _fallbackAdminName(User user) {
    final metadataName =
        user.userMetadata?['full_name']?.toString().trim() ?? '';
    if (metadataName.isNotEmpty) return metadataName;

    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) {
      final emailName = email.split('@').first.trim();
      if (emailName.isNotEmpty) return emailName;
    }

    return "Admin";
  }

  Future<void> _loadAdminHeaderData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      String resolvedName = _fallbackAdminName(user);
      String resolvedRole = "admin";

      final profile = await supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        if (profile['full_name']?.toString().trim().isNotEmpty == true) {
          resolvedName = profile['full_name'];
        }
        if (profile['role']?.toString().trim().isNotEmpty == true) {
          resolvedRole = profile['role'];
        }
      }

      if (!mounted) return;

      setState(() {
        adminName = resolvedName;
        adminRole = resolvedRole;
      });
    } catch (_) {}
  }

  Future<void> _refreshNotificationCounts() async {
    try {
      final pendingReports = await supabase
          .from('reports')
          .select('id')
          .eq('status', 'pending');

      final pendingResidents = await supabase
          .from('residents')
          .select('id')
          .eq('status', 'pending');

      if (!mounted) return;

      setState(() {
        pendingReportsCount = (pendingReports as List).length;
        pendingResidentsCount = (pendingResidents as List).length;
      });
    } catch (_) {}
  }

  void _openNotificationsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Notifications"),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.report_problem_outlined),
                  title: const Text("Pending reports"),
                  subtitle: Text("$pendingReportsCount waiting for review"),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      setState(() {
                        selectedIndex = 0;
                      });
                    },
                    child: const Text("Open"),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text("Pending registrations"),
                  subtitle: Text("$pendingResidentsCount waiting for approval"),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      setState(() {
                        selectedIndex = 2;
                      });
                    },
                    child: const Text("Open"),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Future logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  Widget _buildSidebarItem({
    required String iconAsset,
    required String title,
    required int index,
    int badgeCount = 0,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                selectedIndex = index;
              });
              _refreshNotificationCounts();
            },
            child: SizedBox(
              height: 46,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: SvgPicture.asset(
                        iconAsset,
                        width: 21,
                        height: 21,
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          isSelected ? _accentColor : const Color(0xFF374151),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? _accentColor
                            : const Color(0xFF374151),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    SizedBox(
                      width: 32,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D4F),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeCount > 99 ? "99+" : "$badgeCount",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 32),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          AnimatedOpacity(
            opacity: _dashboardVisible ? 1 : 0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            child: Row(
              children: [
                /// SIDEBAR
                Container(
                  width: 260,
                  color: _sidebarColor,
                  foregroundDecoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'lib/Assets/BBBC.png',
                                width: 44,
                                height: 44,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Admin Portal",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFF0087EF),
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    "Community Management",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          "MAIN MENU",
                          style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSidebarItem(
                        iconAsset: 'lib/Assets/Mainmenu Analytics icon.svg',
                        title: "Analytics",
                        index: 3,
                      ),
                      _buildSidebarItem(
                        iconAsset:
                            'lib/Assets/Mainmenu Community Reports icon.svg',
                        title: "Community Reports",
                        index: 0,
                        badgeCount: pendingReportsCount,
                      ),
                      _buildSidebarItem(
                        iconAsset: 'lib/Assets/Mainmenu Complain Map icon.svg',
                        title: "Complaint Map",
                        index: 1,
                      ),
                      _buildSidebarItem(
                        iconAsset:
                            'lib/Assets/Mainmenu Resident Verification icon.svg',
                        title: "Resident Verification",
                        index: 2,
                        badgeCount: pendingResidentsCount,
                      ),
                      _buildSidebarItem(
                        iconAsset: 'lib/Assets/Mainmenu Announcement icon.svg',
                        title: "Announcement",
                        index: 4,
                      ),

                      const Spacer(),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: logout,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout,
                                    color: Color(0xFF374151),
                                    size: 18,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Logout",
                                    style: TextStyle(
                                      color: Color(0xFF374151),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),
                    ],
                  ),
                ),

                /// MAIN CONTENT
                Expanded(
                  child: Column(
                    children: [
                      /// HEADER
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),

                        child: Row(
                          children: [
                            const Spacer(),
                            SizedBox(
                              width: 250,
                              height: 32,
                              child: TextField(
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: "Search...",
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 16,
                                    color: Color(0xFF6B7280),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 34,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: IconButton(
                                    tooltip: "Notifications",
                                    constraints: const BoxConstraints.tightFor(
                                      width: 34,
                                      height: 34,
                                    ),
                                    padding: EdgeInsets.zero,
                                    onPressed: () async {
                                      await _refreshNotificationCounts();
                                      if (!mounted) return;
                                      _openNotificationsDialog();
                                    },
                                    icon: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        const Icon(
                                          Icons.notifications_none,
                                          size: 18,
                                        ),
                                        if (notificationCount > 0)
                                          Positioned(
                                            right: -8,
                                            top: -7,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                notificationCount > 99
                                                    ? "99+"
                                                    : "$notificationCount",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  tooltip: "Account menu",
                                  color: Colors.white,
                                  elevation: 8,
                                  shadowColor: const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.12),
                                  surfaceTintColor: Colors.transparent,
                                  offset: const Offset(0, 10),
                                  constraints: const BoxConstraints(
                                    minWidth: 176,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: Color(0xFFD9DFE7),
                                    ),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'logout') {
                                      logout();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'logout',
                                      height: 48,
                                      padding: EdgeInsets.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 19,
                                              color: Color(0xFF3F4854),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              "Logout",
                                              style: TextStyle(
                                                color: Color(0xFF3F4854),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    height: 34,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFBFC),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: _accentColor
                                              .withValues(alpha: 0.15),
                                          child: Icon(
                                            Icons.person,
                                            color: _accentColor,
                                            size: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 96,
                                          ),
                                          child: Text(
                                            adminName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              height: 1,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 16,
                                          color: _mutedColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Container(
                          color: _pageBackground,
                          child: pages[selectedIndex],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_showWelcomeOverlay)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _welcomeOverlayFadeOut ? 0 : 1,
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeInOut,
                child: Container(
                  color: const Color(0xFF0087EF),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'lib/Assets/BBBC.png',
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Welcome, $adminName",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Loading admin dashboard...",
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 16,
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
}
