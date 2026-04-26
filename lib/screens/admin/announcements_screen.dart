import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/announcement_model.dart';
import '../../services/announcement_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementSegment {
  final String text;
  final Map<String, dynamic> attributes;

  const _AnnouncementSegment({required this.text, required this.attributes});
}

class _AnnouncementLine {
  final List<_AnnouncementSegment> segments;
  final String? align;

  const _AnnouncementLine({required this.segments, this.align});
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const Color _primaryBlue = Color(0xFF0087EF);

  final SupabaseClient _supabase = Supabase.instance.client;
  final AnnouncementService announcementService = AnnouncementService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _announcementSearchController =
      TextEditingController();

  static const int _maxAnnouncementImages = 8;
  static const int _minFontSize = 1;
  static const int _maxFontSizeValue = 144;
  bool _isSubmitting = false;
  bool _isPublished = true;
  int _announcementSectionIndex = 0;
  int _selectedFontSize = 16;
  List<Announcement> _announcements = [];
  bool _loading = true;
  XFile? _thumbnailFile;
  final List<XFile> _announcementImageFiles = [];
  String _announcementSearchQuery = "";
  String _announcementStatusFilter = "all";

  int get _publishedCount =>
      _announcements.where((item) => item.isPublished).length;

  int get _draftCount =>
      _announcements.where((item) => !item.isPublished).length;

