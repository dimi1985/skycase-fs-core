import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/ground_ops/ground_ops_template_catalog.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/painters/ground_ops/ground_ops_painter.dart';
import 'package:skycase/services/aircraft_service.dart';
import 'package:skycase/services/ground_ops/ground_ops_template_storage.dart';
import 'package:skycase/services/simlink_service.dart';

enum BuilderLayer {
  parts,
  doors,
  lights,
  services,
}

class AircraftLayoutBuilderScreen extends StatefulWidget {
  final GroundOpsTemplate? initialTemplate;

  const AircraftLayoutBuilderScreen({
    super.key,
    this.initialTemplate,
  });

  @override
  State<AircraftLayoutBuilderScreen> createState() =>
      _AircraftLayoutBuilderScreenState();
}

class _AircraftLayoutBuilderScreenState
    extends State<AircraftLayoutBuilderScreen> {
  StreamSubscription<SimLinkData>? _simSub;

  SimLinkData? _liveSim;
  String? _lastLiveAircraftTitle;

  List<LearnedAircraft> _hangarAircraft = [];

  bool _loadingHangar = true;
  bool _usingLiveAircraft = false;

  LearnedAircraft? _selectedAircraft;
  GroundOpsTemplate? _template;
  GroundOpsAircraftFamily _family = GroundOpsAircraftFamily.gaSingle;

  BuilderLayer _layer = BuilderLayer.parts;

  String? _selectedPartId;
  String? _selectedDoorId;
  String? _selectedLightId;
  String? _selectedServiceId;

  static const double _desktopPreviewAspect = 0.98;
  static const double _mobilePreviewAspect = 0.78;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate;
    _bootstrap();
    _simSub = SimLinkService.stream.listen(_handleLiveSimData, onError: (_) {});
  }

  @override
  void dispose() {
    _simSub?.cancel();
    _autoSaveTimer?.cancel();
    super.dispose();
  }


  String get _activeAircraftId {
    if (_usingLiveAircraft && _liveSim != null) {
      return GroundOpsTemplateStorage.normalizeAircraftId(_liveSim!.title);
    }
    final ac = _selectedAircraft;
    if (ac != null) {
      return GroundOpsTemplateStorage.normalizeAircraftId(
        ac.id.isEmpty ? ac.title : ac.id,
      );
    }
    final t = _template;
    if (t != null) {
      return GroundOpsTemplateStorage.normalizeAircraftId(t.id);
    }
    return 'unknown_aircraft';
  }

  Future<void> _saveTemplate({bool showFeedback = false}) async {
    final template = _template;
    if (template == null) return;

    final normalized = template.copyWith(id: _activeAircraftId);
    _template = normalized;
    await GroundOpsTemplateStorage.saveTemplate(normalized);

    if (!mounted || !showFeedback) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template saved.')),
    );
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 450), () {
      _saveTemplate();
    });
  }

  Future<GroundOpsTemplate> _loadSeedOrSaved({
    required String aircraftId,
    required String aircraftName,
    required GroundOpsAircraftFamily family,
  }) {
    return GroundOpsTemplateStorage.loadOrSeed(
      aircraftId: aircraftId,
      aircraftName: aircraftName,
      family: family,
    );
  }

  String _uniqueId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';


  String _defaultPartName(AircraftPartType type) {
    return switch (type) {
      AircraftPartType.fuselage => 'Part Fuselage',
      AircraftPartType.wingLeft => 'Left Wing Part',
      AircraftPartType.wingRight => 'Right Wing Part',
      AircraftPartType.flapLeft => 'Left Flap',
      AircraftPartType.flapRight => 'Right Flap',
      AircraftPartType.aileronLeft => 'Left Aileron',
      AircraftPartType.aileronRight => 'Right Aileron',
      AircraftPartType.elevatorLeft => 'Left Elevator',
      AircraftPartType.elevatorRight => 'Right Elevator',
      AircraftPartType.rudder => 'Rudder',
      AircraftPartType.engineSingle => 'Engine',
      AircraftPartType.engineLeft => 'Left Engine',
      AircraftPartType.engineRight => 'Right Engine',
      AircraftPartType.engineCenter => 'Center Engine',
      AircraftPartType.propeller => 'Propeller Zone',
      AircraftPartType.rotorMain => 'Main Rotor Zone',
      AircraftPartType.noseGear => 'Nose Gear',
      AircraftPartType.mainGearLeft => 'Left Main Gear',
      AircraftPartType.mainGearRight => 'Right Main Gear',
      AircraftPartType.mainGearCenter => 'Center Main Gear',
    };
  }

  Color _colorForPartType(AircraftPartType type) {
    return switch (type) {
      AircraftPartType.fuselage => Colors.blueGrey,
      AircraftPartType.wingLeft || AircraftPartType.wingRight => Colors.blueGrey,
      AircraftPartType.flapLeft || AircraftPartType.flapRight => Colors.orange,
      AircraftPartType.aileronLeft || AircraftPartType.aileronRight => Colors.teal,
      AircraftPartType.elevatorLeft || AircraftPartType.elevatorRight || AircraftPartType.rudder => Colors.indigo,
      AircraftPartType.engineSingle || AircraftPartType.engineLeft || AircraftPartType.engineRight || AircraftPartType.engineCenter => Colors.redAccent,
      AircraftPartType.propeller || AircraftPartType.rotorMain => Colors.brown,
      AircraftPartType.noseGear || AircraftPartType.mainGearLeft || AircraftPartType.mainGearRight || AircraftPartType.mainGearCenter => Colors.brown,
    };
  }

  String _defaultDoorName(DoorType type) {
    return switch (type) {
      DoorType.mainEntry => 'Main Entry',
      DoorType.service => 'Service Door',
      DoorType.cargo => 'Cargo Door',
      DoorType.baggage => 'Baggage Door',
      DoorType.emergencyExit => 'Emergency Exit',
      DoorType.overwingExit => 'Overwing Exit',
      DoorType.cockpitAccess => 'Cockpit Access',
      DoorType.custom => 'Custom Door',
    };
  }

  String _defaultLightName(LightType type) {
    return switch (type) {
      LightType.beacon => 'Beacon',
      LightType.navLeft => 'Left Nav',
      LightType.navRight => 'Right Nav',
      LightType.strobeLeft => 'Left Strobe',
      LightType.strobeRight => 'Right Strobe',
      LightType.landing => 'Landing',
      LightType.taxi => 'Taxi',
      LightType.logo => 'Logo',
      LightType.cabin => 'Cabin',
      LightType.generic => 'Generic Light',
    };
  }

  Color _colorForLightType(LightType type) {
    return switch (type) {
      LightType.beacon => Colors.red,
      LightType.navLeft => Colors.red,
      LightType.navRight => Colors.green,
      LightType.strobeLeft || LightType.strobeRight || LightType.landing || LightType.taxi || LightType.logo || LightType.cabin || LightType.generic => Colors.white,
    };
  }

  DoorAnimationStyle _animationForDoorType(DoorType type) {
    return switch (type) {
      DoorType.cargo || DoorType.baggage => DoorAnimationStyle.slideUp,
      DoorType.overwingExit => DoorAnimationStyle.foldOut,
      DoorType.service || DoorType.cockpitAccess => DoorAnimationStyle.slideSide,
      DoorType.mainEntry || DoorType.emergencyExit || DoorType.custom => DoorAnimationStyle.swingOut,
    };
  }

  String _defaultServiceName(ServicePointType type) {
    return switch (type) {
      ServicePointType.fuel => 'Fuel Point',
      ServicePointType.gpu => 'GPU',
      ServicePointType.catering => 'Catering',
      ServicePointType.baggage => 'Baggage Service',
      ServicePointType.lavatory => 'Lavatory',
      ServicePointType.water => 'Water',
      ServicePointType.pushback => 'Pushback',
      ServicePointType.airStart => 'Air Start',
      ServicePointType.custom => 'Custom Service',
    };
  }

  void _addDoor() {
    final template = _template;
    if (template == null) return;

    final door = GroundDoor(
      id: _uniqueId('door'),
      name: _defaultDoorName(DoorType.mainEntry),
      type: DoorType.mainEntry,
      code: 'D${template.doors.length + 1}',
      animationStyle: _animationForDoorType(DoorType.mainEntry),
      points: const [
        NormalizedPoint(0.56, 0.22),
        NormalizedPoint(0.60, 0.22),
        NormalizedPoint(0.60, 0.30),
        NormalizedPoint(0.56, 0.30),
      ],
    );

    setState(() {
      _layer = BuilderLayer.doors;
      _template = template.copyWith(doors: [...template.doors, door]);
      _selectedDoorId = door.id;
      _selectedPartId = null;
      _selectedLightId = null;
      _selectedServiceId = null;
    });
    _scheduleAutoSave();
  }

  void _addPart([AircraftPartType type = AircraftPartType.fuselage]) {
    final template = _template;
    if (template == null) return;

    final centerX = 0.50 + ((template.parts.length % 3) - 1) * 0.06;
    final centerY = 0.50 + ((template.parts.length % 4) - 1.5) * 0.06;
    final points = [
      NormalizedPoint((centerX - 0.04).clamp(0.04, 0.96), (centerY - 0.03).clamp(0.04, 0.96)),
      NormalizedPoint((centerX + 0.04).clamp(0.04, 0.96), (centerY - 0.03).clamp(0.04, 0.96)),
      NormalizedPoint((centerX + 0.04).clamp(0.04, 0.96), (centerY + 0.03).clamp(0.04, 0.96)),
      NormalizedPoint((centerX - 0.04).clamp(0.04, 0.96), (centerY + 0.03).clamp(0.04, 0.96)),
    ];

    final part = AircraftPolygonPart(
      id: _uniqueId('part'),
      name: _defaultPartName(type),
      type: type,
      colorHint: _colorForPartType(type),
      points: points,
    );

    setState(() {
      _layer = BuilderLayer.parts;
      _template = template.copyWith(parts: [...template.parts, part]);
      _selectedPartId = part.id;
      _selectedDoorId = null;
      _selectedLightId = null;
      _selectedServiceId = null;
    });
    _scheduleAutoSave();
  }

  void _addService([ServicePointType type = ServicePointType.fuel]) {
    final template = _template;
    if (template == null) return;

    final point = GroundServicePoint(
      id: _uniqueId('service'),
      name: _defaultServiceName(type),
      type: type,
      position: const NormalizedPoint(0.62, 0.24),
    );

    setState(() {
      _layer = BuilderLayer.services;
      _template = template.copyWith(servicePoints: [...template.servicePoints, point]);
      _selectedServiceId = point.id;
      _selectedPartId = null;
      _selectedDoorId = null;
      _selectedLightId = null;
    });
    _scheduleAutoSave();
  }

  void _addLight([LightType type = LightType.generic]) {
    final template = _template;
    if (template == null) return;

    final light = GroundLight(
      id: _uniqueId('light'),
      name: _defaultLightName(type),
      type: type,
      position: const NormalizedPoint(0.50, 0.18),
      color: _colorForLightType(type),
      enabled: false,
      intensity: type == LightType.landing || type == LightType.taxi ? 1.2 : 1.0,
    );

    setState(() {
      _layer = BuilderLayer.lights;
      _template = template.copyWith(lights: [...template.lights, light]);
      _selectedLightId = light.id;
      _selectedPartId = null;
      _selectedDoorId = null;
      _selectedServiceId = null;
    });
    _scheduleAutoSave();
  }

  void _deleteSelected() {
    final template = _template;
    if (template == null) return;

    setState(() {
      switch (_layer) {
        case BuilderLayer.parts:
          final id = _selectedPartId;
          if (id == null) return;
          _template = template.copyWith(
            parts: template.parts.where((e) => e.id != id).toList(),
          );
          _selectedPartId = null;
          break;
        case BuilderLayer.doors:
          final id = _selectedDoorId;
          if (id == null) return;
          _template = template.copyWith(
            doors: template.doors.where((e) => e.id != id).toList(),
          );
          _selectedDoorId = null;
          break;
        case BuilderLayer.lights:
          final id = _selectedLightId;
          if (id == null) return;
          _template = template.copyWith(
            lights: template.lights.where((e) => e.id != id).toList(),
          );
          _selectedLightId = null;
          break;
        case BuilderLayer.services:
          final id = _selectedServiceId;
          if (id == null) return;
          _template = template.copyWith(
            servicePoints: template.servicePoints.where((e) => e.id != id).toList(),
          );
          _selectedServiceId = null;
          break;
      }
    });
    _scheduleAutoSave();
  }

  Future<void> _bootstrap() async {
    final latest = SimLinkService.latest;
    if (latest != null) {
      _applyLiveAircraft(latest, rebuild: false);
    }

    await _loadHangar();
    if (!mounted) return;

    if (_template != null) {
      setState(() {});
      return;
    }

    if (_liveSim != null) {
      _usingLiveAircraft = true;
      _buildTemplateFromLive(rebuild: false);
    } else if (_hangarAircraft.isNotEmpty) {
      _selectedAircraft = _hangarAircraft.first;
      _family = GroundOpsTemplateCatalog.inferFamily(aircraft: _selectedAircraft);
      _buildTemplateFromSelectedAircraft(rebuild: false);
    }

    setState(() {});
  }

  Future<void> _loadHangar() async {
    try {
      _hangarAircraft = await AircraftService.getAll();
    } catch (_) {
      _hangarAircraft = [];
    } finally {
      _loadingHangar = false;
    }
  }

  void _handleLiveSimData(SimLinkData data) {
    final incomingTitle = data.title.trim();
    if (_lastLiveAircraftTitle == incomingTitle) {
      _liveSim = data;
      return;
    }
    _applyLiveAircraft(data, rebuild: true);
  }

  Future<void> _applyLiveAircraft(SimLinkData data, {required bool rebuild}) async {
    _liveSim = data;
    _lastLiveAircraftTitle = data.title.trim();

    if (_usingLiveAircraft || _template == null) {
      _usingLiveAircraft = true;
      _family = GroundOpsTemplateCatalog.inferFamily(title: data.title);
      _template = await _loadSeedOrSaved(
        aircraftId: _slugify(data.title),
        aircraftName: data.title.trim().isEmpty ? 'Live Aircraft' : data.title,
        family: _family,
      );
      _clearSelection();
    }

    if (rebuild && mounted) {
      setState(() {});
    }
  }

  Future<void> _buildTemplateFromLive({bool rebuild = true}) async {
    final sim = _liveSim;
    if (sim == null) return;

    _usingLiveAircraft = true;
    _template = await _loadSeedOrSaved(
      aircraftId: _slugify(sim.title),
      aircraftName: sim.title.trim().isEmpty ? 'Live Aircraft' : sim.title,
      family: _family,
    );
    _clearSelection();

    if (rebuild && mounted) setState(() {});
  }

  Future<void> _buildTemplateFromSelectedAircraft({bool rebuild = true}) async {
    final ac = _selectedAircraft;
    if (ac == null) return;

    _usingLiveAircraft = false;
    _template = await _loadSeedOrSaved(
      aircraftId: ac.id.isEmpty ? _slugify(ac.title) : ac.id,
      aircraftName: ac.title,
      family: _family,
    );
    _clearSelection();

    if (rebuild && mounted) setState(() {});
  }

  void _selectLiveAircraft() {
    if (_liveSim == null) return;
    _family = GroundOpsTemplateCatalog.inferFamily(title: _liveSim!.title);
    _buildTemplateFromLive();
  }

  void _selectHangarAircraft(LearnedAircraft aircraft) {
    _selectedAircraft = aircraft;
    _family = GroundOpsTemplateCatalog.inferFamily(aircraft: aircraft);
    _buildTemplateFromSelectedAircraft();
  }

  void _setFamily(GroundOpsAircraftFamily family) {
    _family = family;
    if (_usingLiveAircraft) {
      _buildTemplateFromLive();
    } else {
      _buildTemplateFromSelectedAircraft();
    }
  }

  void _clearSelection() {
    _selectedPartId = null;
    _selectedDoorId = null;
    _selectedLightId = null;
    _selectedServiceId = null;
  }

  void _setLayer(BuilderLayer layer) {
    setState(() {
      _layer = layer;
      _clearSelection();
    });
  }

  void _selectPart(String id) {
    setState(() {
      _layer = BuilderLayer.parts;
      _selectedPartId = id;
      _selectedDoorId = null;
      _selectedLightId = null;
      _selectedServiceId = null;
    });
  }

  void _selectDoor(String id) {
    setState(() {
      _layer = BuilderLayer.doors;
      _selectedDoorId = id;
      _selectedPartId = null;
      _selectedLightId = null;
      _selectedServiceId = null;
    });
  }

  void _selectLight(String id) {
    setState(() {
      _layer = BuilderLayer.lights;
      _selectedLightId = id;
      _selectedPartId = null;
      _selectedDoorId = null;
      _selectedServiceId = null;
    });
  }

  void _selectService(String id) {
    setState(() {
      _layer = BuilderLayer.services;
      _selectedServiceId = id;
      _selectedPartId = null;
      _selectedDoorId = null;
      _selectedLightId = null;
    });
  }

  AircraftPolygonPart? get _selectedPart {
    final t = _template;
    final id = _selectedPartId;
    if (t == null || id == null) return null;
    for (final item in t.parts) {
      if (item.id == id) return item;
    }
    return null;
  }

  GroundDoor? get _selectedDoor {
    final t = _template;
    final id = _selectedDoorId;
    if (t == null || id == null) return null;
    for (final item in t.doors) {
      if (item.id == id) return item;
    }
    return null;
  }

  GroundLight? get _selectedLight {
    final t = _template;
    final id = _selectedLightId;
    if (t == null || id == null) return null;
    for (final item in t.lights) {
      if (item.id == id) return item;
    }
    return null;
  }

  GroundServicePoint? get _selectedService {
    final t = _template;
    final id = _selectedServiceId;
    if (t == null || id == null) return null;
    for (final item in t.servicePoints) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _renameSelected() async {
    final current = switch (_layer) {
      BuilderLayer.parts => _selectedPart?.name,
      BuilderLayer.doors => _selectedDoor?.name,
      BuilderLayer.lights => _selectedLight?.name,
      BuilderLayer.services => _selectedService?.name,
    };

    if (current == null) return;

    final value = await _showTextEditDialog(
      context: context,
      title: 'Rename',
      initialValue: current,
    );

    if (value == null || value.trim().isEmpty || _template == null) return;

    setState(() {
      switch (_layer) {
        case BuilderLayer.parts:
          _template = _template!.copyWith(
            parts: _template!.parts
                .map((e) => e.id == _selectedPartId ? e.copyWith(name: value.trim()) : e)
                .toList(),
          );
          break;
        case BuilderLayer.doors:
          _template = _template!.copyWith(
            doors: _template!.doors
                .map((e) => e.id == _selectedDoorId ? e.copyWith(name: value.trim()) : e)
                .toList(),
          );
          break;
        case BuilderLayer.lights:
          _template = _template!.copyWith(
            lights: _template!.lights
                .map((e) => e.id == _selectedLightId ? e.copyWith(name: value.trim()) : e)
                .toList(),
          );
          break;
        case BuilderLayer.services:
          _template = _template!.copyWith(
            servicePoints: _template!.servicePoints
                .map((e) => e.id == _selectedServiceId ? e.copyWith(name: value.trim()) : e)
                .toList(),
          );
          break;
      }
    });
    _scheduleAutoSave();
  }

  void _toggleSelectedEnabled() {
    if (_template == null) return;

    setState(() {
      switch (_layer) {
        case BuilderLayer.parts:
          final selected = _selectedPart;
          if (selected == null) return;
          _template = _template!.copyWith(
            parts: _template!.parts
                .map(
                  (e) => e.id == selected.id
                      ? e.copyWith(colorHint: (e.colorHint ?? Colors.blueGrey))
                      : e,
                )
                .toList(),
          );
          break;
        case BuilderLayer.doors:
          final selected = _selectedDoor;
          if (selected == null) return;
          _template = _template!.copyWith(
            doors: _template!.doors
                .map((e) => e.id == selected.id ? e.copyWith(enabled: !e.enabled) : e)
                .toList(),
          );
          break;
        case BuilderLayer.lights:
          final selected = _selectedLight;
          if (selected == null) return;
          _template = _template!.copyWith(
            lights: _template!.lights
                .map((e) => e.id == selected.id ? e.copyWith(enabled: !e.enabled) : e)
                .toList(),
          );
          break;
        case BuilderLayer.services:
          final selected = _selectedService;
          if (selected == null) return;
          _template = _template!.copyWith(
            servicePoints: _template!.servicePoints
                .map((e) => e.id == selected.id ? e.copyWith(enabled: !e.enabled) : e)
                .toList(),
          );
          break;
      }
    });
    _scheduleAutoSave();
  }

  void _nudgeSelected(double dx, double dy) {
    if (_template == null) return;

    setState(() {
      switch (_layer) {
        case BuilderLayer.parts:
          final selected = _selectedPart;
          if (selected == null) return;
          _template = _template!.copyWith(
            parts: _template!.parts.map((e) {
              if (e.id != selected.id) return e;
              return e.copyWith(points: _shiftPoints(e.points, dx, dy));
            }).toList(),
          );
          break;
        case BuilderLayer.doors:
          final selected = _selectedDoor;
          if (selected == null) return;
          _template = _template!.copyWith(
            doors: _template!.doors.map((e) {
              if (e.id != selected.id) return e;
              return e.copyWith(points: _shiftPoints(e.points, dx, dy));
            }).toList(),
          );
          break;
        case BuilderLayer.lights:
          final selected = _selectedLight;
          if (selected == null) return;
          _template = _template!.copyWith(
            lights: _template!.lights.map((e) {
              if (e.id != selected.id) return e;
              return e.copyWith(position: _shiftPoint(e.position, dx, dy));
            }).toList(),
          );
          break;
        case BuilderLayer.services:
          final selected = _selectedService;
          if (selected == null) return;
          _template = _template!.copyWith(
            servicePoints: _template!.servicePoints.map((e) {
              if (e.id != selected.id) return e;
              return e.copyWith(position: _shiftPoint(e.position, dx, dy));
            }).toList(),
          );
          break;
      }
    });
    _scheduleAutoSave();
  }

  void _changeDoorType(DoorType type) {
    if (_template == null || _selectedDoorId == null) return;
    setState(() {
      _template = _template!.copyWith(
        doors: _template!.doors
            .map((e) => e.id == _selectedDoorId ? e.copyWith(type: type, animationStyle: _animationForDoorType(type)) : e)
            .toList(),
      );
    });
    _scheduleAutoSave();
  }

  void _changeLightType(LightType type) {
    if (_template == null || _selectedLightId == null) return;
    setState(() {
      _template = _template!.copyWith(
        lights: _template!.lights
            .map((e) => e.id == _selectedLightId ? e.copyWith(type: type, color: _colorForLightType(type)) : e)
            .toList(),
      );
    });
    _scheduleAutoSave();
  }

  void _changeServiceType(ServicePointType type) {
    if (_template == null || _selectedServiceId == null) return;
    setState(() {
      _template = _template!.copyWith(
        servicePoints: _template!.servicePoints
            .map((e) => e.id == _selectedServiceId ? e.copyWith(type: type) : e)
            .toList(),
      );
    });
    _scheduleAutoSave();
  }

  void _changePartType(AircraftPartType type) {
    if (_template == null || _selectedPartId == null) return;
    setState(() {
      _template = _template!.copyWith(
        parts: _template!.parts
            .map((e) => e.id == _selectedPartId ? e.copyWith(type: type) : e)
            .toList(),
      );
    });
    _scheduleAutoSave();
  }

  bool get _isDesktop => MediaQuery.of(context).size.width >= 1100;

  String get _sourceLabel {
    if (_usingLiveAircraft && _liveSim != null) return 'SimLink Live';
    if (_selectedAircraft != null) return 'Hangar';
    return 'No Source';
  }

  String get _aircraftTitle {
    if (_usingLiveAircraft && _liveSim != null) {
      final t = _liveSim!.title.trim();
      return t.isEmpty ? 'Live Aircraft' : t;
    }
    return _selectedAircraft?.title ?? 'No aircraft selected';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _PreviewCard(
      title: _aircraftTitle,
      sourceLabel: _sourceLabel,
      family: _family,
      template: _template,
      selectedPartId: _selectedPartId,
      selectedDoorId: _selectedDoorId,
      selectedLightId: _selectedLightId,
      selectedServiceId: _selectedServiceId,
      previewAspect: _isDesktop ? _desktopPreviewAspect : _mobilePreviewAspect,
      isMobile: !_isDesktop,
    );

    final side = _BuilderSidePanel(
      loadingHangar: _loadingHangar,
      liveSim: _liveSim,
      usingLiveAircraft: _usingLiveAircraft,
      hangarAircraft: _hangarAircraft,
      selectedAircraft: _selectedAircraft,
      family: _family,
      layer: _layer,
      template: _template,
      selectedPartId: _selectedPartId,
      selectedDoorId: _selectedDoorId,
      selectedLightId: _selectedLightId,
      selectedServiceId: _selectedServiceId,
      selectedPart: _selectedPart,
      selectedDoor: _selectedDoor,
      selectedLight: _selectedLight,
      selectedService: _selectedService,
      onUseLiveAircraft: _selectLiveAircraft,
      onSelectHangarAircraft: _selectHangarAircraft,
      onFamilyChanged: _setFamily,
      onLayerChanged: _setLayer,
      onSelectPart: _selectPart,
      onSelectDoor: _selectDoor,
      onSelectLight: _selectLight,
      onSelectService: _selectService,
      onRenameSelected: _renameSelected,
      onToggleEnabled: _toggleSelectedEnabled,
      onNudge: _nudgeSelected,
      onChangePartType: _changePartType,
      onChangeDoorType: _changeDoorType,
      onChangeLightType: _changeLightType,
      onChangeServiceType: _changeServiceType,
      onSaveTemplate: () => _saveTemplate(showFeedback: true),
      onAddPart: _addPart,
      onAddDoor: _addDoor,
      onAddLight: _addLight,
      onAddService: _addService,
      onDeleteSelected: _deleteSelected,
      onRegenerate: () {
        if (_usingLiveAircraft) {
          _buildTemplateFromLive();
        } else {
          _buildTemplateFromSelectedAircraft();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aircraft Layout Builder'),
        actions: [
          if (_template != null)
            IconButton(
              onPressed: () => _saveTemplate(showFeedback: true),
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save template',
            ),
          if (_template != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_template!.parts.length} parts • ${_template!.doors.length} doors • ${_template!.lights.length} lights • ${_template!.servicePoints.length} service',
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isDesktop
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: preview),
                    const SizedBox(width: 16),
                    SizedBox(width: 420, child: side),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.44,
                      child: preview,
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: side),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String sourceLabel;
  final GroundOpsAircraftFamily family;
  final GroundOpsTemplate? template;
  final String? selectedPartId;
  final String? selectedDoorId;
  final String? selectedLightId;
  final String? selectedServiceId;
  final double previewAspect;
  final bool isMobile;

  const _PreviewCard({
    required this.title,
    required this.sourceLabel,
    required this.family,
    required this.template,
    required this.selectedPartId,
    required this.selectedDoorId,
    required this.selectedLightId,
    required this.selectedServiceId,
    required this.previewAspect,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                _TinyBadge(label: sourceLabel),
                _TinyBadge(label: _familyLabel(family)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.outline.withOpacity(0.15)),
                ),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.65,
                    maxScale: 4.0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: isMobile ? 420 : 0,
                      ),
                      child: AspectRatio(
                        aspectRatio: previewAspect,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: colors.surface,
                            child: CustomPaint(
                              painter: GroundOpsPainter(
                                template: template,
                                selectedPartId: selectedPartId,
                                selectedDoorId: selectedDoorId,
                                selectedLightId: selectedLightId,
                                selectedServicePointId: selectedServiceId,
                                showLabels: true,
                                showDoors: true,
                                showLights: true,
                                showServicePoints: true,
                                showGrid: false,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Doors, lights, parts, and service points are now all selectable/editable layers.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.70),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderSidePanel extends StatelessWidget {
  final bool loadingHangar;
  final SimLinkData? liveSim;
  final bool usingLiveAircraft;
  final List<LearnedAircraft> hangarAircraft;
  final LearnedAircraft? selectedAircraft;
  final GroundOpsAircraftFamily family;
  final BuilderLayer layer;
  final GroundOpsTemplate? template;

  final String? selectedPartId;
  final String? selectedDoorId;
  final String? selectedLightId;
  final String? selectedServiceId;

  final AircraftPolygonPart? selectedPart;
  final GroundDoor? selectedDoor;
  final GroundLight? selectedLight;
  final GroundServicePoint? selectedService;

  final VoidCallback onUseLiveAircraft;
  final ValueChanged<LearnedAircraft> onSelectHangarAircraft;
  final ValueChanged<GroundOpsAircraftFamily> onFamilyChanged;
  final ValueChanged<BuilderLayer> onLayerChanged;
  final ValueChanged<String> onSelectPart;
  final ValueChanged<String> onSelectDoor;
  final ValueChanged<String> onSelectLight;
  final ValueChanged<String> onSelectService;
  final VoidCallback onRenameSelected;
  final VoidCallback onToggleEnabled;
  final void Function(double dx, double dy) onNudge;
  final ValueChanged<AircraftPartType> onChangePartType;
  final ValueChanged<DoorType> onChangeDoorType;
  final ValueChanged<LightType> onChangeLightType;
  final ValueChanged<ServicePointType> onChangeServiceType;
  final VoidCallback onSaveTemplate;
  final ValueChanged<AircraftPartType> onAddPart;
  final VoidCallback onAddDoor;
  final ValueChanged<LightType> onAddLight;
  final ValueChanged<ServicePointType> onAddService;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRegenerate;

  const _BuilderSidePanel({
    required this.loadingHangar,
    required this.liveSim,
    required this.usingLiveAircraft,
    required this.hangarAircraft,
    required this.selectedAircraft,
    required this.family,
    required this.layer,
    required this.template,
    required this.selectedPartId,
    required this.selectedDoorId,
    required this.selectedLightId,
    required this.selectedServiceId,
    required this.selectedPart,
    required this.selectedDoor,
    required this.selectedLight,
    required this.selectedService,
    required this.onUseLiveAircraft,
    required this.onSelectHangarAircraft,
    required this.onFamilyChanged,
    required this.onLayerChanged,
    required this.onSelectPart,
    required this.onSelectDoor,
    required this.onSelectLight,
    required this.onSelectService,
    required this.onRenameSelected,
    required this.onToggleEnabled,
    required this.onNudge,
    required this.onChangePartType,
    required this.onChangeDoorType,
    required this.onChangeLightType,
    required this.onChangeServiceType,
    required this.onSaveTemplate,
    required this.onAddPart,
    required this.onAddDoor,
    required this.onAddLight,
    required this.onAddService,
    required this.onDeleteSelected,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('Aircraft Source', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (liveSim != null)
            _SourceTile(
              title: liveSim!.title.trim().isEmpty ? 'Live Aircraft' : liveSim!.title,
              subtitle: 'Use aircraft coming from SimLink',
              selected: usingLiveAircraft,
              leading: Icons.sensors,
              onTap: onUseLiveAircraft,
            )
          else
            const _EmptyHint(text: 'No live SimLink aircraft detected right now.'),
          const SizedBox(height: 12),
          if (loadingHangar)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hangarAircraft.isEmpty)
            const _EmptyHint(text: 'No aircraft found in your hangar.')
          else
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedAircraft?.id,
              decoration: const InputDecoration(
                labelText: 'Hangar aircraft',
                border: OutlineInputBorder(),
              ),
              items: hangarAircraft.map((ac) {
                return DropdownMenuItem<String>(
                  value: ac.id,
                  child: Text(ac.title, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                final ac = hangarAircraft.firstWhere((e) => e.id == value);
                onSelectHangarAircraft(ac);
              },
            ),
          const SizedBox(height: 18),
          Text('Aircraft Family', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GroundOpsAircraftFamily.values.map((f) {
              return ChoiceChip(
                label: Text(_familyLabel(f)),
                selected: family == f,
                onSelected: (_) => onFamilyChanged(f),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: template == null ? null : onRegenerate,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Regenerate Layout'),
            ),
          ),
          const SizedBox(height: 18),
          Text('Editable Layer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BuilderLayer.values.map((l) {
              return ChoiceChip(
                label: Text(_layerLabel(l)),
                selected: layer == l,
                onSelected: (_) => onLayerChanged(l),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onSaveTemplate,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              if (layer == BuilderLayer.parts)
                OutlinedButton.icon(
                  onPressed: () => onAddPart(AircraftPartType.fuselage),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Add part'),
                ),
              if (layer == BuilderLayer.doors)
                OutlinedButton.icon(
                  onPressed: onAddDoor,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add door'),
                ),
              if (layer == BuilderLayer.lights)
                OutlinedButton.icon(
                  onPressed: () => onAddLight(LightType.taxi),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add light'),
                ),
              if (layer == BuilderLayer.services)
                OutlinedButton.icon(
                  onPressed: () => onAddService(ServicePointType.fuel),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add service'),
                ),
              OutlinedButton.icon(
                onPressed: onDeleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete selected'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _LayerList(
            layer: layer,
            template: template,
            selectedPartId: selectedPartId,
            selectedDoorId: selectedDoorId,
            selectedLightId: selectedLightId,
            selectedServiceId: selectedServiceId,
            onSelectPart: onSelectPart,
            onSelectDoor: onSelectDoor,
            onSelectLight: onSelectLight,
            onSelectService: onSelectService,
          ),
          const SizedBox(height: 18),
          Text('Inspector', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _InspectorCard(
            layer: layer,
            selectedPart: selectedPart,
            selectedDoor: selectedDoor,
            selectedLight: selectedLight,
            selectedService: selectedService,
            onRenameSelected: onRenameSelected,
            onToggleEnabled: onToggleEnabled,
            onNudge: onNudge,
            onChangePartType: onChangePartType,
            onChangeDoorType: onChangeDoorType,
            onChangeLightType: onChangeLightType,
            onChangeServiceType: onChangeServiceType,
          ),
        ],
      ),
    );
  }
}

class _LayerList extends StatelessWidget {
  final BuilderLayer layer;
  final GroundOpsTemplate? template;
  final String? selectedPartId;
  final String? selectedDoorId;
  final String? selectedLightId;
  final String? selectedServiceId;
  final ValueChanged<String> onSelectPart;
  final ValueChanged<String> onSelectDoor;
  final ValueChanged<String> onSelectLight;
  final ValueChanged<String> onSelectService;

  const _LayerList({
    required this.layer,
    required this.template,
    required this.selectedPartId,
    required this.selectedDoorId,
    required this.selectedLightId,
    required this.selectedServiceId,
    required this.onSelectPart,
    required this.onSelectDoor,
    required this.onSelectLight,
    required this.onSelectService,
  });

  @override
  Widget build(BuildContext context) {
    if (template == null) {
      return const _EmptyHint(text: 'No template generated yet.');
    }

    final items = <Widget>[];

    switch (layer) {
      case BuilderLayer.parts:
        for (final item in template!.parts) {
          items.add(_SelectTile(
            selected: item.id == selectedPartId,
            title: item.name,
            subtitle: item.type.name,
            onTap: () => onSelectPart(item.id),
          ));
        }
        break;
      case BuilderLayer.doors:
        for (final item in template!.doors) {
          items.add(_SelectTile(
            selected: item.id == selectedDoorId,
            title: item.name,
            subtitle: '${item.type.name} • ${item.enabled ? "enabled" : "disabled"}',
            onTap: () => onSelectDoor(item.id),
          ));
        }
        break;
      case BuilderLayer.lights:
        for (final item in template!.lights) {
          items.add(_SelectTile(
            selected: item.id == selectedLightId,
            title: item.name,
            subtitle: '${item.type.name} • ${item.enabled ? "enabled" : "disabled"}',
            onTap: () => onSelectLight(item.id),
          ));
        }
        break;
      case BuilderLayer.services:
        for (final item in template!.servicePoints) {
          items.add(_SelectTile(
            selected: item.id == selectedServiceId,
            title: item.name,
            subtitle: '${item.type.name} • ${item.enabled ? "enabled" : "disabled"}',
            onTap: () => onSelectService(item.id),
          ));
        }
        break;
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView(
        children: items.isEmpty ? const [Padding(
          padding: EdgeInsets.all(14),
          child: Text('Nothing here yet.'),
        )] : items,
      ),
    );
  }
}

class _InspectorCard extends StatelessWidget {
  final BuilderLayer layer;
  final AircraftPolygonPart? selectedPart;
  final GroundDoor? selectedDoor;
  final GroundLight? selectedLight;
  final GroundServicePoint? selectedService;
  final VoidCallback onRenameSelected;
  final VoidCallback onToggleEnabled;
  final void Function(double dx, double dy) onNudge;
  final ValueChanged<AircraftPartType> onChangePartType;
  final ValueChanged<DoorType> onChangeDoorType;
  final ValueChanged<LightType> onChangeLightType;
  final ValueChanged<ServicePointType> onChangeServiceType;

  const _InspectorCard({
    required this.layer,
    required this.selectedPart,
    required this.selectedDoor,
    required this.selectedLight,
    required this.selectedService,
    required this.onRenameSelected,
    required this.onToggleEnabled,
    required this.onNudge,
    required this.onChangePartType,
    required this.onChangeDoorType,
    required this.onChangeLightType,
    required this.onChangeServiceType,
  });

  @override
  Widget build(BuildContext context) {
    final selectedName = switch (layer) {
      BuilderLayer.parts => selectedPart?.name,
      BuilderLayer.doors => selectedDoor?.name,
      BuilderLayer.lights => selectedLight?.name,
      BuilderLayer.services => selectedService?.name,
    };

    if (selectedName == null) {
      return const _EmptyHint(text: 'Select an item to edit it.');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selectedName, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onRenameSelected,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Rename'),
              ),
              if (layer != BuilderLayer.parts)
                OutlinedButton.icon(
                  onPressed: onToggleEnabled,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Toggle enabled'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          switch (layer) {
            BuilderLayer.parts => DropdownButtonFormField<AircraftPartType>(
                value: selectedPart!.type,
                decoration: const InputDecoration(
                  labelText: 'Part type',
                  border: OutlineInputBorder(),
                ),
                items: AircraftPartType.values.map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChangePartType(v);
                },
              ),
            BuilderLayer.doors => DropdownButtonFormField<DoorType>(
                value: selectedDoor!.type,
                decoration: const InputDecoration(
                  labelText: 'Door type',
                  border: OutlineInputBorder(),
                ),
                items: DoorType.values.map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChangeDoorType(v);
                },
              ),
            BuilderLayer.lights => DropdownButtonFormField<LightType>(
                value: selectedLight!.type,
                decoration: const InputDecoration(
                  labelText: 'Light type',
                  border: OutlineInputBorder(),
                ),
                items: LightType.values.map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChangeLightType(v);
                },
              ),
            BuilderLayer.services => DropdownButtonFormField<ServicePointType>(
                value: selectedService!.type,
                decoration: const InputDecoration(
                  labelText: 'Service type',
                  border: OutlineInputBorder(),
                ),
                items: ServicePointType.values.map((e) {
                  return DropdownMenuItem(value: e, child: Text(e.name));
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChangeServiceType(v);
                },
              ),
          },
          const SizedBox(height: 16),
          const Text('Nudge'),
          const SizedBox(height: 8),
          _NudgePad(onNudge: onNudge),
        ],
      ),
    );
  }
}

class _NudgePad extends StatelessWidget {
  final void Function(double dx, double dy) onNudge;

  const _NudgePad({required this.onNudge});

  @override
  Widget build(BuildContext context) {
    const step = 0.01;

    return Column(
      children: [
        Center(
          child: IconButton(
            onPressed: () => onNudge(0, -step),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => onNudge(-step, 0),
              icon: const Icon(Icons.keyboard_arrow_left),
            ),
            const SizedBox(width: 18),
            IconButton(
              onPressed: () => onNudge(step, 0),
              icon: const Icon(Icons.keyboard_arrow_right),
            ),
          ],
        ),
        Center(
          child: IconButton(
            onPressed: () => onNudge(0, step),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ),
      ],
    );
  }
}

class _SelectTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SelectTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      selectedTileColor: colors.primary.withOpacity(0.08),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 18,
      ),
      onTap: onTap,
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final IconData leading;
  final VoidCallback onTap;

  const _SourceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colors.primary.withOpacity(0.08) : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.primary : colors.outline.withOpacity(0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(leading),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String label;

  const _TinyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.primary.withOpacity(0.20)),
      ),
      child: Text(label),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colors.surfaceContainerHighest.withOpacity(0.25),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withOpacity(0.70),
            ),
      ),
    );
  }
}

Future<String?> _showTextEditDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

List<NormalizedPoint> _shiftPoints(List<NormalizedPoint> points, double dx, double dy) {
  return points.map((p) => _shiftPoint(p, dx, dy)).toList();
}

NormalizedPoint _shiftPoint(NormalizedPoint p, double dx, double dy) {
  return NormalizedPoint(
    (p.x + dx).clamp(0.0, 1.0),
    (p.y + dy).clamp(0.0, 1.0),
  );
}

String _familyLabel(GroundOpsAircraftFamily family) {
  switch (family) {
    case GroundOpsAircraftFamily.gaSingle:
      return 'GA Single';
    case GroundOpsAircraftFamily.gaTwin:
      return 'GA Twin';
    case GroundOpsAircraftFamily.airliner:
      return 'Airliner';
    case GroundOpsAircraftFamily.helicopter:
      return 'Helicopter';
  }
}

String _layerLabel(BuilderLayer layer) {
  switch (layer) {
    case BuilderLayer.parts:
      return 'Parts';
    case BuilderLayer.doors:
      return 'Doors';
    case BuilderLayer.lights:
      return 'Lights';
    case BuilderLayer.services:
      return 'Services';
  }
}

String _slugify(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return 'unknown_aircraft';

  return text
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}