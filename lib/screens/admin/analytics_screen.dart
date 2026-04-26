import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _navyColor = Color(0xFF0087EF);
  static const Color _blueColor = Color(0xFF0087EF);
  static const Color _goldColor = Color(0xFFE4A000);
  static const Color _greenColor = Color(0xFF2FB887);
  static const Color _tealColor = Color(0xFF1F8A70);
  static const Color _roseColor = Color(0xFFFF5B78);

  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  int totalReports = 0;
  int pendingReports = 0;
  int progressReports = 0;
  int resolvedReports = 0;
  int totalResidents = 0;

  final List<String> _categoryOrder = const [
    "Road Damage",
    "Garbage Collection",
    "Broken Streetlight",
    "Drainage Issue",
    "Noise Complaint",
    "Others",
  ];

  Map<int, int> monthlyReports = {
    for (int month = 1; month <= 12; month++) month: 0,
  };

  late Map<String, int> categoryCounts = {
    for (final category in _categoryOrder) category: 0,
  };

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  String _normalizeStatus(dynamic value) {
    final status = (value?.toString() ?? "").toLowerCase().trim();
    if (status == "in progress" || status == "in_process") return "in progress";
    if (status == "resolved" || status == "completed") return "resolved";
    return "pending";
  }

  String _normalizeCategory(dynamic value) {
    final raw = (value?.toString() ?? "").trim();
    final normalized = raw.toLowerCase();

    if (_categoryOrder.contains(raw)) return raw;
    if (normalized == "garbage") return "Garbage Collection";
    if (normalized == "noise") return "Noise Complaint";
    if (normalized == "flooding") return "Drainage Issue";
    if (normalized == "other") return "Others";

    return "Others";
  }

  Future<void> loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reportsResponse = await supabase.from('reports').select();
      final residentsResponse = await supabase.from('residents').select('id');
      final reports = List<Map<String, dynamic>>.from(reportsResponse as List);
      final residents = List<dynamic>.from(residentsResponse as List);

      int pending = 0;
      int progress = 0;
      int resolved = 0;
      final monthData = {for (int month = 1; month <= 12; month++) month: 0};
      final catCounts = {for (final category in _categoryOrder) category: 0};

      for (final row in reports) {
        final status = _normalizeStatus(row['status']);
        if (status == "pending") pending++;
        if (status == "in progress") progress++;
        if (status == "resolved") resolved++;

        final createdAt = DateTime.tryParse(
          row['created_at']?.toString() ?? "",
        );
        if (createdAt != null) {
          monthData[createdAt.month] = (monthData[createdAt.month] ?? 0) + 1;
        }

        final category = _normalizeCategory(row['category']);
        catCounts[category] = (catCounts[category] ?? 0) + 1;
      }

      if (!mounted) return;

      setState(() {
        totalReports = reports.length;
        pendingReports = pending;
        progressReports = progress;
        resolvedReports = resolved;
        totalResidents = residents.length;
        monthlyReports = monthData;
        categoryCounts = catCounts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load analytics. Please try again.";
        _isLoading = false;
      });
    }
  }

  int get _activeReports => pendingReports + progressReports;

  int get _resolutionRate {
    if (totalReports == 0) return 0;
    return ((resolvedReports / totalReports) * 100).round();
  }

  int get _residentReportCoverage {
    if (totalResidents == 0) return 0;
    return ((totalReports / totalResidents) * 100).round();
  }

  String get _topCategory {
    if (categoryCounts.values.every((value) => value == 0)) return "No reports";

    return categoryCounts.entries.reduce((a, b) {
      if (a.value == b.value) return a.key.compareTo(b.key) <= 0 ? a : b;
      return a.value > b.value ? a : b;
    }).key;
  }

  String get _peakMonth {
    final entry = monthlyReports.entries.reduce((a, b) {
      if (a.value == b.value) return a.key < b.key ? a : b;
      return a.value > b.value ? a : b;
    });

    if (entry.value == 0) return "No activity";
    return "${_monthLabel(entry.key)} (${entry.value})";
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final index = (month - 1).clamp(0, 11).toInt();
    return months[index];
  }

  String _categoryShortLabel(String value) {
    switch (value) {
      case "Garbage Collection":
        return "Garbage";
      case "Broken Streetlight":
        return "Streetlight";
      case "Drainage Issue":
        return "Drainage";
      case "Noise Complaint":
        return "Noise";
      default:
        return value;
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _navyColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  "BARANGAY OPERATIONS COMMAND VIEW",
                  style: TextStyle(
                    color: Color(0xFFE8F4FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Community Analytics",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Monitor complaint workload, resident reach, and service pressure across the barangay.",
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          );

          final summary = _HeaderSummary(
            activeReports: _activeReports,
            resolutionRate: _resolutionRate,
            topCategory: _categoryShortLabel(_topCategory),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 18), summary],
            );
          }

          return Row(
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 24),
              summary,
            ],
          );
        },
      ),
    );
  }

  Widget _metricGrid() {
    final items = [
      _MetricData(
        label: "Total Cases",
        value: totalReports.toString(),
        note: "Citizen-submitted reports",
        icon: Icons.assignment_outlined,
        color: _navyColor,
      ),
      _MetricData(
        label: "Pending Review",
        value: pendingReports.toString(),
        note: "Awaiting admin triage",
        icon: Icons.pending_actions_outlined,
        color: _goldColor,
      ),
      _MetricData(
        label: "In Progress",
        value: progressReports.toString(),
        note: "Currently being addressed",
        icon: Icons.sync_outlined,
        color: _blueColor,
      ),
      _MetricData(
        label: "Resolved",
        value: resolvedReports.toString(),
        note: "$_resolutionRate% closure rate",
        icon: Icons.verified_outlined,
        color: _greenColor,
      ),
      _MetricData(
        label: "Residents",
        value: totalResidents.toString(),
        note: "$_residentReportCoverage% report-to-resident ratio",
        icon: Icons.groups_2_outlined,
        color: _tealColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _MetricCard(data: item),
              ),
          ],
        );
      },
    );
  }

  Widget _analyticsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1120;
        final leftWidth = wide
            ? ((constraints.maxWidth - 16) * 0.42)
            : constraints.maxWidth;
        final rightWidth = wide
            ? constraints.maxWidth - leftWidth - 16
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: leftWidth,
              child: _Panel(
                title: "Workload Status",
                subtitle: "Live distribution of complaint handling stages.",
                trailing: _StatusBadge(
                  label: "$_activeReports active",
                  color: _roseColor,
                ),
                child: _statusPanel(),
              ),
            ),
            SizedBox(
              width: rightWidth,
              child: _Panel(
                title: "Monthly Intake",
                subtitle: "Report volume by month for the current dataset.",
                trailing: _StatusBadge(
                  label: "Peak $_peakMonth",
                  color: _blueColor,
                ),
                child: _monthlyBarChart(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusPanel() {
    final total = pendingReports + progressReports + resolvedReports;
    if (total == 0) return const _EmptyState(message: "No report data yet.");

    return SizedBox(
      height: 340,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 54,
                startDegreeOffset: -90,
                sections: [
                  _pieSection(pendingReports, total, _goldColor),
                  _pieSection(progressReports, total, _blueColor),
                  _pieSection(resolvedReports, total, _greenColor),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusRow(
                  label: "Pending review",
                  value: pendingReports,
                  total: total,
                  color: _goldColor,
                ),
                const SizedBox(height: 14),
                _StatusRow(
                  label: "In progress",
                  value: progressReports,
                  total: total,
                  color: _blueColor,
                ),
                const SizedBox(height: 14),
                _StatusRow(
                  label: "Resolved",
                  value: resolvedReports,
                  total: total,
                  color: _greenColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(int value, int total, Color color) {
    final percent = total == 0 ? 0 : ((value / total) * 100).round();

    return PieChartSectionData(
      value: value.toDouble(),
      title: value == 0 ? "" : "$percent%",
      color: color,
      radius: 82,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      badgeWidget: value == 0 ? null : null,
    );
  }

  Widget _monthlyBarChart() {
    final maxValue = monthlyReports.values.fold<int>(0, math.max).toDouble();
    final chartMax = maxValue == 0 ? 4.0 : maxValue + 2.0;
    final horizontalInterval = (chartMax / 4) < 1.0 ? 1.0 : (chartMax / 4);

    return SizedBox(
      height: 340,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: chartMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: horizontalInterval,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFE6EDF4),
              strokeWidth: 1,
              dashArray: [6, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 1,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final month = value.toInt() + 1;
                  if (month < 1 || month > 12) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _monthLabel(month),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF697386),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _navyColor,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${_monthLabel(group.x + 1)}\n${rod.toY.toInt()} reports",
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          barGroups: List.generate(12, (index) {
            final value = (monthlyReports[index + 1] ?? 0).toDouble();
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                  color: value == 0 ? const Color(0xFFE5E7EB) : _tealColor,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _categoryPanel() {
    return _Panel(
      title: "Service Pressure by Category",
      subtitle: "Most common resident concerns requiring barangay attention.",
      trailing: _StatusBadge(
        label: "Top: ${_categoryShortLabel(_topCategory)}",
        color: _tealColor,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final chart = SizedBox(
            height: 330,
            width: wide ? constraints.maxWidth * 0.62 : constraints.maxWidth,
            child: _categoryBarChart(),
          );
          final ranking = SizedBox(
            width: wide ? constraints.maxWidth * 0.30 : constraints.maxWidth,
            child: _CategoryRanking(
              categories: _categoryOrder,
              counts: categoryCounts,
              labelBuilder: _categoryShortLabel,
              maxValue: categoryCounts.values.fold<int>(0, math.max),
            ),
          );

          if (!wide) {
            return Column(
              children: [chart, const SizedBox(height: 18), ranking],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [chart, const Spacer(), ranking],
          );
        },
      ),
    );
  }

  Widget _categoryBarChart() {
    final maxValue = categoryCounts.values.fold<int>(0, math.max).toDouble();
    final chartMax = maxValue == 0 ? 4.0 : maxValue + 2.0;
    final horizontalInterval = (chartMax / 4) < 1.0 ? 1.0 : (chartMax / 4);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: chartMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE6EDF4),
            strokeWidth: 1,
            dashArray: [6, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _categoryOrder.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _categoryShortLabel(_categoryOrder[index]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF697386),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _navyColor,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = _categoryOrder[group.x];
              return BarTooltipItem(
                "$category\n${rod.toY.toInt()} reports",
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        barGroups: List.generate(_categoryOrder.length, (index) {
          final value = (categoryCounts[_categoryOrder[index]] ?? 0).toDouble();
          final color = switch (index) {
            0 => _blueColor,
            1 => _tealColor,
            2 => _goldColor,
            3 => _greenColor,
            4 => _roseColor,
            _ => _navyColor,
          };

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                width: 26,
                borderRadius: BorderRadius.circular(5),
                color: value == 0 ? const Color(0xFFE5E7EB) : color,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _decisionSignals() {
    final signals = [
      _SignalData(
        icon: Icons.fact_check_outlined,
        title: "Backlog posture",
        value: _activeReports == 0 ? "Clear" : "$_activeReports open cases",
        color: _activeReports == 0 ? _greenColor : _roseColor,
      ),
      _SignalData(
        icon: Icons.trending_up_outlined,
        title: "Peak reporting period",
        value: _peakMonth,
        color: _blueColor,
      ),
      _SignalData(
        icon: Icons.location_city_outlined,
        title: "Priority service area",
        value: _categoryShortLabel(_topCategory),
        color: _tealColor,
      ),
      _SignalData(
        icon: Icons.verified_user_outlined,
        title: "Resolution performance",
        value: "$_resolutionRate% closed",
        color: _greenColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final signal in signals)
              SizedBox(
                width: width,
                child: _SignalCard(data: signal),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: _pageBackground,
      child: RefreshIndicator(
        onRefresh: loadAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _metricGrid(),
              const SizedBox(height: 18),
              _analyticsGrid(),
              const SizedBox(height: 18),
              _categoryPanel(),
              const SizedBox(height: 18),
              _decisionSignals(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
}

class _SignalData {
  const _SignalData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
              const Spacer(),
              Text(
                data.value,
                style: TextStyle(
                  color: data.color,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF697386), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF697386),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({
    required this.activeReports,
    required this.resolutionRate,
    required this.topCategory,
  });

  final int activeReports;
  final int resolutionRate;
  final String topCategory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HeaderSummaryItem(label: "Active", value: "$activeReports"),
          ),
          const _HeaderDivider(),
          Expanded(
            child: _HeaderSummaryItem(
              label: "Closed",
              value: "$resolutionRate%",
            ),
          ),
          const _HeaderDivider(),
          Expanded(
            child: _HeaderSummaryItem(label: "Focus", value: topCategory),
          ),
        ],
      ),
    );
  }
}

class _HeaderSummaryItem extends StatelessWidget {
  const _HeaderSummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xBFFFFFFF),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white24,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              "$value",
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: const Color(0xFFE8EEF5),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CategoryRanking extends StatelessWidget {
  const _CategoryRanking({
    required this.categories,
    required this.counts,
    required this.labelBuilder,
    required this.maxValue,
  });

  final List<String> categories;
  final Map<String, int> counts;
  final String Function(String value) labelBuilder;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final category in categories) ...[
          _CategoryRankRow(
            label: labelBuilder(category),
            value: counts[category] ?? 0,
            maxValue: maxValue,
          ),
          if (category != categories.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CategoryRankRow extends StatelessWidget {
  const _CategoryRankRow({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final progress = maxValue == 0 ? 0.0 : value / maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              "$value",
              style: const TextStyle(
                color: Color(0xFF172033),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: const Color(0xFFE8EEF5),
            color: const Color(0xFF1F8A70),
          ),
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.data});

  final _SignalData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF697386),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF697386), fontSize: 13),
        ),
      ),
    );
  }
}