  List<Announcement> get _visibleAnnouncements {
    final query = _announcementSearchQuery.trim().toLowerCase();

    return _announcements.where((announcement) {
      final matchesStatus = switch (_announcementStatusFilter) {
        "published" => announcement.isPublished,
        "draft" => !announcement.isPublished,
        _ => true,
      };

      final matchesSearch =
          query.isEmpty ||
          announcement.title.toLowerCase().contains(query) ||
          announcement.plainText.toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _announcementSearchController.dispose();
    super.dispose();
  }

  List<_AnnouncementLine> _parseAnnouncementLines(String rawContent) {
    final trimmed = rawContent.trim();
    final ops = <Map<String, dynamic>>[];

    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              ops.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {}
    }

    if (ops.isEmpty) {
      return _parseMarkupAnnouncementLines(rawContent);
    }

    return _buildAnnouncementLinesFromOps(ops);
  }

  List<_AnnouncementLine> _buildAnnouncementLinesFromOps(
    List<Map<String, dynamic>> ops,
  ) {
    final lines = <_AnnouncementLine>[];
    final currentSegments = <_AnnouncementSegment>[];

    void pushLine([String? align]) {
      lines.add(
        _AnnouncementLine(
          segments: List<_AnnouncementSegment>.from(currentSegments),
          align: align,
        ),
      );
      currentSegments.clear();
    }

    for (final op in ops) {
      final insert = op['insert'];
      final attributes = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};

      if (insert is! String) continue;

      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isNotEmpty) {
          currentSegments.add(
            _AnnouncementSegment(text: part, attributes: attributes),
          );
        }

        if (i < parts.length - 1) {
          pushLine(attributes['align']?.toString());
        }
      }
    }

    if (currentSegments.isNotEmpty) {
      pushLine();
    }

    return lines;
  }

  List<_AnnouncementLine> _parseMarkupAnnouncementLines(String rawContent) {
    final lines = <_AnnouncementLine>[];
    final currentSegments = <_AnnouncementSegment>[];
    final tagPattern = RegExp(
      r'\[(\/?)(b|i|u|s|size|align)\b(?:=([^\]]+))?\]',
      caseSensitive: false,
    );

    final boldStack = <bool>[];
    final italicStack = <bool>[];
    final underlineStack = <bool>[];
    final strikeStack = <bool>[];
    final sizeStack = <String?>[];
    final alignStack = <String?>[];

    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool strike = false;
    String? size;
    String? align;

    Map<String, dynamic> currentAttributes() {
      final attributes = <String, dynamic>{};
      if (bold) attributes['bold'] = true;
      if (italic) attributes['italic'] = true;
      if (underline) attributes['underline'] = true;
      if (strike) attributes['strike'] = true;
      if (size != null && size.isNotEmpty) {
        attributes['size'] = size;
      }
      return attributes;
    }

    void pushLine() {
      lines.add(
        _AnnouncementLine(
          segments: List<_AnnouncementSegment>.from(currentSegments),
          align: align,
        ),
      );
      currentSegments.clear();
    }

    void appendText(String text) {
      final normalized = text.replaceAll('\r\n', '\n');
      final parts = normalized.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          currentSegments.add(
            _AnnouncementSegment(
              text: parts[i],
              attributes: currentAttributes(),
            ),
          );
        }
        if (i < parts.length - 1) {
          pushLine();
        }
      }
    }

    var cursor = 0;
    for (final match in tagPattern.allMatches(rawContent)) {
      if (match.start > cursor) {
        appendText(rawContent.substring(cursor, match.start));
      }

      final isClosing = match.group(1) == '/';
      final tag = (match.group(2) ?? '').toLowerCase();
      final value = match.group(3)?.trim();

      if (!isClosing) {
        switch (tag) {
          case 'b':
            boldStack.add(bold);
            bold = true;
            break;
          case 'i':
            italicStack.add(italic);
            italic = true;
            break;
          case 'u':
            underlineStack.add(underline);
            underline = true;
            break;
          case 's':
            strikeStack.add(strike);
            strike = true;
            break;
          case 'size':
            sizeStack.add(size);
            final parsedSize = int.tryParse(value ?? '');
            if (parsedSize != null) {
              size = parsedSize
                  .clamp(_minFontSize, _maxFontSizeValue)
                  .toString();
            }
            break;
          case 'align':
            alignStack.add(align);
            final normalizedAlign = value?.toLowerCase();
            if (normalizedAlign == 'center' ||
                normalizedAlign == 'right' ||
                normalizedAlign == 'justify') {
              align = normalizedAlign;
            } else {
              align = 'left';
            }
            break;
        }
      } else {
        switch (tag) {
          case 'b':
            bold = boldStack.isNotEmpty ? boldStack.removeLast() : false;
            break;
          case 'i':
            italic = italicStack.isNotEmpty ? italicStack.removeLast() : false;
            break;
          case 'u':
            underline = underlineStack.isNotEmpty
                ? underlineStack.removeLast()
                : false;
            break;
          case 's':
            strike = strikeStack.isNotEmpty ? strikeStack.removeLast() : false;
            break;
          case 'size':
            size = sizeStack.isNotEmpty ? sizeStack.removeLast() : null;
            break;
          case 'align':
            align = alignStack.isNotEmpty ? alignStack.removeLast() : null;
            break;
        }
      }

      cursor = match.end;
    }

    if (cursor < rawContent.length) {
      appendText(rawContent.substring(cursor));
    }

    if (currentSegments.isNotEmpty) {
      pushLine();
    }

    return lines;
  }

  String _contentToEditableText(String rawContent) {
    final trimmed = rawContent.trim();
    if (!trimmed.startsWith('[')) {
      return rawContent;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return rawContent;
      final lines = _buildAnnouncementLinesFromOps(
        decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );

      final buffer = StringBuffer();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final lineText = line.segments.map(_segmentToMarkupText).join();
        if ((line.align ?? '').isNotEmpty && line.align != 'left') {
          buffer.write('[align=${line.align}]$lineText[/align]');
        } else {
          buffer.write(lineText);
        }
        if (index != lines.length - 1) {
          buffer.writeln();
        }
      }
      return buffer.toString();
    } catch (_) {
      return rawContent;
    }
  }

  String _segmentToMarkupText(_AnnouncementSegment segment) {
    var text = segment.text;
    final attributes = segment.attributes;

    final size = attributes['size']?.toString();
    if (size != null && size.isNotEmpty) {
      text = '[size=$size]$text[/size]';
    }
    if (attributes['strike'] == true) {
      text = '[s]$text[/s]';
    }
    if (attributes['underline'] == true) {
      text = '[u]$text[/u]';
    }
    if (attributes['italic'] == true) {
      text = '[i]$text[/i]';
    }
    if (attributes['bold'] == true) {
      text = '[b]$text[/b]';
    }

    return text;
  }

  Color? _parseAnnouncementColor(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;

    final hex = text.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return null;
  }

  TextStyle _announcementSegmentStyle(Map<String, dynamic> attributes) {
    var decoration = TextDecoration.none;
    if (attributes['underline'] == true) {
      decoration = TextDecoration.underline;
    }
    if (attributes['strike'] == true) {
      decoration = decoration == TextDecoration.none
          ? TextDecoration.lineThrough
          : TextDecoration.combine([decoration, TextDecoration.lineThrough]);
    }

    final fontSize = double.tryParse(attributes['size']?.toString() ?? '');

    return TextStyle(
      color:
          _parseAnnouncementColor(attributes['color']) ??
          const Color(0xFF374151),
      fontSize: fontSize ?? 15,
      height: 1.6,
      fontWeight: attributes['bold'] == true
          ? FontWeight.w700
          : FontWeight.w400,
      fontStyle: attributes['italic'] == true
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: decoration,
    );
  }

  TextAlign _announcementTextAlign(String? align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  Widget _buildAnnouncementContentView(String rawContent) {
    final lines = _parseAnnouncementLines(rawContent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            SelectableText.rich(
              TextSpan(
                children: lines[index].segments
                    .map(
                      (segment) => TextSpan(
                        text: segment.text,
                        style: _announcementSegmentStyle(segment.attributes),
                      ),
                    )
                    .toList(),
              ),
              textAlign: _announcementTextAlign(lines[index].align),
            ),
            if (index != lines.length - 1) const SizedBox(height: 6),
          ],
          if (lines.isEmpty)
            const Text(
              "No announcement details available.",
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
        ],
      ),
    );
  }

  Future<void> _loadAnnouncements() async {
    try {
      final announcements = await announcementService.fetchAnnouncements();
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
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
    return "${months[local.month - 1]} ${local.day}, ${local.year}";
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _replaceControllerRange(
    TextEditingController controller, {
    required int start,
    required int end,
    required String replacement,
    required TextSelection selection,
  }) {
    final newText = controller.text.replaceRange(start, end, replacement);
    controller.value = TextEditingValue(
      text: newText,
      selection: selection,
      composing: TextRange.empty,
    );
  }

  void _wrapSelectionWithTags(
    TextEditingController controller, {
    required String openTag,
    required String closeTag,
    String placeholder = 'text',
  }) {
    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    if (start < 0 || end < 0) return;

    if (selection.isCollapsed) {
      final replacement = '$openTag$placeholder$closeTag';
      _replaceControllerRange(
        controller,
        start: start,
        end: end,
        replacement: replacement,
        selection: TextSelection(
          baseOffset: start + openTag.length,
          extentOffset: start + openTag.length + placeholder.length,
        ),
      );
      return;
    }

    final selectedText = text.substring(start, end);
    final replacement = '$openTag$selectedText$closeTag';
    _replaceControllerRange(
      controller,
      start: start,
      end: end,
      replacement: replacement,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + replacement.length,
      ),
    );
  }

  TextRange _expandSelectionToFullLines(TextEditingController controller) {
    final selection = controller.selection;
    final text = controller.text;
    if (text.isEmpty) {
      return const TextRange(start: 0, end: 0);
    }

    final safeStart = selection.isValid
        ? selection.start.clamp(0, text.length).toInt()
        : 0;
    final safeEnd = selection.isValid
        ? selection.end.clamp(0, text.length).toInt()
        : text.length;

    final startLineBreak = text.lastIndexOf('\n', safeStart - 1);
    final endLineBreak = text.indexOf('\n', safeEnd);

    final blockStart = startLineBreak == -1 ? 0 : startLineBreak + 1;
    final blockEnd = endLineBreak == -1 ? text.length : endLineBreak;
    return TextRange(start: blockStart, end: blockEnd);
  }

  void _applyBullets(TextEditingController controller) {
    final range = _expandSelectionToFullLines(controller);
    final block = controller.text.substring(range.start, range.end);
    final lines = block.split('\n');
    final allBulleted = lines
        .where((line) => line.trim().isNotEmpty)
        .every((line) => line.trimLeft().startsWith('- '));

    final transformed = lines
        .map((line) {
          if (line.trim().isEmpty) return line;
          if (allBulleted) {
            final index = line.indexOf('- ');
            return index >= 0
                ? '${line.substring(0, index)}${line.substring(index + 2)}'
                : line;
          }
          return line.trimLeft().startsWith('- ') ? line : '- $line';
        })
        .join('\n');

    _replaceControllerRange(
      controller,
      start: range.start,
      end: range.end,
      replacement: transformed,
      selection: TextSelection(
        baseOffset: range.start,
        extentOffset: range.start + transformed.length,
      ),
    );
  }

  void _applyAlignment(TextEditingController controller, String align) {
    final range = _expandSelectionToFullLines(controller);
    final block = controller.text.substring(range.start, range.end).trim();
    final existingPattern = RegExp(
      r'^\[align=(left|center|right|justify)\]([\s\S]*)\[/align\]$',
      caseSensitive: false,
    );
    final existingMatch = existingPattern.firstMatch(block);
    final coreText = existingMatch?.group(2)?.trim() ?? block;
    final replacement = align == 'left'
        ? coreText
        : '[align=$align]$coreText[/align]';

    _replaceControllerRange(
      controller,
      start: range.start,
      end: range.end,
      replacement: replacement,
      selection: TextSelection(
        baseOffset: range.start,
        extentOffset: range.start + replacement.length,
      ),
    );
  }

  void _applyFontSizeToSelection(
    TextEditingController controller,
    int fontSize,
  ) {
    _wrapSelectionWithTags(
      controller,
      openTag: '[size=$fontSize]',
      closeTag: '[/size]',
    );
  }

  void _increaseFontSize() {
    setState(() {
      _selectedFontSize = (_selectedFontSize + 1)
          .clamp(_minFontSize, _maxFontSizeValue)
          .toInt();
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _selectedFontSize = (_selectedFontSize - 1)
          .clamp(_minFontSize, _maxFontSizeValue)
          .toInt();
    });
  }

  Widget _buildFormatButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD9E2E7)),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeStepper({
    required int fontSize,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    required VoidCallback onApply,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E2E7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease font size',
            visualDensity: VisualDensity.compact,
            onPressed: onDecrease,
            icon: const Icon(Icons.remove, size: 18),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onApply,
            child: SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  '$fontSize',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Increase font size',
            visualDensity: VisualDensity.compact,
            onPressed: onIncrease,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattingToolbar({
    required TextEditingController controller,
    required int fontSize,
    required VoidCallback onDecreaseFontSize,
    required VoidCallback onIncreaseFontSize,
    required VoidCallback onApplyFontSize,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select text, then apply formatting. The live preview below shows how residents will see it.",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFontSizeStepper(
                  fontSize: fontSize,
                  onDecrease: onDecreaseFontSize,
                  onIncrease: onIncreaseFontSize,
                  onApply: onApplyFontSize,
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Bold',
                  icon: Icons.format_bold,
                  onPressed: () => _wrapSelectionWithTags(
                    controller,
                    openTag: '[b]',
                    closeTag: '[/b]',
                  ),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Italic',
                  icon: Icons.format_italic,
                  onPressed: () => _wrapSelectionWithTags(
                    controller,
                    openTag: '[i]',
                    closeTag: '[/i]',
                  ),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Underline',
                  icon: Icons.format_underlined,
                  onPressed: () => _wrapSelectionWithTags(
                    controller,
                    openTag: '[u]',
                    closeTag: '[/u]',
                  ),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Strikethrough',
                  icon: Icons.format_strikethrough,
                  onPressed: () => _wrapSelectionWithTags(
                    controller,
                    openTag: '[s]',
                    closeTag: '[/s]',
                  ),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Bullets',
                  icon: Icons.format_list_bulleted,
                  onPressed: () => _applyBullets(controller),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Align left',
                  icon: Icons.format_align_left,
                  onPressed: () => _applyAlignment(controller, 'left'),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Align center',
                  icon: Icons.format_align_center,
                  onPressed: () => _applyAlignment(controller, 'center'),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Align right',
                  icon: Icons.format_align_right,
                  onPressed: () => _applyAlignment(controller, 'right'),
                ),
                const SizedBox(width: 8),
                _buildFormatButton(
                  tooltip: 'Justify',
                  icon: Icons.format_align_justify,
                  onPressed: () => _applyAlignment(controller, 'justify'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryBlue, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF142329),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF667680),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  BoxDecoration _announcementPanelDecoration() {
    return BoxDecoration(
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
    );
  }

  InputDecoration _announcementInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD9E2E7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryBlue),
      ),
    );
  }

  Widget _announcementSearchField() {
    return SizedBox(
      width: 320,
      height: 40,
      child: TextField(
        controller: _announcementSearchController,
        style: const TextStyle(fontSize: 13),
        onChanged: (value) {
          setState(() => _announcementSearchQuery = value);
        },
        decoration: InputDecoration(
          hintText: "Search announcements...",
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: Color(0xFF64748B),
          ),
          suffixIcon: _announcementSearchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: "Clear search",
                  onPressed: () {
                    _announcementSearchController.clear();
                    setState(() => _announcementSearchQuery = "");
                  },
                  icon: const Icon(Icons.close, size: 16),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _primaryBlue),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    Color backgroundColor = const Color(0xFFF4F7F8),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667680),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickThumbnail() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() {
      _thumbnailFile = picked;
    });
  }

  Future<void> _pickAnnouncementImages() async {
    final remainingSlots =
        _maxAnnouncementImages - _announcementImageFiles.length;
    if (remainingSlots <= 0) {
      _showMessage(
        "You can upload up to $_maxAnnouncementImages announcement photos.",
      );
      return;
    }

    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;

    final filesToAdd = picked.take(remainingSlots).toList();
    setState(() {
      _announcementImageFiles.addAll(filesToAdd);
    });

    final skipped = picked.length - filesToAdd.length;
    if (skipped > 0) {
      _showMessage(
        "$skipped photo(s) were not added. Max is $_maxAnnouncementImages.",
      );
    }
  }

  Future<String> _uploadAnnouncementFile(XFile file, String folder) async {
    final bytes = await file.readAsBytes();
    final extension = path.extension(file.name).isEmpty
        ? '.jpg'
        : path.extension(file.name);
    final fileName =
        "${DateTime.now().microsecondsSinceEpoch}_${path.basenameWithoutExtension(file.name)}$extension";
    final storagePath = "$folder/$fileName";

    await _supabase.storage
        .from('announcement-files')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: lookupMimeType(file.name) ?? 'image/jpeg',
          ),
        );

    return _supabase.storage
        .from('announcement-files')
        .getPublicUrl(storagePath);
  }

  void _removeAnnouncementImage(int index) {
    if (index < 0 || index >= _announcementImageFiles.length) return;
    setState(() {
      _announcementImageFiles.removeAt(index);
    });
  }

  void _showAnnouncementImageViewer(List<String> imageUrls, int initialIndex) {
    if (imageUrls.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              PageView.builder(
                controller: PageController(initialPage: initialIndex),
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "Unable to load image.",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAnnouncementDetails(Announcement announcement) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            announcement.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: announcement.isPublished
                                      ? const Color(0xFFE8F5EE)
                                      : const Color(0xFFFFF3CD),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  announcement.isPublished
                                      ? "Published"
                                      : "Draft",
                                  style: TextStyle(
                                    color: announcement.isPublished
                                        ? const Color(0xFF1F8A70)
                                        : const Color(0xFF9E7B00),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(announcement.createdAt),
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (announcement.thumbnailUrl.trim().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => _showAnnouncementImageViewer(
                        announcement.imageUrls.isNotEmpty
                            ? announcement.imageUrls
                            : [announcement.thumbnailUrl],
                        0,
                      ),
                      child: Image.network(
                        announcement.thumbnailUrl,
                        width: double.infinity,
                        height: 260,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                if (announcement.imageUrls.length > 1) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: announcement.imageUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final imageUrl = announcement.imageUrls[index];
                        return InkWell(
                          onTap: () => _showAnnouncementImageViewer(
                            announcement.imageUrls,
                            index,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              imageUrl,
                              width: 120,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  "Announcement Details",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _buildAnnouncementContentView(announcement.content),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _editAnnouncement(announcement);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text("Edit"),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _deleteAnnouncement(announcement);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Delete"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitAnnouncement() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();

    if (title.isEmpty || _contentController.text.trim().isEmpty) {
      _showMessage("Please enter both announcement title and content.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final imageUrls = <String>[];

      for (final file in _announcementImageFiles) {
        final url = await _uploadAnnouncementFile(file, 'gallery');
        imageUrls.add(url);
      }

      String thumbnailUrl = '';
      if (_thumbnailFile != null) {
        thumbnailUrl = await _uploadAnnouncementFile(
          _thumbnailFile!,
          'thumbnails',
        );
      } else if (imageUrls.isNotEmpty) {
        thumbnailUrl = imageUrls.first;
      }

      await announcementService.createAnnouncement(
        title: title,
        content: _contentController.text.trim(),
        thumbnailUrl: thumbnailUrl,
        imageUrls: imageUrls,
        isPublished: _isPublished,
      );

      _titleController.clear();
      _contentController.clear();
      _thumbnailFile = null;
      _announcementImageFiles.clear();
      _isPublished = true;
      await _loadAnnouncements();
      if (!mounted) return;
      _showMessage("Announcement posted.");
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('announcements')
          ? "Failed to post. Add the announcements table in Supabase first."
          : e.toString().contains('announcement-files')
          ? "Failed to upload image. Create the announcement-files storage bucket first."
          : "Failed to post announcement: $e";
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _editAnnouncement(Announcement announcement) async {
    final titleController = TextEditingController(text: announcement.title);
    final contentController = TextEditingController(
      text: _contentToEditableText(announcement.content),
    );
    bool isPublished = announcement.isPublished;
    String existingThumbnailUrl = announcement.thumbnailUrl;
    final existingImageUrls = List<String>.from(announcement.imageUrls);
    XFile? newThumbnailFile;
    final newImageFiles = <XFile>[];
    int dialogFontSize = _selectedFontSize;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Edit announcement"),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Title",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFormattingToolbar(
                      controller: contentController,
                      fontSize: dialogFontSize,
                      onDecreaseFontSize: () {
                        setDialogState(() {
                          dialogFontSize = (dialogFontSize - 1)
                              .clamp(_minFontSize, _maxFontSizeValue)
                              .toInt();
                        });
                      },
                      onIncreaseFontSize: () {
                        setDialogState(() {
                          dialogFontSize = (dialogFontSize + 1)
                              .clamp(_minFontSize, _maxFontSizeValue)
                              .toInt();
                        });
                      },
                      onApplyFontSize: () => _applyFontSizeToSelection(
                        contentController,
                        dialogFontSize,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      minLines: 8,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: "Announcement content",
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText: "Write your announcement details here...",
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Live Preview",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: contentController,
                      builder: (context, value, _) {
                        return _buildAnnouncementContentView(value.text);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Thumbnail Photo",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (picked == null) return;
                            setDialogState(() {
                              newThumbnailFile = picked;
                            });
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            newThumbnailFile != null ||
                                    existingThumbnailUrl.isNotEmpty
                                ? "Change Thumbnail"
                                : "Select Thumbnail",
                          ),
                        ),
                        if (newThumbnailFile != null)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  newThumbnailFile!.path,
                                  width: 120,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(
                                      () => newThumbnailFile = null,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (existingThumbnailUrl.isNotEmpty)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  existingThumbnailUrl,
                                  width: 120,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(
                                      () => existingThumbnailUrl = '',
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Announcement Photos (${existingImageUrls.length + newImageFiles.length}/$_maxAnnouncementImages)",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final remainingSlots =
                            _maxAnnouncementImages -
                            existingImageUrls.length -
                            newImageFiles.length;
                        if (remainingSlots <= 0) {
                          _showMessage(
                            "You can upload up to $_maxAnnouncementImages announcement photos.",
                          );
                          return;
                        }

                        final picked = await _picker.pickMultiImage();
                        if (picked.isEmpty) return;

                        setDialogState(() {
                          newImageFiles.addAll(picked.take(remainingSlots));
                        });

                        final skipped = picked.length - remainingSlots;
                        if (skipped > 0) {
                          _showMessage(
                            "$skipped photo(s) were not added. Max is $_maxAnnouncementImages.",
                          );
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text("Add Photos"),
                    ),
                    if (existingImageUrls.isNotEmpty ||
                        newImageFiles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 88,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (
                              var i = 0;
                              i < existingImageUrls.length;
                              i++
                            ) ...[
                              Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        existingImageUrls[i],
                                        width: 120,
                                        height: 88,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 14,
                                    top: 4,
                                    child: InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          existingImageUrls.removeAt(i);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            for (var i = 0; i < newImageFiles.length; i++) ...[
                              Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        newImageFiles[i].path,
                                        width: 120,
                                        height: 88,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 14,
                                    top: 4,
                                    child: InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          newImageFiles.removeAt(i);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isPublished,
                      title: const Text("Published"),
                      onChanged: (value) {
                        setDialogState(() => isPublished = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("Save"),
              ),
            ],
          ),
        );
      },
    );

    if (shouldSave != true) {
      titleController.dispose();
      contentController.dispose();
      return;
    }

    if (titleController.text.trim().isEmpty ||
        contentController.text.trim().isEmpty) {
      _showMessage("Please enter both announcement title and content.");
      titleController.dispose();
      contentController.dispose();
      return;
    }

    try {
      final uploadedImageUrls = <String>[];
      for (final file in newImageFiles) {
        final url = await _uploadAnnouncementFile(file, 'gallery');
        uploadedImageUrls.add(url);
      }

      String thumbnailUrl = existingThumbnailUrl;
      if (newThumbnailFile != null) {
        thumbnailUrl = await _uploadAnnouncementFile(
          newThumbnailFile!,
          'thumbnails',
        );
      }

      final imageUrls = [...existingImageUrls, ...uploadedImageUrls];
      if (thumbnailUrl.trim().isEmpty && imageUrls.isNotEmpty) {
        thumbnailUrl = imageUrls.first;
      }

      await announcementService.updateAnnouncement(
        id: announcement.id,
        title: titleController.text,
        content: contentController.text.trim(),
        thumbnailUrl: thumbnailUrl,
        imageUrls: imageUrls,
        isPublished: isPublished,
      );
      await _loadAnnouncements();
      if (!mounted) return;
      _showMessage("Announcement updated.");
    } catch (e) {
      if (!mounted) return;
      _showMessage("Failed to update announcement: $e");
    } finally {
      titleController.dispose();
      contentController.dispose();
    }
  }

  Future<void> _deleteAnnouncement(Announcement announcement) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete announcement?"),
        content: Text(
          "Are you sure you want to delete \"${announcement.title}\"?",
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
      await announcementService.deleteAnnouncement(announcement.id);
      await _loadAnnouncements();
      if (!mounted) return;
      _showMessage("Announcement deleted.");
    } catch (e) {
      if (!mounted) return;
      _showMessage("Failed to delete announcement: $e");
    }
  }

  Widget _buildComposerCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1120;

        final editor = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: _announcementInputDecoration(
                label: "Announcement title",
                icon: Icons.title,
              ),
            ),
            const SizedBox(height: 12),
            _buildFormattingToolbar(
              controller: _contentController,
              fontSize: _selectedFontSize,
              onDecreaseFontSize: _decreaseFontSize,
              onIncreaseFontSize: _increaseFontSize,
              onApplyFontSize: () => _applyFontSizeToSelection(
                _contentController,
                _selectedFontSize,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              minLines: wide ? 11 : 8,
              maxLines: wide ? 13 : 10,
              decoration: _announcementInputDecoration(
                label: "Announcement content",
                hint: "Write the official notice residents will receive.",
                icon: Icons.notes_outlined,
              ).copyWith(alignLabelWithHint: true),
            ),
          ],
        );

        final preview = Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Resident Preview",
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _contentController,
                builder: (context, value, _) {
                  return _buildAnnouncementContentView(value.text);
                },
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: editor),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: preview),
                ],
              )
            else ...[
              editor,
              const SizedBox(height: 18),
              preview,
            ],
            const SizedBox(height: 24),
            const Text(
              "Thumbnail Photo",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickThumbnail,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _thumbnailFile == null
                        ? "Select Thumbnail"
                        : "Change Thumbnail",
                  ),
                ),
                if (_thumbnailFile != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _thumbnailFile!.path,
                          width: 120,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: () {
                            setState(() => _thumbnailFile = null);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              "Announcement Photos",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickAnnouncementImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                "Add Photos (${_announcementImageFiles.length}/$_maxAnnouncementImages)",
              ),
            ),
            if (_announcementImageFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _announcementImageFiles.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final file = _announcementImageFiles[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            file.path,
                            width: 120,
                            height: 74,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: InkWell(
                            onTap: () => _removeAnnouncementImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: const VisualDensity(
                      horizontal: 0,
                      vertical: -2,
                    ),
                    value: _isPublished,
                    title: const Text("Publish immediately"),
                    onChanged: (value) {
                      setState(() => _isPublished = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitAnnouncement,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: Text(
                    _isSubmitting ? "Posting..." : "Post Announcement",
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _announcementPanelDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showAnnouncementDetails(announcement),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnnouncementThumbnail(announcement: announcement),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title.trim().isEmpty
                                  ? "Untitled announcement"
                                  : announcement.title.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF172033),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _AnnouncementStatusBadge(
                            isPublished: announcement.isPublished,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatDate(announcement.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF697386),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        announcement.plainText.isEmpty
                            ? "No announcement details available."
                            : announcement.plainText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _AnnouncementMetaPill(
                            label:
                                "${announcement.imageUrls.length} photo${announcement.imageUrls.length == 1 ? '' : 's'}",
                          ),
                          const SizedBox(width: 8),
                          _AnnouncementMetaPill(
                            label: announcement.updatedAt == null
                                ? "New post"
                                : "Updated",
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: "View",
                            onPressed: () =>
                                _showAnnouncementDetails(announcement),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            tooltip: "Edit",
                            onPressed: () => _editAnnouncement(announcement),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: "Delete",
                            onPressed: () => _deleteAnnouncement(announcement),
                            color: const Color(0xFFFF5B78),
                            icon: const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _announcementStatusFilterChip(String label, String value) {
    final isSelected = _announcementStatusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: const Color(0xFFE8F4FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? _primaryBlue : const Color(0xFFE5E7EB),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      labelStyle: TextStyle(
        color: isSelected ? _primaryBlue : const Color(0xFF4B5563),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) {
        setState(() => _announcementStatusFilter = value);
      },
    );
  }

  Widget _buildAnnouncementsListPanel() {
    final visibleAnnouncements = _visibleAnnouncements;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _announcementPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.campaign_outlined,
            title: "Posted Announcements",
            subtitle:
                "Browse, review, and manage all published or draft posts.",
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4F2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "${_announcements.length} total",
                style: const TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildStatChip(
                      label: "Published",
                      value: "$_publishedCount",
                      color: const Color(0xFF1F8A70),
                      backgroundColor: const Color(0xFFEAF7F2),
                    ),
                    _buildStatChip(
                      label: "Drafts",
                      value: "$_draftCount",
                      color: const Color(0xFFB78103),
                      backgroundColor: const Color(0xFFFFF7E3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              _announcementSearchField(),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _announcementStatusFilterChip("All Posts", "all"),
              _announcementStatusFilterChip("Published", "published"),
              _announcementStatusFilterChip("Drafts", "draft"),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visibleAnnouncements.isEmpty
                ? Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE3EBEF)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 42,
                            color: Color(0xFF8AA0AA),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "No announcements match this view.",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Try adjusting the search or status filter.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6D7C83)),
                          ),
                        ],
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(right: 6),
                      itemCount: visibleAnnouncements.length,
                      itemBuilder: (context, index) {
                        return _buildAnnouncementCard(
                          visibleAnnouncements[index],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAnnouncementPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _announcementPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.edit_note_rounded,
            title: "Create Announcement",
            subtitle:
                "Prepare a notice with images, formatting, and publish controls for residents.",
          ),
          const SizedBox(height: 22),
          _buildComposerCard(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Announcement Workspace",
                          style: TextStyle(
                            fontSize: 24,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Prepare official notices and manage resident-facing updates.",
                          style: TextStyle(
                            color: Color(0xD9FFFFFF),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text("Create Announcement"),
                        selected: _announcementSectionIndex == 0,
                        showCheckmark: false,
                        selectedColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _announcementSectionIndex == 0
                              ? _primaryBlue
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        side: const BorderSide(color: Colors.white24),
                        onSelected: (_) {
                          setState(() => _announcementSectionIndex = 0);
                        },
                      ),
                      ChoiceChip(
                        label: const Text("Posted Announcements"),
                        selected: _announcementSectionIndex == 1,
                        showCheckmark: false,
                        selectedColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _announcementSectionIndex == 1
                              ? _primaryBlue
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        side: const BorderSide(color: Colors.white24),
                        onSelected: (_) {
                          setState(() => _announcementSectionIndex = 1);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _announcementSectionIndex == 0
                    ? SingleChildScrollView(
                        key: const ValueKey('create_announcement_view'),
                        child: _buildCreateAnnouncementPanel(),
                      )
                    : Container(
                        key: const ValueKey('posted_announcement_view'),
                        child: _buildAnnouncementsListPanel(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementThumbnail extends StatelessWidget {
  const _AnnouncementThumbnail({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final imageUrl = announcement.thumbnailUrl.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageUrl.isEmpty
          ? Container(
              width: 128,
              height: 104,
              color: const Color(0xFFE8F4FF),
              child: const Icon(
                Icons.campaign_outlined,
                color: _AnnouncementsScreenState._primaryBlue,
                size: 30,
              ),
            )
          : Image.network(
              imageUrl,
              width: 128,
              height: 104,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 128,
                height: 104,
                color: const Color(0xFFE5E7EB),
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
    );
  }
}

class _AnnouncementStatusBadge extends StatelessWidget {
  const _AnnouncementStatusBadge({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final color = isPublished
        ? const Color(0xFF1F8A70)
        : const Color(0xFFB78103);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPublished ? "Published" : "Draft",
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AnnouncementMetaPill extends StatelessWidget {
  const _AnnouncementMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
