import 'dart:convert';

class Checklist {
  final String aircraft;
  final String icao;
  final List<ChecklistSection> sections;

  Checklist({
    required this.aircraft,
    required this.icao,
    required this.sections,
  });

  factory Checklist.fromJson(Map<String, dynamic> j) {
    return Checklist(
      aircraft: j["aircraft"] ?? "Unknown",
      icao: j["icao"] ?? "",
      sections: (j["sections"] as List<dynamic>)
          .map((s) => ChecklistSection.fromJson(s))
          .toList(),
    );
  }
}

class ChecklistSection {
  final String id;
  final String title;
  final List<String> items;

  ChecklistSection({
    required this.id,
    required this.title,
    required this.items,
  });

  factory ChecklistSection.fromJson(Map<String, dynamic> j) {
    return ChecklistSection(
      id: j["id"],
      title: j["title"],
      items: List<String>.from(j["items"] ?? []),
    );
  }
}
