import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final ReportService reportService = ReportService();
  static const Color _panelBackground = Color(0xFFF5F7FA);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _textColor = Color(0xFF24272D);
  static const Color _mutedColor = Color(0xFF697386);
  static const Color _blueColor = Color(0xFF0087EF);
  static const Color _orangeColor = Color(0xFFE4A000);
  static const Color _greenColor = Color(0xFF29B17E);
  static const double _reportImageWidth = 250;
  late Future<List<Report>> reports;
  final List<String> categoryOptions = const [
    "Road Damage",
    "Garbage Collection",
    "Broken Streetlight",
    "Drainage Issue",
    "Noise Complaint",
    "Others",
  ];

  String searchQuery = "";
  String selectedFilter = "all";
  List<Report> filteredReports = [];

  @override
  void initState() {
    super.initState();
    reports = reportService.fetchReports();
  }

  void refreshReports() {
    setState(() {
      reports = reportService.fetchReports();
    });
  }

  Future<void> _editAdminNote(Report report) async {
    final controller = TextEditingController(text: report.adminNote);

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Admin Note"),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "Add an update or note visible to the resident",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    controller.dispose();

    if (note == null) return;

    try {
      await reportService.updateAdminNote(report.id, note);
      refreshReports();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Admin note updated.")));
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('admin_note')
          ? "Failed to save admin note. Add the admin_note column in Supabase first."
          : "Failed to save admin note: $e";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDeleteReport(Report report) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete report?"),
        content: Text(
          "Are you sure you want to delete this report from ${report.reporterName}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await reportService.deleteReport(report.id);
      refreshReports();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Report deleted.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete report: $e")));
    }
  }

  /// FULLSCREEN IMAGE
  void showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) {
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
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String formatCoordinates(Report report) {
    if (report.latitude == null || report.longitude == null) {
      return "No GPS location";
    }

    return "Lat ${report.latitude!.toStringAsFixed(6)}, Lng ${report.longitude!.toStringAsFixed(6)}";
  }

  List<String> _reportImages(Report report) {
    if (report.imageUrls.isNotEmpty) {
      return report.imageUrls;
    }
    if (report.imageUrl != null && report.imageUrl!.trim().isNotEmpty) {
      return [report.imageUrl!];
    }
    return const [];
  }

  Widget _buildLocationMapPreview(Report report) {
    if (report.latitude == null || report.longitude == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text("No map preview available."),
      );
    }

    final point = LatLng(report.latitude!, report.longitude!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(initialCenter: point, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: 'com.example.barangay_admin_web',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  width: 40,
                  height: 40,
                  point: point,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationMapDialog(Report report) async {
    if (report.latitude == null || report.longitude == null) {
      return;
    }

    final point = LatLng(report.latitude!, report.longitude!);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Report Location",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Pinned at: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}",
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 16,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName:
                              'com.example.barangay_admin_web',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 44,
                              height: 44,
                              point: point,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showReportDetails(Report report) {
    final normalized = normalizeStatus(report.status);
    final images = _reportImages(report);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Report Details"),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => showFullImage(images.first),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        images.first,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Click image to zoom",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (images.length > 1) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final image = images[index];
                          return GestureDetector(
                            onTap: () => showFullImage(image),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                image,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${images.length} images uploaded",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                buildDetailRow(
                  "Description",
                  report.description.trim().isEmpty
                      ? "No description provided"
                      : report.description,
                ),
                buildDetailRow("Reported by", report.reporterName),
                buildDetailRow("Category", normalizeCategory(report.category)),
                buildDetailRow("Status", normalized.toUpperCase()),
                buildDetailRow(
                  "Date",
                  report.createdAt.toLocal().toString().split(' ')[0],
                ),
                buildDetailRow("GPS", formatCoordinates(report)),
                buildDetailRow(
                  "Admin note",
                  report.adminNote.trim().isEmpty
                      ? "No admin note yet."
                      : report.adminNote.trim(),
                ),
                if (report.latitude != null && report.longitude != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showLocationMapDialog(report),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text("Open full map"),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  "Location map",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildLocationMapPreview(report),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editAdminNote(report);
            },
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text("Edit note"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  /// NORMALIZE STATUS
  String normalizeStatus(String status) {
    final s = status.toLowerCase().trim();

    if (s == "pending") return "pending";
    if (s == "in progress") return "in progress";
    if (s == "in_process") return "in progress";
    if (s == "resolved") return "resolved";
    if (s == "completed") return "resolved";

    return "pending";
  }

  String normalizeCategory(String category) {
    final raw = category.trim();
    final normalized = raw.toLowerCase();

    if (normalized == "other") return "Others";
    if (normalized == "garbage") return "Garbage Collection";
    if (normalized == "noise") return "Noise Complaint";
    if (normalized == "flooding") return "Drainage Issue";

    final hasExactMatch = categoryOptions.any((option) => option == raw);
    return hasExactMatch ? raw : "Others";
  }

  /// STATUS BADGE
  Widget buildStatusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "pending":
        return _orangeColor;
      case "in progress":
        return _blueColor;
      case "resolved":
        return _greenColor;
      default:
        return _mutedColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "pending":
        return "Pending";
      case "in progress":
        return "In Progress";
      case "resolved":
        return "Resolved";
      default:
        return status;
    }
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
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? "PM" : "AM";
    return "${months[local.month - 1]} ${local.day}, $hour:$minute $period";
  }

  String _reportTitle(Report report) {
    final text = report.description.trim();
    if (text.isEmpty) return "Untitled community report";
    return text;
  }

  String _reportSummary(Report report) {
    final text = report.description.trim();
    return text.isEmpty ? "No description provided." : text;
  }

  /// STAT CARD
  Widget buildStatCard(String title, int value, Color color) {
    return Container(
      width: 172,
      height: 82,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _mutedColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// FILTER BUTTON
  Widget filterChip(String title, String value) {
    final isActive = selectedFilter == value;

    return SizedBox(
      height: 28,
      child: ChoiceChip(
        label: Text(title),
        selected: isActive,
        showCheckmark: false,
        selectedColor: const Color(0xFFE8F4FF),
        labelStyle: TextStyle(
          color: isActive ? _blueColor : const Color(0xFF4B5563),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide(color: isActive ? _blueColor : _borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: Colors.white,
        onSelected: (_) {
          setState(() {
            selectedFilter = value;
          });
        },
      ),
    );
  }

  Widget _metadataItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _mutedColor),
        const SizedBox(width: 4),
        Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _mutedColor, fontSize: 11),
        ),
      ],
    );
  }

  Widget _selectPill({
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
    required Color backgroundColor,
    Color foregroundColor = const Color(0xFF4B5563),
    Color borderColor = _borderColor,
    double width = 126,
  }) {
    return PopupMenuButton<String>(
      tooltip: "",
      onSelected: onSelected,
      itemBuilder: (context) {
        return options
            .map(
              (option) => PopupMenuItem<String>(
                value: option,
                child: Text(option, style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList();
      },
      child: Container(
        width: width,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 15, color: foregroundColor),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    final currentStatus = normalizeStatus(report.status);
    final images = _reportImages(report);
    final statusColor = _statusColor(currentStatus);
    final category = normalizeCategory(report.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _borderColor),
        ),
        child: InkWell(
          onTap: () => showReportDetails(report),
          hoverColor: const Color(0xFFF8FBFF),
          splashColor: _blueColor.withValues(alpha: 0.08),
          highlightColor: _blueColor.withValues(alpha: 0.04),
          child: SizedBox(
            height: 158,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => showReportDetails(report),
                  child: SizedBox(
                    width: _reportImageWidth,
                    child: images.isEmpty
                        ? Container(
                            color: const Color(0xFFE5E7EB),
                            child: const Icon(
                              Icons.image_outlined,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : Image.network(
                            images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _metadataItem(
                              Icons.schedule_outlined,
                              _shortDate(report.createdAt),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _reportTitle(report),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 16,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _reportSummary(report),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _mutedColor,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _metadataItem(
                          Icons.person_outline,
                          report.reporterName,
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _selectPill(
                              value: category,
                              options: categoryOptions,
                              backgroundColor: Colors.white,
                              width: 126,
                              onSelected: (value) async {
                                await reportService.updateCategory(
                                  report.id,
                                  value,
                                );
                                refreshReports();
                              },
                            ),
                            _selectPill(
                              value: _statusLabel(currentStatus),
                              options: const [
                                "pending",
                                "in progress",
                                "resolved",
                              ],
                              backgroundColor: statusColor.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: statusColor,
                              borderColor: statusColor.withValues(alpha: 0.18),
                              width: 112,
                              onSelected: (value) async {
                                await reportService.updateStatus(
                                  report.id,
                                  value,
                                );
                                refreshReports();
                              },
                            ),
                            TextButton.icon(
                              onPressed: () => _confirmDeleteReport(report),
                              icon: const Icon(Icons.delete_outline, size: 14),
                              label: const Text("Delete"),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEEF2),
                                foregroundColor: const Color(0xFFFF4D6D),
                                fixedSize: const Size(76, 30),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panelBackground,
      body: FutureBuilder<List<Report>>(
        future: reports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reportList = snapshot.data ?? [];

          filteredReports = reportList.where((report) {
            final q = searchQuery.toLowerCase();
            final matchesSearch =
                report.description.toLowerCase().contains(q) ||
                report.reporterName.toLowerCase().contains(q);

            final matchesFilter = selectedFilter == "all"
                ? true
                : normalizeStatus(report.status) == selectedFilter;

            return matchesSearch && matchesFilter;
          }).toList();

          int totalReports = reportList.length;

          int pendingReports = reportList
              .where((r) => normalizeStatus(r.status) == "pending")
              .length;

          int progressReports = reportList
              .where((r) => normalizeStatus(r.status) == "in progress")
              .length;

          int resolvedReports = reportList
              .where((r) => normalizeStatus(r.status) == "resolved")
              .length;

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Active Reports",
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Manage and assign citizen-submitted community issues.",
                  style: TextStyle(color: _mutedColor, fontSize: 11),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    buildStatCard("Total Active", totalReports, _textColor),
                    buildStatCard(
                      "Pending Review",
                      pendingReports,
                      _orangeColor,
                    ),
                    buildStatCard("In Progress", progressReports, _blueColor),
                    buildStatCard("Resolved", resolvedReports, _greenColor),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    filterChip("All", "all"),
                    filterChip("Pending", "pending"),
                    filterChip("In Progress", "in progress"),
                    filterChip("Resolved", "resolved"),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Recent Submissions",
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: reportList.isEmpty
                      ? const Center(child: Text("No reports found."))
                      : filteredReports.isEmpty
                      ? const Center(
                          child: Text(
                            "No reports match your current search/filter.",
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredReports.length,
                          itemBuilder: (context, index) =>
                              _buildReportCard(filteredReports[index]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
