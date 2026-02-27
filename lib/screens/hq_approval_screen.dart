import 'package:flutter/material.dart';
import 'package:skycase/screens/home_screen.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/metar_service.dart';
import 'package:skycase/utils/session_manager.dart';

class HQApprovalScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const HQApprovalScreen({super.key, required this.job});

  @override
  State<HQApprovalScreen> createState() => _HQApprovalScreenState();
}

class _HQApprovalScreenState extends State<HQApprovalScreen> {
  bool approving = false;

  // Expandable section state
  bool cargoOpen = true;
  bool paxOpen = false;
  bool fuelOpen = false;
  bool weatherOpen = false;
  bool opsOpen = false;
  Map<String, dynamic>? _metar;
  bool _loadingMetar = true;

  // HQ Chat
  final List<_HQMessage> _chat = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _seedInitialChat();
    _fetchWeather();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _seedInitialChat() {
    final job = widget.job;
    final from = (job["fromIcao"] ?? "????").toString().toUpperCase();
    final to = (job["toIcao"] ?? "????").toString().toUpperCase();
    final type = (job["type"] ?? "").toString();

    String typeLabel;
    switch (type) {
      case "cargo":
        typeLabel = "Cargo flight";
        break;
      case "pax":
        typeLabel = "Passenger service";
        break;
      case "fuel":
        typeLabel = "Fuel transfer";
        break;
      case "ferry":
        typeLabel = "Ferry reposition";
        break;
      default:
        typeLabel = "Job";
    }

    _chat.addAll([
      _HQMessage(
        from: "HQ",
        text: "Ops here. Reviewing $typeLabel from $from to $to.",
        isHQ: true,
      ),
      _HQMessage(
        from: "HQ",
        text:
            "Confirm when you have reviewed manifest and are ready for dispatch.",
        isHQ: true,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final job = widget.job;

    final String type = (job["type"] ?? "").toString();
    final String title = (job["title"] ?? "Job").toString();
    final String from = (job["fromIcao"] ?? "????").toString().toUpperCase();
    final String to = (job["toIcao"] ?? "????").toString().toUpperCase();
    final int reward = (job["reward"] ?? 0) as int;
    final double distance =
        (job["distanceNm"] is num)
            ? (job["distanceNm"] as num).toDouble()
            : 0.0;

    final int payloadLbs = (job["payloadLbs"] ?? 0) as int;
    final int paxCount = (job["paxCount"] ?? 0) as int;
    final int fuelGallons = (job["fuelGallons"] ?? 0) as int;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🛫 Operations Center"),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // HEADER
            // ==========================================
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  "$from → $to",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    type.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.navigation,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text("${distance.toStringAsFixed(0)} NM"),
                const SizedBox(width: 16),
                Icon(Icons.payments, size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text("$reward cr"),
              ],
            ),

            const SizedBox(height: 24),

            // ==========================================
            // TYPE-SPECIFIC MANIFEST SECTIONS
            // ==========================================
            if (type == "cargo")
              _expando(
                icon: Icons.inventory_2_rounded,
                title: "Cargo Preparation",
                open: cargoOpen,
                onToggle: () => setState(() => cargoOpen = !cargoOpen),
                children:
                    _generateCargoManifest(
                      payloadLbs,
                    ).map((e) => _bullet(e)).toList(),
              ),

            if (type == "pax")
              _expando(
                icon: Icons.airline_seat_recline_normal,
                title: "Passenger Boarding",
                open: paxOpen,
                onToggle: () => setState(() => paxOpen = !paxOpen),
                children:
                    _generatePassengerManifest(
                      paxCount,
                    ).map((e) => _bullet(e)).toList(),
              ),

            if (type == "fuel")
              _expando(
                icon: Icons.local_gas_station,
                title: "Fuel Transfer",
                open: fuelOpen,
                onToggle: () => setState(() => fuelOpen = !fuelOpen),
                children:
                    _generateFuelManifest(
                      fuelGallons,
                    ).map((e) => _bullet(e)).toList(),
              ),

            if (type == "ferry")
              _expando(
                icon: Icons.airplanemode_active,
                title: "Ferry Operation",
                open: opsOpen,
                onToggle: () => setState(() => opsOpen = !opsOpen),
                children: [
                  _bullet("Aircraft repositioning flight only."),
                  _bullet("No cargo or passengers assigned."),
                  _bullet("Optional maintenance check on arrival."),
                ],
              ),

            // ==========================================
            // UNIVERSAL WEATHER & OPS
            // ==========================================
            _expando(
              icon: Icons.cloud,
              title: "Weather Briefing",
              open: weatherOpen,
              onToggle: () => setState(() => weatherOpen = !weatherOpen),
              children: _buildWeatherSection(),
            ),

            _expando(
              icon: Icons.engineering,
              title: "Operational Notes",
              open: opsOpen,
              onToggle: () => setState(() => opsOpen = !opsOpen),
              children: [
                _bullet("🛠 No critical maintenance remarks reported."),
                _bullet("🔧 Ensure within aircraft WT/BAL limits."),
                _bullet(
                  "🔥 Fuel on board must meet legal reserves + company policy.",
                ),
                _bullet(
                  "📡 Flight plan ready for uplink on pilot confirmation.",
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ==========================================
            // HQ CHAT
            // ==========================================
            Text(
              "HQ Chat",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.onSurface.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _chatScroll,
                      padding: const EdgeInsets.all(10),
                      itemCount: _chat.length,
                      itemBuilder: (context, index) {
                        final msg = _chat[index];
                        final align =
                            msg.isHQ
                                ? Alignment.centerLeft
                                : Alignment.centerRight;
                        final bubbleColor =
                            msg.isHQ
                                ? colors.surface
                                : colors.primary.withOpacity(0.90);
                        final textColor =
                            msg.isHQ ? colors.onSurface : colors.onPrimary;

                        return Align(
                          alignment: align,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: const InputDecoration(
                              hintText: "Message HQ…",
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ==========================================
            // APPROVE BUTTON
            // ==========================================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: approving ? null : _approve,
                child:
                    approving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "Accept Job",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MANIFEST GENERATORS
  // ============================================================

  List<String> _generateCargoManifest(int weight) {
    if (weight <= 0) {
      return ["No cargo assigned to this job."];
    }

    final List<Map<String, dynamic>> cargoTypes = [
      {"name": "Supply Crate", "weight": 80},
      {"name": "Industrial Drill", "weight": 120},
      {"name": "Medical Kit", "weight": 25},
      {"name": "Electronics Box", "weight": 42},
      {"name": "Tool Bag", "weight": 18},
    ];

    List<String> manifest = [];
    int remaining = weight;

    while (remaining > 0) {
      final item = cargoTypes[remaining % cargoTypes.length];
      final int w = item["weight"];

      if (remaining < w) {
        manifest.add("$remaining lbs Misc Cargo");
        break;
      }

      manifest.add("${item["name"]} — $w lbs");
      remaining -= w;
    }

    manifest.insert(0, "Total payload: $weight lbs");
    return manifest;
  }

  List<String> _generatePassengerManifest(int paxCount) {
    if (paxCount <= 0) {
      return ["No passengers booked on this leg."];
    }

    final names = [
      "J. Kiriakos",
      "M. Papadopoulou",
      "A. Rallis",
      "S. Marinou",
      "Capt. Leon",
      "Dr. Petros",
      "Family Group",
    ];

    List<String> pax = ["Total passengers: $paxCount"];
    for (int i = 0; i < paxCount; i++) {
      pax.add("Passenger ${i + 1}: ${names[i % names.length]}");
    }

    return pax;
  }

  List<String> _generateFuelManifest(int gallons) {
    if (gallons <= 0) {
      return ["No fuel transfer required for this leg."];
    }

    return [
      "Fuel to deliver: $gallons gallons",
      "Pump: Assigned (Truck #2)",
      "Safety checks: Completed",
      "Reminder: Monitor fire safety procedures on stand.",
    ];
  }

  // ============================================================
  // CHAT LOGIC
  // ============================================================

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chat.add(_HQMessage(from: "Pilot", text: text, isHQ: false));
      _chatController.clear();
    });

    _scrollChatToEnd();

    // Very simple canned HQ reply
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      final job = widget.job;
      final type = (job["type"] ?? "").toString();

      String reply;
      if (type == "cargo") {
        reply =
            "HQ: Copy. Cargo manifest locked. You’re cleared once walkaround is complete.";
      } else if (type == "pax") {
        reply =
            "HQ: Roger. Gate has been informed. Notify when doors are closed.";
      } else if (type == "fuel") {
        reply =
            "HQ: Fuel truck en route. Do not start until refuel is confirmed complete.";
      } else if (type == "ferry") {
        reply =
            "HQ: Ferry approved. Note any abnormal behavior for maintenance on arrival.";
      } else {
        reply = "HQ: Acknowledged. Standing by for your ready call.";
      }

      setState(() {
        _chat.add(_HQMessage(from: "HQ", text: reply, isHQ: true));
      });
      _scrollChatToEnd();
    });
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    );
  }

  Widget _expando({
    required IconData icon,
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.onSurface.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: colors.primary),
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // APPROVAL
  // ============================================================
  Future<void> _approve() async {
    setState(() => approving = true);

    // Extract job ID and user ID
    final jobId = widget.job["id"] ?? widget.job["_id"];
    final userId = await SessionManager.getUserId();

    if (jobId == null || userId == null) {
      setState(() => approving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing job or user — cannot approve")),
      );
      return;
    }
    

    // Call backend
    final result = await DispatchService.acceptJob(jobId, userId);

    if (!mounted) return;

    setState(() => approving = false);

    if (result != null) {
      // SUCCESS → Go home and rebuild everything
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // FAILED
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to assign job — try again")),
      );
    }
  }

  Future<void> _fetchWeather() async {
    final String icao =
        (widget.job["fromIcao"] ?? "").toString().trim().toUpperCase();

    if (icao.isEmpty) {
      setState(() {
        _loadingMetar = false;
        _metar = null;
      });
      return;
    }

    final data = await MetarService.getBriefing(icao);

    if (!mounted) return;

    setState(() {
      _loadingMetar = false; // <- IMPORTANT
      _metar = data; // <- can be null, that's OK
    });

    // HQ auto weather message ONLY if we actually got real data
    if (data != null) {
      _chat.add(
        _HQMessage(
          from: "HQ",
          text: "Weather at $icao: ${data["summary"]}",
          isHQ: true,
        ),
      );
      _scrollChatToEnd();
    }
  }

  List<Widget> _buildWeatherSection() {
    if (_loadingMetar) {
      return [
        const Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      ];
    }

    if (_metar == null) {
      return [
        _bullet("⚠️ METAR unavailable for this airport."),
        _bullet("SkyCase will use MSFS in-sim weather during flight."),
      ];
    }

    final wind = _metar!["wind"] ?? "N/A";
    final temp = _metar!["temp"] ?? "N/A";
    final List clouds = _metar!["clouds"] ?? [];
    final raw = _metar!["raw"] ?? "N/A";

    return [
      _bullet("Raw: $raw"),
      _bullet("💨 Wind: $wind"),
      _bullet("🌡 Temp: ${temp}°C"),
      _bullet("☁ Clouds: ${clouds.isNotEmpty ? clouds.join(', ') : "Clear"}"),
    ];
  }
}

// Simple HQ message model
class _HQMessage {
  final String from;
  final String text;
  final bool isHQ;

  _HQMessage({required this.from, required this.text, required this.isHQ});
}
