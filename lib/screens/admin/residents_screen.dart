import 'package:flutter/material.dart';
import '../../models/resident_model.dart';
import '../../services/resident_service.dart';

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _textColor = Color(0xFF24272D);
  static const Color _mutedColor = Color(0xFF697386);
  static const Color _blueColor = Color(0xFF0087EF);
  static const Color _borderColor = Color(0xFFE5E7EB);
  final ResidentService residentService = ResidentService();
  final TextEditingController _searchController = TextEditingController();
  final List<String> rejectionOptions = const [
    "Invalid ID",
    "Blurry ID photo",
    "Incomplete information",
    "Address cannot be verified",
    "Not a barangay resident",
  ];

  List<Resident> residents = [];
  bool loading = true;
  String _selectedFilter = "all";
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadResidents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future loadResidents() async {
    residents = await residentService.fetchResidents();
    setState(() {
      loading = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approveResident(Resident resident) async {
    try {
      await residentService.approveResident(resident.id);
      await loadResidents();

      if (!mounted) return;
      _showMessage("${resident.fullName} was approved.");
    } catch (e) {
      if (!mounted) return;
      _showMessage("Approval failed: $e");
    }
  }

  Future<void> _rejectResident(Resident resident, String reason) async {
    try {
      await residentService.rejectResident(resident.id, reason.trim());
      await loadResidents();

      if (!mounted) return;
      _showMessage("${resident.fullName} was rejected.");
    } catch (e) {
      if (!mounted) return;
      _showMessage("Rejection failed: $e");
    }
  }

  Future<void> _showRejectDialog(Resident resident) async {
    String? selectedReason;
    final otherReasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasOtherReason = selectedReason == 'Other';
            final isConfirmEnabled = hasOtherReason
                ? otherReasonController.text.trim().isNotEmpty
                : selectedReason != null;

            return AlertDialog(
              title: Text("Reject ${resident.fullName}?"),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Select a reason for rejection:"),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in rejectionOptions)
                          ChoiceChip(
                            label: Text(option),
                            selected: selectedReason == option,
                            onSelected: (_) {
                              setDialogState(() {
                                selectedReason = option;
                              });
                            },
                          ),
                        ChoiceChip(
                          label: const Text("Other"),
                          selected: hasOtherReason,
                          onSelected: (_) {
                            setDialogState(() {
                              selectedReason = 'Other';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otherReasonController,
                      enabled: hasOtherReason,
                      maxLines: 3,
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                      decoration: const InputDecoration(
                        labelText: "Custom reason",
                        hintText: "Explain why this registration was rejected",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isConfirmEnabled
                      ? () {
                          final value = hasOtherReason
                              ? otherReasonController.text.trim()
                              : selectedReason!;
                          Navigator.pop(dialogContext, value);
                        }
                      : null,
                  child: const Text("Reject"),
                ),
              ],
            );
          },
        );
      },
    );

    otherReasonController.dispose();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    await _rejectResident(resident, reason);
  }

  Future<bool> _confirmApproveResident(Resident resident) async {
    final shouldApprove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Approve resident?"),
          content: Text(
            "Are you sure you want to approve ${resident.fullName}?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Approve"),
            ),
          ],
        );
      },
    );

    return shouldApprove ?? false;
  }

  String _displayValue(String value) {
    return value.trim().isEmpty ? 'Not provided' : value.trim();
  }

  String _formatDate(String value) {
    if (value.trim().isEmpty) {
      return 'Not provided';
    }

    final parsedDate = DateTime.tryParse(value);
    if (parsedDate == null) {
      return value;
    }

    return "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(_displayValue(value))),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String title, String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl.trim().isEmpty
              ? const Center(child: Text("No image uploaded"))
              : InkWell(
                  onTap: () => _showImageViewer(title, imageUrl),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) {
                            return const Center(
                              child: Text("Unable to load image"),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (imageUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            "Click image to zoom",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }

  Future<void> _showImageViewer(String title, String imageUrl) async {
    final transformController = TransformationController();

    double zoomScale = 1.0;

    void applyScale(double nextScale) {
      zoomScale = nextScale.clamp(1.0, 5.0);
      transformController.value = Matrix4.diagonal3Values(
        zoomScale,
        zoomScale,
        1,
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 980,
                  maxHeight: 760,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.05),
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            transformationController: transformController,
                            child: Center(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) {
                                  return const Text("Unable to load image");
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                applyScale(1.0);
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text("Reset"),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: "Zoom out",
                            onPressed: () {
                              setDialogState(() {
                                applyScale(zoomScale - 0.5);
                              });
                            },
                            icon: const Icon(Icons.zoom_out),
                          ),
                          IconButton(
                            tooltip: "Zoom in",
                            onPressed: () {
                              setDialogState(() {
                                applyScale(zoomScale + 0.5);
                              });
                            },
                            icon: const Icon(Icons.zoom_in),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    transformController.dispose();
  }

  Future<void> _showResidentDetailsDialog(
    Resident resident, {
    required bool showActionButtons,
  }) async {
    final profileImageForReview =
        resident.profileImageOriginal.trim().isNotEmpty
        ? resident.profileImageOriginal
        : resident.profileImage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final normalizedStatus = _normalizedStatus(resident);
        final statusLabel = _statusLabel(resident);
        final statusBg = normalizedStatus == "approved"
            ? const Color(0xFFE8F5EE)
            : normalizedStatus == "flagged"
            ? const Color(0xFFFDECEC)
            : const Color(0xFFF6EFD9);
        final statusFg = normalizedStatus == "approved"
            ? const Color(0xFF1F7A45)
            : normalizedStatus == "flagged"
            ? const Color(0xFFB3261E)
            : const Color(0xFF9B6A00);

        Widget detailTile(String label, String value) {
          return Container(
            width: 430,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7ECF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6A7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _displayValue(value),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980, maxHeight: 780),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE7ECF3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resident.fullName,
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              showActionButtons
                                  ? "Review resident registration details before approval."
                                  : "View resident registration details.",
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusFg,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Color(0xFF4B5563)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              detailTile(
                                "Submitted on",
                                _formatDate(resident.createdAt),
                              ),
                              detailTile("Status", resident.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              detailTile("Full name", resident.fullName),
                              detailTile("Birthdate", _formatDate(resident.birthdate)),
                              detailTile("Gender", resident.gender),
                              detailTile("Civil status", resident.civilStatus),
                              detailTile("Address", resident.address),
                              detailTile("Contact number", resident.contactNumber),
                              detailTile("ID type", resident.idType),
                              detailTile("Rejection reason", resident.rejectionReason),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: 290,
                                child: _buildImagePreview(
                                  "Profile image",
                                  profileImageForReview,
                                ),
                              ),
                              SizedBox(
                                width: 290,
                                child: _buildImagePreview(
                                  "ID image (Front)",
                                  resident.idImageFront,
                                ),
                              ),
                              SizedBox(
                                width: 290,
                                child: _buildImagePreview(
                                  "ID image (Back)",
                                  resident.idImageBack,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: const Text("Close"),
                      ),
                      if (showActionButtons) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            await _showRejectDialog(resident);
                          },
                          child: const Text("Reject"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006CBF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            final shouldApprove = await _confirmApproveResident(
                              resident,
                            );

                            if (!shouldApprove) {
                              return;
                            }

                            await _approveResident(resident);
                          },
                          child: const Text("Approve"),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _normalizedStatus(Resident resident) {
    final status = resident.status.toLowerCase().trim();
    if (status == "rejected") return "flagged";
    if (status == "approved") return "approved";
    return "pending";
  }

  String _statusLabel(Resident resident) {
    switch (_normalizedStatus(resident)) {
      case "approved":
        return "Approved";
      case "flagged":
        return "Flagged";
      default:
        return "Pending";
    }
  }

  bool _matchesFilter(Resident resident) {
    if (_selectedFilter == "all") return true;
    return _normalizedStatus(resident) == _selectedFilter;
  }

  bool _matchesSearch(Resident resident) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    return resident.fullName.toLowerCase().contains(query) ||
        resident.id.toLowerCase().contains(query) ||
        resident.address.toLowerCase().contains(query) ||
        resident.contactNumber.toLowerCase().contains(query) ||
        resident.idType.toLowerCase().contains(query);
  }

  String _formatSubmittedAt(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return _displayValue(value);

    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    final hour = parsed.hour == 0
        ? 12
        : parsed.hour > 12
        ? parsed.hour - 12
        : parsed.hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? "PM" : "AM";
    return "${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}\n$hour:$minute $period";
  }

  Widget _filterButton(String title, String value) {
    final isActive = _selectedFilter == value;

    return SizedBox(
      height: 36,
      child: ChoiceChip(
        label: Text(title),
        selected: isActive,
        showCheckmark: false,
        selectedColor: const Color(0xFFE8F4FF),
        backgroundColor: Colors.white,
        side: BorderSide(color: isActive ? _blueColor : _borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: TextStyle(
          color: isActive ? _blueColor : const Color(0xFF4B5563),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        onSelected: (_) {
          setState(() {
            _selectedFilter = value;
          });
        },
      ),
    );
  }

  Widget _residentSearchField() {
    return SizedBox(
      width: 360,
      height: 42,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        decoration: InputDecoration(
          hintText: "Search residents, ID, address...",
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: Color(0xFF64748B),
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: "Clear search",
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                  icon: const Icon(Icons.close, size: 16),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _blueColor),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(Resident resident) {
    final status = _normalizedStatus(resident);
    final color = switch (status) {
      "approved" => const Color(0xFF2FB887),
      "flagged" => const Color(0xFFFF5B78),
      _ => const Color(0xFFE6A000),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == "flagged"
                ? Icons.error_outline
                : status == "pending"
                ? Icons.schedule
                : Icons.verified_outlined,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _statusLabel(resident),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _residentAvatar(Resident resident) {
    final image = resident.profileImage.trim();
    if (image.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(image),
        backgroundColor: const Color(0xFFE8F4FF),
      );
    }

    final initials = resident.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFE8F4FF),
      child: Text(
        initials.isEmpty ? "R" : initials,
        style: const TextStyle(
          color: _blueColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: const Color(0xFF4B5563),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 38),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFE9EDF2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(flex: 4, child: _HeaderText("RESIDENT APPLICANT")),
          Expanded(flex: 3, child: _HeaderText("DATE SUBMITTED")),
          Expanded(flex: 3, child: _HeaderText("DOC STATUS")),
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerRight,
              child: _HeaderText("ACTIONS"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _residentRow(Resident resident) {
    final showActionButtons = _normalizedStatus(resident) == "pending";

    return Container(
      height: 92,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showResidentDetailsDialog(
            resident,
            showActionButtons: showActionButtons,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      _residentAvatar(resident),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resident.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "ID: REG-${resident.id.length > 8 ? resident.id.substring(0, 8) : resident.id}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _mutedColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatSubmittedAt(resident.createdAt),
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _statusBadge(resident),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EDF2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionButton(
                            icon: Icons.check,
                            onPressed: () async {
                              final shouldApprove =
                                  await _confirmApproveResident(resident);
                              if (!shouldApprove) return;
                              await _approveResident(resident);
                            },
                          ),
                          _actionButton(
                            icon: Icons.close,
                            onPressed: () => _showRejectDialog(resident),
                          ),
                        ],
                      ),
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
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredResidents = residents
        .where(_matchesFilter)
        .where(_matchesSearch)
        .toList();

    return ColoredBox(
      color: _pageBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Resident Verification",
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Review and process new community registrations to ensure accurate demographic records.",
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 14),
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _filterButton("All", "all"),
                          _filterButton("Pending", "pending"),
                          _filterButton("Approved", "approved"),
                          _filterButton("Flagged", "flagged"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _residentSearchField(),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  "Recent Submissions",
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _tableHeader(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: filteredResidents.isEmpty
                  ? const Center(
                      child: Text("No resident submissions match this view."),
                    )
                  : ListView.builder(
                      itemCount: filteredResidents.length,
                      itemBuilder: (context, index) {
                        return _residentRow(filteredResidents[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
