class ManifestGenerator {
  static List<String> cargo(int weight) {
    if (weight <= 0) return ["No cargo assigned to this job."];

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

  static List<String> pax(int count) {
    if (count <= 0) return ["No passengers booked on this leg."];

    final names = [
      "J. Kiriakos", "M. Papadopoulou", "A. Rallis",
      "S. Marinou", "Capt. Leon", "Dr. Petros", "Family Group",
    ];

    List<String> list = ["Total passengers: $count"];
    for (int i = 0; i < count; i++) {
      list.add("Passenger ${i + 1}: ${names[i % names.length]}");
    }

    return list;
  }

  static List<String> fuel(int gallons) {
    if (gallons <= 0) return ["No fuel transfer required for this leg."];

    return [
      "Fuel to deliver: $gallons gallons",
      "Pump truck: Assigned (#2)",
      "Safety checks: Completed",
      "Monitor fire safety on stand.",
    ];
  }
}
