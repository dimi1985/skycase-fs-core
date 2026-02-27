import 'package:flutter/material.dart';
import 'package:skycase/screens/hq_approval_screen.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/utils/session_manager.dart';

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool cancelling = false;

  Future<void> _cancelJob() async {
    setState(() => cancelling = true);

    final jobId = widget.job["id"] ?? widget.job["_id"];
    final userId = await SessionManager.getUserId();

    if (jobId == null || userId == null) {
      setState(() => cancelling = false);
      return;
    }

    final ok = await DispatchService.cancelJob(jobId, userId);

    setState(() => cancelling = false);

    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final job = widget.job;

    final type = job["type"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Details"),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------
            // MAIN HEADER
            // -------------------------
            Text(
              job["title"] ?? "Active Job",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            _infoRow(theme, "From", job["fromIcao"]),
            _infoRow(theme, "To", job["toIcao"]),
            _infoRow(theme, "Type", type.toUpperCase()),
            _infoRow(
              theme,
              "Distance",
              "${job["distanceNm"]?.toStringAsFixed(0)} NM",
            ),
            _infoRow(theme, "Reward", "${job["reward"]} cr"),

            const SizedBox(height: 20),

            Divider(color: colors.onSurface.withOpacity(0.2), thickness: 1),
            const SizedBox(height: 20),

            // -------------------------
            // DYNAMIC SECTIONS
            // -------------------------
            if (type == "cargo") _cargoSection(theme, job),
            if (type == "pax") _paxSection(theme, job),
            if (type == "fuel") _fuelSection(theme, job),
            if (type == "ferry") _ferrySection(theme),

            const SizedBox(height: 20),

            SizedBox(width: double.infinity, child: _actionButton(theme, job)),
            const SizedBox(height: 30),

            // -------------------------
            // CANCEL BUTTON
            // -------------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cancelling ? null : _cancelJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child:
                    cancelling
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Cancel Job"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------
  // UNIVERSAL INFO ROW
  // -----------------------------------------------
  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  // -----------------------------------------------
  // CARGO SECTION
  // -----------------------------------------------
  Widget _cargoSection(ThemeData theme, Map<String, dynamic> job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, "Cargo Manifest"),
        _chip(theme, "${job["payloadLbs"]} lbs cargo"),
        const SizedBox(height: 10),
        _sectionHeader(theme, "Hazards / Notes"),
        Text(
          "• Possible remote strip operations\n"
          "• Watch density altitude\n"
          "• Confirm runway surface condition",
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  // -----------------------------------------------
  // PASSENGER SECTION (AIRLINE STYLE)
  // -----------------------------------------------
  Widget _paxSection(ThemeData theme, Map<String, dynamic> job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, "Passenger Manifest"),
        _chip(theme, "${job["paxCount"]} passengers"),

        const SizedBox(height: 20),

        _sectionHeader(theme, "Flight Briefing"),
        Text(
          "• Standard charter/airline briefing\n"
          "• Confirm passenger weights & balance\n"
          "• Check NOTAMs and SIGMETs",
          style: theme.textTheme.bodyMedium,
        ),

        const SizedBox(height: 20),

        _sectionHeader(theme, "Weather (Placeholder)"),
        Text(
          "METAR integration coming from SimLink weather feed.",
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  // -----------------------------------------------
  // FUEL TRANSFER SECTION
  // -----------------------------------------------
  Widget _fuelSection(ThemeData theme, Map<String, dynamic> job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, "Fuel Transfer"),
        _chip(theme, "${job["fuelGallons"]} gallons"),
        const SizedBox(height: 10),
        Text(
          "Operational Note:\n• Confirm pump availability\n• Handle fuel with care\n• Monitor fire safety procedures",
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  // -----------------------------------------------
  // FERRY SECTION
  // -----------------------------------------------
  Widget _ferrySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, "Ferry Flight"),
        Text(
          "• No cargo\n• No passengers\n• Aircraft repositioning flight.\n• Optional maintenance check ferry.",
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  // -----------------------------------------------
  // UI HELPERS
  // -----------------------------------------------
  Widget _sectionHeader(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionButton(ThemeData theme, Map<String, dynamic> job) {
    final status = job["status"] ?? "accepted";

    // --- Pending approval ---
    if (status == "pending_approval") {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        child: const Text("Waiting for HQ Approval"),
      );
    }

    // --- Approved ---
    if (status == "approved") {
      return ElevatedButton(
        onPressed: () {
          Navigator.pop(context, true);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: const Text("Approved — Start Flight"),
      );
    }

    // --- Rejected ---
    if (status == "rejected") {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        child: const Text("HQ Rejected"),
      );
    }

    // --- Accepted (DO NOT SHOW ANY BUTTON) ---
    if (status == "accepted") {
      return const SizedBox.shrink();
    }

    // --- Default: Not submitted ---
    return ElevatedButton(
      onPressed: () async {
        final approved = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HQApprovalScreen(job: job)),
        );
        if (approved == true && mounted) Navigator.pop(context, true);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: const Text("Send to HQ for Approval"),
    );
  }
}
