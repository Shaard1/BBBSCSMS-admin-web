import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/report_model.dart';
import '../../services/report_service.dart';

class ReportsMapScreen extends StatefulWidget {
  const ReportsMapScreen({super.key});

  @override
  State<ReportsMapScreen> createState() => _ReportsMapScreenState();
}

class _ReportsMapScreenState extends State<ReportsMapScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _textColor = Color(0xFF172033);
  static const Color _navyColor = Color(0xFF0087EF);
  static const Color _blueColor = Color(0xFF0087EF);
  static const Color _goldColor = Color(0xFFE4A000);
  static const Color _greenColor = Color(0xFF2FB887);
  static const LatLng _barangayCenter = LatLng(9.7392, 118.7353);

  final ReportService reportService = ReportService();
  final MapController _mapController = MapController();

  Future<List<Report>>? _reportsFuture;
  String _selectedStatus = "active";
  String _selectedCategory = "all";
  Report? _selectedReport;

  @override
  void initState() {
    super.initState();
    _reportsFuture = reportService.fetchReports();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _refreshReports() {
    if (!mounted) return;
    setState(() {
      _reportsFuture = reportService.fetchReports();
    });
  }

  String _normalizeStatus(String status) {
    final value = status.toLowerCase().trim();
    if (value == "resolved" || value == "completed") return "resolved";
    if (value == "in progress" || value == "in_process") return "in progress";
    return "pending";
  }

  String _normalizeCategory(String category) {
    final value = category.trim();
    final lower = value.toLowerCase();

    if (lower == "garbage") return "Garbage Collection";
    if (lower == "noise") return "Noise Complaint";
    if (lower == "flooding") return "Drainage Issue";
    if (lower == "other") return "Others";

    const knownCategories = [
      "Road Damage",
      "Garbage Collection",
      "Broken Streetlight",
      "Drainage Issue",
      "Noise Complaint",
      "Others",
    ];

    return knownCategories.contains(value) ? value : "Others";
  }

  List<String> _reportImages(Report report) {
    if (report.imageUrls.isNotEmpty) return report.imageUrls;
    if (report.imageUrl != null && report.imageUrl!.trim().isNotEmpty) {
      return [report.imageUrl!];
    }
    return const [];
  }

  bool _hasLocation(Report report) {
    return report.latitude != null && report.longitude != null;
  }

  bool _matchesStatus(Report report) {
    final status = _normalizeStatus(report.status);
    return switch (_selectedStatus) {
      "active" => status != "resolved",
      "all" => true,
      _ => status == _selectedStatus,
    };
  }

  bool _matchesCategory(Report report) {
    if (_selectedCategory == "all") return true;
    return _normalizeCategory(report.category) == _selectedCategory;
  }

  List<Report> _filterReports(List<Report> reports) {
    return reports
        .where(_hasLocation)
        .where(_matchesStatus)
        .where(_matchesCategory)
        .toList();
  }

  int _countByStatus(List<Report> reports, String status) {
    return reports
        .where((report) => _normalizeStatus(report.status) == status)
        .length;
  }

  String _shortDate(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    final local = date.toLocal();
    return "${months[local.month - 1]} ${local.day}, ${local.year}";
  }

  Color _statusColor(String status) {
    return switch (_normalizeStatus(status)) {
      "resolved" => _greenColor,
      "in progress" => _blueColor,
      _ => _goldColor,
    };
  }

  String _statusLabel(String status) {
    return switch (_normalizeStatus(status)) {
      "resolved" => "Resolved",
      "in progress" => "In Progress",
      _ => "Pending",
    };
  }

  String _categoryLabel(String category) {
    return switch (_normalizeCategory(category)) {
      "Garbage Collection" => "Garbage",
      "Broken Streetlight" => "Streetlight",
      "Drainage Issue" => "Drainage",
      "Noise Complaint" => "Noise",
      final value => value,
    };
  }

  void _selectReport(Report report) {
    if (!_hasLocation(report)) return;
    setState(() {
      _selectedReport = report;
    });
    _mapController.move(LatLng(report.latitude!, report.longitude!), 16);
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteReport(Report report) async {
    try {
      await reportService.deleteReport(report.id);
      if (!mounted) return;
      setState(() {
        if (_selectedReport?.id == report.id) _selectedReport = null;
        _reportsFuture = reportService.fetchReports();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Report deleted.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  List<Marker> _buildMarkers(List<Report> reports) {
    return reports.map((report) {
      final statusColor = _statusColor(report.status);
      final isSelected = _selectedReport?.id == report.id;

      return Marker(
        width: isSelected ? 58 : 48,
        height: isSelected ? 58 : 48,
        point: LatLng(report.latitude!, report.longitude!),
        child: Tooltip(
          message:
              "${_categoryLabel(report.category)} - ${_statusLabel(report.status)}",
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _selectReport(report),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _navyColor : Colors.white,
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(Icons.location_on, color: statusColor, size: 34),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildHeader(List<Report> reports, List<Report> visibleReports) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _navyColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Complaint Map",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Geographic command view for active resident-submitted issues.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _HeaderPill(
            icon: Icons.location_searching_outlined,
            label: "Visible Pins",
            value: "${visibleReports.length}",
          ),
          const SizedBox(width: 10),
          _HeaderPill(
            icon: Icons.assignment_outlined,
            label: "Total Cases",
            value: "${reports.length}",
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: "Refresh map",
            onPressed: _refreshReports,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricStrip(List<Report> reports) {
    final locatedCount = reports.where(_hasLocation).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MapMetric(
          label: "Pending Review",
          value: _countByStatus(reports, "pending").toString(),
          color: _goldColor,
          icon: Icons.pending_actions_outlined,
        ),
        _MapMetric(
          label: "In Progress",
          value: _countByStatus(reports, "in progress").toString(),
          color: _blueColor,
          icon: Icons.sync_outlined,
        ),
        _MapMetric(
          label: "Resolved",
          value: _countByStatus(reports, "resolved").toString(),
          color: _greenColor,
          icon: Icons.verified_outlined,
        ),
        _MapMetric(
          label: "Mapped Reports",
          value: "$locatedCount",
          color: _navyColor,
          icon: Icons.map_outlined,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    const categories = [
      "all",
      "Road Damage",
      "Garbage Collection",
      "Broken Streetlight",
      "Drainage Issue",
      "Noise Complaint",
      "Others",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Filters",
          style: TextStyle(
            color: _textColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: "Active",
              selected: _selectedStatus == "active",
              onTap: () => setState(() => _selectedStatus = "active"),
            ),
            _FilterChip(
              label: "All",
              selected: _selectedStatus == "all",
              onTap: () => setState(() => _selectedStatus = "all"),
            ),
            _FilterChip(
              label: "Pending",
              selected: _selectedStatus == "pending",
              onTap: () => setState(() => _selectedStatus = "pending"),
            ),
            _FilterChip(
              label: "In Progress",
              selected: _selectedStatus == "in progress",
              onTap: () => setState(() => _selectedStatus = "in progress"),
            ),
            _FilterChip(
              label: "Resolved",
              selected: _selectedStatus == "resolved",
              onTap: () => setState(() => _selectedStatus = "resolved"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in categories)
              _FilterChip(
                label: category == "all"
                    ? "All Categories"
                    : _categoryLabel(category),
                selected: _selectedCategory == category,
                onTap: () => setState(() => _selectedCategory = category),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMap(List<Report> visibleReports) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _barangayCenter,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.barangay_admin_web',
              ),
              MarkerLayer(markers: _buildMarkers(visibleReports)),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            child: _MapLegend(
              pendingColor: _goldColor,
              progressColor: _blueColor,
              resolvedColor: _greenColor,
            ),
          ),
          if (visibleReports.isEmpty)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.70),
                alignment: Alignment.center,
                child: const _EmptyMapMessage(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedReportPanel(List<Report> visibleReports) {
    final report = _selectedReport;
    if (report != null && visibleReports.any((item) => item.id == report.id)) {
      return _ReportDetailsPanel(
        report: report,
        statusColor: _statusColor(report.status),
        statusLabel: _statusLabel(report.status),
        categoryLabel: _categoryLabel(report.category),
        dateLabel: _shortDate(report.createdAt),
        images: _reportImages(report),
        onImageTap: _showFullImage,
        onClose: () => setState(() => _selectedReport = null),
        onDelete: () => _deleteReport(report),
      );
    }

    return _ReportQueuePanel(
      reports: visibleReports,
      statusColor: _statusColor,
      statusLabel: _statusLabel,
      categoryLabel: _categoryLabel,
      onSelect: _selectReport,
    );
  }

  Widget _buildContent(List<Report> reports) {
    final visibleReports = _filterReports(reports);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(reports, visibleReports),
          const SizedBox(height: 12),
          _ControlDeck(
            metrics: _buildMetricStrip(reports),
            filters: _buildFilters(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1080;
                final panelWidth = wide ? 330.0 : constraints.maxWidth;

                if (!wide) {
                  return Column(
                    children: [
                      Expanded(child: _buildMap(visibleReports)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 280,
                        width: panelWidth,
                        child: _buildSelectedReportPanel(visibleReports),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _buildMap(visibleReports)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: panelWidth,
                      child: _buildSelectedReportPanel(visibleReports),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBackground,
      child: FutureBuilder<List<Report>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MapErrorState(onRetry: _refreshReports);
          }

          return _buildContent(snapshot.data ?? const []);
        },
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
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
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlDeck extends StatelessWidget {
  const _ControlDeck({required this.metrics, required this.filters});

  final Widget metrics;
  final Widget filters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1180) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [metrics, const SizedBox(height: 16), filters],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 720, child: metrics),
              const SizedBox(width: 22),
              Container(width: 1, height: 126, color: const Color(0xFFE5E7EB)),
              const SizedBox(width: 22),
              Expanded(child: filters),
            ],
          );
        },
      ),
    );
  }
}

class _MapMetric extends StatelessWidget {
  const _MapMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 70,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF697386),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: const Color(0xFFE8F4FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? const Color(0xFF0087EF) : const Color(0xFFE5E7EB),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0087EF) : const Color(0xFF4B5563),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.pendingColor,
    required this.progressColor,
    required this.resolvedColor,
  });

  final Color pendingColor;
  final Color progressColor;
  final Color resolvedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "PIN STATUS",
            style: TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 9),
          _LegendItem(label: "Pending", color: pendingColor),
          const SizedBox(height: 7),
          _LegendItem(label: "In Progress", color: progressColor),
          const SizedBox(height: 7),
          _LegendItem(label: "Resolved", color: resolvedColor),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF172033), fontSize: 11),
        ),
      ],
    );
  }
}

class _ReportQueuePanel extends StatelessWidget {
  const _ReportQueuePanel({
    required this.reports,
    required this.statusColor,
    required this.statusLabel,
    required this.categoryLabel,
    required this.onSelect,
  });

  final List<Report> reports;
  final Color Function(String status) statusColor;
  final String Function(String status) statusLabel;
  final String Function(String category) categoryLabel;
  final ValueChanged<Report> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Mapped Complaint Queue",
            style: TextStyle(
              color: Color(0xFF172033),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Select a map pin or queue item to inspect complaint details.",
            style: TextStyle(color: Color(0xFF697386), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: reports.isEmpty
                ? const Center(
                    child: Text("No mapped reports match this view."),
                  )
                : ListView.separated(
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return _QueueItem(
                        report: report,
                        statusColor: statusColor(report.status),
                        statusLabel: statusLabel(report.status),
                        categoryLabel: categoryLabel(report.category),
                        onTap: () => onSelect(report),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    required this.report,
    required this.statusColor,
    required this.statusLabel,
    required this.categoryLabel,
    required this.onTap,
  });

  final Report report;
  final Color statusColor;
  final String statusLabel;
  final String categoryLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = report.description.trim().isEmpty
        ? "No description provided."
        : report.description.trim();

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      categoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _TinyStatus(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF697386),
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDetailsPanel extends StatelessWidget {
  const _ReportDetailsPanel({
    required this.report,
    required this.statusColor,
    required this.statusLabel,
    required this.categoryLabel,
    required this.dateLabel,
    required this.images,
    required this.onImageTap,
    required this.onClose,
    required this.onDelete,
  });

  final Report report;
  final Color statusColor;
  final String statusLabel;
  final String categoryLabel;
  final String dateLabel;
  final List<String> images;
  final ValueChanged<String> onImageTap;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final description = report.description.trim().isEmpty
        ? "No description provided."
        : report.description.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: "Close details",
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyStatus(label: statusLabel, color: statusColor),
              _TinyStatus(label: dateLabel, color: const Color(0xFF0087EF)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty)
                    _PrimaryImage(imageUrl: images.first, onTap: onImageTap),
                  if (images.length > 1) ...[
                    const SizedBox(height: 10),
                    _ImageStrip(
                      images: images.skip(1).toList(),
                      onTap: onImageTap,
                    ),
                  ],
                  if (images.isNotEmpty) const SizedBox(height: 14),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailLabelValue(
                    label: "Reported by",
                    value: report.reporterName,
                  ),
                  _DetailLabelValue(
                    label: "GPS",
                    value:
                        "Lat ${report.latitude!.toStringAsFixed(6)}, Lng ${report.longitude!.toStringAsFixed(6)}",
                  ),
                  if (report.adminNote.trim().isNotEmpty)
                    _DetailLabelValue(
                      label: "Admin note",
                      value: report.adminNote.trim(),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5B78),
                        side: const BorderSide(color: Color(0xFFFFD1DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Delete Report"),
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

class _PrimaryImage extends StatelessWidget {
  const _PrimaryImage({required this.imageUrl, required this.onTap});

  final String imageUrl;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 200,
          height: 166,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 200,
            height: 166,
            color: const Color(0xFFE5E7EB),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.images, required this.onTap});

  final List<String> images;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = images[index];
          return GestureDetector(
            onTap: () => onTap(image),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                image,
                width: 76,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 76,
                  height: 68,
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailLabelValue extends StatelessWidget {
  const _DetailLabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF697386),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyStatus extends StatelessWidget {
  const _TinyStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyMapMessage extends StatelessWidget {
  const _EmptyMapMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, color: Color(0xFF697386), size: 32),
          SizedBox(height: 8),
          Text(
            "No mapped complaints match the selected filters.",
            style: TextStyle(
              color: Color(0xFF172033),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapErrorState extends StatelessWidget {
  const _MapErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Failed to load complaint map data."),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFE5E7EB)),
    boxShadow: const [
      BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6)),
    ],
  );
}
