import 'package:flutter/material.dart';

//
// =========================
//  MODEL: Template Blueprint
// =========================
//
class GroundOpsTemplate {
  final List<GroundLight> lights;
  final List<GroundDoor> doors;

  // ⭐ Propeller support
  final Offset? propCenter;   // 0–1 relative position on canvas
  final double propRadius;    // visual size

  GroundOpsTemplate({
    required this.lights,
    required this.doors,
    this.propCenter,
    this.propRadius = 24,
  });
}

//
// =========================
//  MODEL: Lights
// =========================
//
class GroundLight {
  final String type;      // beacon / nav_left / strobe_right / landing ...
  final Offset position;  // relative position
  final Color color;

  GroundLight({
    required this.type,
    required this.position,
    required this.color,
  });
}

//
// =========================
//  MODEL: Doors / Exits
// =========================
//
class GroundDoor {
  final String label;
  final Rect area; // relative 0–1 box

  GroundDoor({
    required this.label,
    required this.area,
  });
}

//
// =========================
//  AIRCRAFT TEMPLATES
// =========================
//

// ----------------------------------
// 🛩  Kodiak 100
// ----------------------------------
final kodiakTemplate = GroundOpsTemplate(
  lights: [
    GroundLight(type: "beacon",      position: Offset(0.50, 0.50), color: Colors.red),
    GroundLight(type: "nav_left",    position: Offset(0.05, 0.45), color: Colors.red),
    GroundLight(type: "nav_right",   position: Offset(0.95, 0.45), color: Colors.green),
    GroundLight(type: "strobe_left", position: Offset(0.05, 0.50), color: Colors.white),
    GroundLight(type: "strobe_right",position: Offset(0.95, 0.50), color: Colors.white),
    GroundLight(type: "landing",     position: Offset(0.15, 0.43), color: Colors.white),
    GroundLight(type: "taxi",        position: Offset(0.50, 0.12), color: Colors.orange),
  ],
  doors: [
    GroundDoor(label: "L", area: Rect.fromLTWH(0.48, 0.34, 0.02, 0.10)),
    GroundDoor(label: "R", area: Rect.fromLTWH(0.50, 0.34, 0.02, 0.10)),
    GroundDoor(label: "C", area: Rect.fromLTWH(0.47, 0.54, 0.02, 0.12)),
  ],

  // Propeller position (nose)
  propCenter: Offset(0.50, 0.12),
  propRadius: 34,
);

// ----------------------------------
// 🛩 Piper Warrior II
// ----------------------------------
final warriorIITemplate = GroundOpsTemplate(
  lights: [
    GroundLight(type: "beacon",      position: Offset(0.50, 0.48), color: Colors.red),
    GroundLight(type: "nav_left",    position: Offset(0.05, 0.45), color: Colors.red),
    GroundLight(type: "nav_right",   position: Offset(0.95, 0.45), color: Colors.green),
    GroundLight(type: "strobe_left", position: Offset(0.05, 0.46), color: Colors.white),
    GroundLight(type: "strobe_right",position: Offset(0.95, 0.46), color: Colors.white),
    GroundLight(type: "landing",     position: Offset(0.15, 0.48), color: Colors.white),
    GroundLight(type: "taxi",        position: Offset(0.50, 0.10), color: Colors.orange),
  ],
  doors: [
    GroundDoor(label: "Pilot",     area: Rect.fromLTWH(0.48, 0.34, 0.02, 0.10)),
    GroundDoor(label: "Passenger", area: Rect.fromLTWH(0.52, 0.34, 0.02, 0.10)),
  ],

  propCenter: Offset(0.50, 0.15),
  propRadius: 22,
);

// ----------------------------------
// 🛩 Cessna 172 Skyhawk
// ----------------------------------
final c172Template = GroundOpsTemplate(
  lights: [
    GroundLight(type: "beacon",      position: Offset(0.50, 0.48), color: Colors.red),
    GroundLight(type: "nav_left",    position: Offset(0.04, 0.43), color: Colors.red),
    GroundLight(type: "nav_right",   position: Offset(0.96, 0.43), color: Colors.green),
    GroundLight(type: "strobe_left", position: Offset(0.05, 0.45), color: Colors.white),
    GroundLight(type: "strobe_right",position: Offset(0.95, 0.45), color: Colors.white),
    GroundLight(type: "landing",     position: Offset(0.13, 0.40), color: Colors.white),
    GroundLight(type: "taxi",        position: Offset(0.50, 0.10), color: Colors.orange),
  ],
  doors: [
    GroundDoor(label: "L", area: Rect.fromLTWH(0.46, 0.34, 0.02, 0.10)),
    GroundDoor(label: "R", area: Rect.fromLTWH(0.52, 0.34, 0.02, 0.10)),
  ],

  propCenter: Offset(0.50, 0.15),
  propRadius: 24,
);

// ----------------------------------
// Default fallback (no lights/doors)
// ----------------------------------
final defaultTemplate = GroundOpsTemplate(
  lights: [],
  doors: [],
);

//
// =========================
//  Template Selector
// =========================
//
GroundOpsTemplate getTemplateForAircraft(String title) {
  final name = title.toLowerCase();

  if (name.contains("kodiak")) return kodiakTemplate;
  if (name.contains("arrow") || name.contains("warrior")) return warriorIITemplate;
  if (name.contains("c172") || name.contains("skyhawk")) return c172Template;

  return defaultTemplate;
}
