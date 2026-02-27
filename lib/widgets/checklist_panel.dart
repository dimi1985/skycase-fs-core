import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skycase/utils/checklist_state_service.dart';

class ChecklistPanel extends StatefulWidget {
  final String aircraftTitle;
  final VoidCallback onClose;

  const ChecklistPanel({
    super.key,
    required this.aircraftTitle,
    required this.onClose,
  });

  @override
  State<ChecklistPanel> createState() => _ChecklistPanelState();
}

class _ChecklistPanelState extends State<ChecklistPanel> {
  List<dynamic>? sections;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  // ------------------------------------------------------------
  // LOAD CHECKLIST
  // ------------------------------------------------------------
  Future<void> _loadChecklist() async {
    try {
      final file = _mapToFile(widget.aircraftTitle);
      final str = await rootBundle.loadString("assets/checklists/$file.json");
      final decoded = jsonDecode(str);

      List data;

      // Accept wrapped object OR raw array
      if (decoded is List) {
        data = decoded;
      } else if (decoded is Map && decoded["sections"] is List) {
        data = decoded["sections"];
      } else {
        throw Exception("Invalid checklist JSON format for $file.json");
      }

      setState(() => sections = data);
    } catch (err) {
      debugPrint("Checklist load error: $err");
      setState(() => sections = []);
    }
  }

  String _mapToFile(String t) {
    t = t.toLowerCase();
    if (t.contains("kodiak")) return "kodiak100";
    if (t.contains("172")) return "c172";
    return "generic";
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ------------------------------------------------------------
            // Header
            // ------------------------------------------------------------
            Row(
              children: [
                const Text(
                  "Checklist",
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ------------------------------------------------------------
            // Loading / Content
            // ------------------------------------------------------------
            Expanded(
              child: sections == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: sections!.length,
                      itemBuilder: (_, i) => _buildSection(sections![i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION WIDGET
  // ------------------------------------------------------------
  Widget _buildSection(dynamic section) {
    final String title = section["title"] ??
        section["name"] ??
        "Untitled Section";

    final String id = section["id"] ?? "section_$title";
    final List items = section["items"] ?? [];

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.white24,
        unselectedWidgetColor: Colors.white70,
      ),
      child: ExpansionTile(
        maintainState: true,
        childrenPadding: EdgeInsets.zero,
        collapsedIconColor: Colors.white70,
        iconColor: Colors.cyanAccent,
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
        children: [
          for (int i = 0; i < items.length; i++)
            _buildItem(id, i, items[i]),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ITEM WIDGET
  // ------------------------------------------------------------
  Widget _buildItem(String sectionId, int index, dynamic item) {
    // Accept either:
    //   "Parking Brake — SET"
    // or:
    //   { "label": "Parking Brake — SET" }
    final String label =
        item is String ? item : (item["label"] ?? "Unknown item");

    return FutureBuilder<Set<int>>(
      future: ChecklistStateService.loadProgress(
        widget.aircraftTitle,
        sectionId,
      ),
      builder: (ctx, snap) {
        final checked = snap.data?.contains(index) ?? false;

        return CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Colors.cyanAccent,
          checkColor: Colors.black,
          value: checked,
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: checked
                  ? Colors.greenAccent
                  : Colors.white.withOpacity(0.9),
              fontWeight:
                  checked ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onChanged: (v) {
            ChecklistStateService.saveProgress(
              icao: widget.aircraftTitle,
              sectionId: sectionId,
              index: index,
              checked: v ?? false,
            );
            setState(() {});
          },
        );
      },
    );
  }
}
