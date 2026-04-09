import 'package:flutter/material.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/learned_aircraft.dart';

enum GroundOpsAircraftFamily {
  gaSingle,
  gaTwin,
  airliner,
  helicopter,
}

class GroundOpsTemplateCatalog {
  static GroundOpsAircraftFamily inferFamily({
    String? title,
    LearnedAircraft? aircraft,
  }) {
    final text = '${title ?? ''} ${aircraft?.title ?? ''}'.toLowerCase();

    if (aircraft?.isHelicopter == true ||
        text.contains('helicopter') ||
        text.contains('heli') ||
        text.contains('r44') ||
        text.contains('r66') ||
        text.contains('bell ') ||
        text.contains('h125') ||
        text.contains('ec135') ||
        text.contains('uh-') ||
        text.contains('ah-')) {
      return GroundOpsAircraftFamily.helicopter;
    }

    if (text.contains('a320') ||
        text.contains('a321') ||
        text.contains('a330') ||
        text.contains('a350') ||
        text.contains('a380') ||
        text.contains('b737') ||
        text.contains('737') ||
        text.contains('b747') ||
        text.contains('747') ||
        text.contains('b757') ||
        text.contains('757') ||
        text.contains('b767') ||
        text.contains('767') ||
        text.contains('b777') ||
        text.contains('777') ||
        text.contains('b787') ||
        text.contains('787') ||
        text.contains('embraer') ||
        text.contains('e190') ||
        text.contains('e195') ||
        text.contains('crj') ||
        text.contains('md-') ||
        text.contains('dc-')) {
      return GroundOpsAircraftFamily.airliner;
    }

    if (text.contains('baron') ||
        text.contains('seneca') ||
        text.contains('duchess') ||
        text.contains('king air') ||
        text.contains('beech 58') ||
        text.contains('da62') ||
        text.contains('bn-2') ||
        text.contains('twin') ||
        text.contains('pa-34')) {
      return GroundOpsAircraftFamily.gaTwin;
    }

    return GroundOpsAircraftFamily.gaSingle;
  }

  static GroundOpsTemplate buildSeed({
    required String aircraftId,
    required String aircraftName,
    required GroundOpsAircraftFamily family,
    String? manufacturer,
    String? variant,
  }) {
    switch (family) {
      case GroundOpsAircraftFamily.gaSingle:
        return _gaSingle(
          aircraftId: aircraftId,
          aircraftName: aircraftName,
          manufacturer: manufacturer,
          variant: variant,
        );
      case GroundOpsAircraftFamily.gaTwin:
        return _gaTwin(
          aircraftId: aircraftId,
          aircraftName: aircraftName,
          manufacturer: manufacturer,
          variant: variant,
        );
      case GroundOpsAircraftFamily.airliner:
        return _airliner(
          aircraftId: aircraftId,
          aircraftName: aircraftName,
          manufacturer: manufacturer,
          variant: variant,
        );
      case GroundOpsAircraftFamily.helicopter:
        return _helicopter(
          aircraftId: aircraftId,
          aircraftName: aircraftName,
          manufacturer: manufacturer,
          variant: variant,
        );
    }
  }

  static GroundOpsTemplate _gaSingle({
    required String aircraftId,
    required String aircraftName,
    String? manufacturer,
    String? variant,
  }) {
    return GroundOpsTemplate(
      id: aircraftId,
      name: aircraftName,
      aircraftCode: aircraftId.toUpperCase(),
      manufacturer: manufacturer,
      variant: variant ?? 'GA Single',
      parts: const [
        AircraftPolygonPart(
          id: 'fuselage',
          name: 'Fuselage',
          type: AircraftPartType.fuselage,
          trackCondition: true,
          systemKey: 'fuselage',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.485, 0.10),
            NormalizedPoint(0.515, 0.10),
            NormalizedPoint(0.555, 0.18),
            NormalizedPoint(0.555, 0.34),
            NormalizedPoint(0.535, 0.74),
            NormalizedPoint(0.520, 0.90),
            NormalizedPoint(0.500, 0.95),
            NormalizedPoint(0.480, 0.90),
            NormalizedPoint(0.465, 0.74),
            NormalizedPoint(0.445, 0.34),
            NormalizedPoint(0.445, 0.18),
          ],
        ),
        AircraftPolygonPart(
          id: 'wing_left',
          name: 'Left Wing',
          type: AircraftPartType.wingLeft,
          trackCondition: true,
          systemKey: 'left_wing',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.482, 0.36),
            NormalizedPoint(0.175, 0.325),
            NormalizedPoint(0.115, 0.345),
            NormalizedPoint(0.095, 0.390),
            NormalizedPoint(0.165, 0.415),
            NormalizedPoint(0.482, 0.405),
          ],
        ),
        AircraftPolygonPart(
          id: 'wing_right',
          name: 'Right Wing',
          type: AircraftPartType.wingRight,
          trackCondition: true,
          systemKey: 'right_wing',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.518, 0.36),
            NormalizedPoint(0.825, 0.325),
            NormalizedPoint(0.885, 0.345),
            NormalizedPoint(0.905, 0.390),
            NormalizedPoint(0.835, 0.415),
            NormalizedPoint(0.518, 0.405),
          ],
        ),
        AircraftPolygonPart(
          id: 'flap_left',
          name: 'Left Flap',
          type: AircraftPartType.flapLeft,
          trackCondition: true,
          systemKey: 'flaps',
          colorHint: Colors.orange,
          points: [
            NormalizedPoint(0.360, 0.392),
            NormalizedPoint(0.210, 0.390),
            NormalizedPoint(0.205, 0.414),
            NormalizedPoint(0.360, 0.414),
          ],
        ),
        AircraftPolygonPart(
          id: 'flap_right',
          name: 'Right Flap',
          type: AircraftPartType.flapRight,
          trackCondition: true,
          systemKey: 'flaps',
          colorHint: Colors.orange,
          points: [
            NormalizedPoint(0.640, 0.392),
            NormalizedPoint(0.790, 0.390),
            NormalizedPoint(0.795, 0.414),
            NormalizedPoint(0.640, 0.414),
          ],
        ),
        AircraftPolygonPart(
          id: 'aileron_left',
          name: 'Left Aileron',
          type: AircraftPartType.aileronLeft,
          trackCondition: true,
          systemKey: 'ailerons',
          colorHint: Colors.teal,
          points: [
            NormalizedPoint(0.205, 0.390),
            NormalizedPoint(0.120, 0.384),
            NormalizedPoint(0.120, 0.410),
            NormalizedPoint(0.205, 0.414),
          ],
        ),
        AircraftPolygonPart(
          id: 'aileron_right',
          name: 'Right Aileron',
          type: AircraftPartType.aileronRight,
          trackCondition: true,
          systemKey: 'ailerons',
          colorHint: Colors.teal,
          points: [
            NormalizedPoint(0.795, 0.390),
            NormalizedPoint(0.880, 0.384),
            NormalizedPoint(0.880, 0.410),
            NormalizedPoint(0.795, 0.414),
          ],
        ),
        AircraftPolygonPart(
          id: 'elevator_left',
          name: 'Left Elevator',
          type: AircraftPartType.elevatorLeft,
          trackCondition: true,
          systemKey: 'elevators',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.482, 0.835),
            NormalizedPoint(0.345, 0.820),
            NormalizedPoint(0.305, 0.840),
            NormalizedPoint(0.480, 0.855),
          ],
        ),
        AircraftPolygonPart(
          id: 'elevator_right',
          name: 'Right Elevator',
          type: AircraftPartType.elevatorRight,
          trackCondition: true,
          systemKey: 'elevators',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.518, 0.835),
            NormalizedPoint(0.655, 0.820),
            NormalizedPoint(0.695, 0.840),
            NormalizedPoint(0.520, 0.855),
          ],
        ),
        AircraftPolygonPart(
          id: 'rudder',
          name: 'Rudder',
          type: AircraftPartType.rudder,
          trackCondition: true,
          systemKey: 'rudder',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.485, 0.760),
            NormalizedPoint(0.515, 0.760),
            NormalizedPoint(0.528, 0.860),
            NormalizedPoint(0.500, 0.905),
            NormalizedPoint(0.472, 0.860),
          ],
        ),
        AircraftPolygonPart(
          id: 'engine_single',
          name: 'Engine',
          type: AircraftPartType.engineSingle,
          trackCondition: true,
          systemKey: 'engine',
          colorHint: Colors.redAccent,
          points: [
            NormalizedPoint(0.460, 0.070),
            NormalizedPoint(0.540, 0.070),
            NormalizedPoint(0.555, 0.120),
            NormalizedPoint(0.445, 0.120),
          ],
        ),
        AircraftPolygonPart(
          id: 'nose_gear',
          name: 'Nose Gear',
          type: AircraftPartType.noseGear,
          trackCondition: true,
          systemKey: 'nose_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.485, 0.165),
            NormalizedPoint(0.515, 0.165),
            NormalizedPoint(0.520, 0.200),
            NormalizedPoint(0.480, 0.200),
          ],
        ),
        AircraftPolygonPart(
          id: 'main_gear_left',
          name: 'Left Main Gear',
          type: AircraftPartType.mainGearLeft,
          trackCondition: true,
          systemKey: 'left_main_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.410, 0.500),
            NormalizedPoint(0.445, 0.500),
            NormalizedPoint(0.450, 0.545),
            NormalizedPoint(0.405, 0.545),
          ],
        ),
        AircraftPolygonPart(
          id: 'main_gear_right',
          name: 'Right Main Gear',
          type: AircraftPartType.mainGearRight,
          trackCondition: true,
          systemKey: 'right_main_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.555, 0.500),
            NormalizedPoint(0.590, 0.500),
            NormalizedPoint(0.595, 0.545),
            NormalizedPoint(0.550, 0.545),
          ],
        ),
      ],
      doors: const [
        GroundDoor(
          id: 'main_left',
          name: 'Pilot Door',
          type: DoorType.mainEntry,
          code: 'L1',
          points: [
            NormalizedPoint(0.435, 0.215),
            NormalizedPoint(0.468, 0.215),
            NormalizedPoint(0.468, 0.315),
            NormalizedPoint(0.435, 0.315),
          ],
        ),
        GroundDoor(
          id: 'main_right',
          name: 'Passenger Door',
          type: DoorType.mainEntry,
          code: 'R1',
          points: [
            NormalizedPoint(0.532, 0.215),
            NormalizedPoint(0.565, 0.215),
            NormalizedPoint(0.565, 0.315),
            NormalizedPoint(0.532, 0.315),
          ],
        ),
      ],
      lights: const [
        GroundLight(
          id: 'beacon',
          name: 'Beacon',
          type: LightType.beacon,
          position: NormalizedPoint(0.500, 0.260),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_left',
          name: 'Left Nav',
          type: LightType.navLeft,
          position: NormalizedPoint(0.100, 0.390),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_right',
          name: 'Right Nav',
          type: LightType.navRight,
          position: NormalizedPoint(0.900, 0.390),
          color: Colors.green,
        ),
        GroundLight(
          id: 'strobe_left',
          name: 'Left Strobe',
          type: LightType.strobeLeft,
          position: NormalizedPoint(0.105, 0.386),
          color: Colors.white,
        ),
        GroundLight(
          id: 'strobe_right',
          name: 'Right Strobe',
          type: LightType.strobeRight,
          position: NormalizedPoint(0.895, 0.386),
          color: Colors.white,
        ),
        GroundLight(
          id: 'landing',
          name: 'Landing',
          type: LightType.landing,
          position: NormalizedPoint(0.500, 0.135),
          color: Colors.white,
        ),
      ],
      servicePoints: const [
        GroundServicePoint(
          id: 'fuel_left',
          name: 'Fuel Left',
          type: ServicePointType.fuel,
          position: NormalizedPoint(0.270, 0.355),
        ),
        GroundServicePoint(
          id: 'fuel_right',
          name: 'Fuel Right',
          type: ServicePointType.fuel,
          position: NormalizedPoint(0.730, 0.355),
        ),
        GroundServicePoint(
          id: 'gpu',
          name: 'GPU',
          type: ServicePointType.gpu,
          position: NormalizedPoint(0.575, 0.180),
        ),
      ],
      propCenter: const NormalizedPoint(0.500, 0.055),
      propRadius: 0.055,
    );
  }

  static GroundOpsTemplate _gaTwin({
    required String aircraftId,
    required String aircraftName,
    String? manufacturer,
    String? variant,
  }) {
    return GroundOpsTemplate(
      id: aircraftId,
      name: aircraftName,
      aircraftCode: aircraftId.toUpperCase(),
      manufacturer: manufacturer,
      variant: variant ?? 'GA Twin',
      parts: const [
        AircraftPolygonPart(
          id: 'fuselage',
          name: 'Fuselage',
          type: AircraftPartType.fuselage,
          trackCondition: true,
          systemKey: 'fuselage',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.480, 0.08),
            NormalizedPoint(0.520, 0.08),
            NormalizedPoint(0.555, 0.15),
            NormalizedPoint(0.560, 0.28),
            NormalizedPoint(0.545, 0.74),
            NormalizedPoint(0.525, 0.92),
            NormalizedPoint(0.500, 0.97),
            NormalizedPoint(0.475, 0.92),
            NormalizedPoint(0.455, 0.74),
            NormalizedPoint(0.440, 0.28),
            NormalizedPoint(0.445, 0.15),
          ],
        ),
        AircraftPolygonPart(
          id: 'wing_left',
          name: 'Left Wing',
          type: AircraftPartType.wingLeft,
          trackCondition: true,
          systemKey: 'left_wing',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.485, 0.37),
            NormalizedPoint(0.145, 0.320),
            NormalizedPoint(0.080, 0.350),
            NormalizedPoint(0.070, 0.410),
            NormalizedPoint(0.160, 0.435),
            NormalizedPoint(0.485, 0.420),
          ],
        ),
        AircraftPolygonPart(
          id: 'wing_right',
          name: 'Right Wing',
          type: AircraftPartType.wingRight,
          trackCondition: true,
          systemKey: 'right_wing',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.515, 0.37),
            NormalizedPoint(0.855, 0.320),
            NormalizedPoint(0.920, 0.350),
            NormalizedPoint(0.930, 0.410),
            NormalizedPoint(0.840, 0.435),
            NormalizedPoint(0.515, 0.420),
          ],
        ),
        AircraftPolygonPart(
          id: 'engine_left',
          name: 'Left Engine',
          type: AircraftPartType.engineLeft,
          trackCondition: true,
          systemKey: 'left_engine',
          colorHint: Colors.redAccent,
          points: [
            NormalizedPoint(0.255, 0.335),
            NormalizedPoint(0.320, 0.335),
            NormalizedPoint(0.330, 0.420),
            NormalizedPoint(0.245, 0.420),
          ],
        ),
        AircraftPolygonPart(
          id: 'engine_right',
          name: 'Right Engine',
          type: AircraftPartType.engineRight,
          trackCondition: true,
          systemKey: 'right_engine',
          colorHint: Colors.redAccent,
          points: [
            NormalizedPoint(0.680, 0.335),
            NormalizedPoint(0.745, 0.335),
            NormalizedPoint(0.755, 0.420),
            NormalizedPoint(0.670, 0.420),
          ],
        ),
        AircraftPolygonPart(
          id: 'flap_left',
          name: 'Left Flap',
          type: AircraftPartType.flapLeft,
          trackCondition: true,
          systemKey: 'flaps',
          colorHint: Colors.orange,
          points: [
            NormalizedPoint(0.395, 0.405),
            NormalizedPoint(0.235, 0.405),
            NormalizedPoint(0.235, 0.432),
            NormalizedPoint(0.395, 0.432),
          ],
        ),
        AircraftPolygonPart(
          id: 'flap_right',
          name: 'Right Flap',
          type: AircraftPartType.flapRight,
          trackCondition: true,
          systemKey: 'flaps',
          colorHint: Colors.orange,
          points: [
            NormalizedPoint(0.605, 0.405),
            NormalizedPoint(0.765, 0.405),
            NormalizedPoint(0.765, 0.432),
            NormalizedPoint(0.605, 0.432),
          ],
        ),
        AircraftPolygonPart(
          id: 'aileron_left',
          name: 'Left Aileron',
          type: AircraftPartType.aileronLeft,
          trackCondition: true,
          systemKey: 'ailerons',
          colorHint: Colors.teal,
          points: [
            NormalizedPoint(0.235, 0.403),
            NormalizedPoint(0.095, 0.395),
            NormalizedPoint(0.095, 0.425),
            NormalizedPoint(0.235, 0.432),
          ],
        ),
        AircraftPolygonPart(
          id: 'aileron_right',
          name: 'Right Aileron',
          type: AircraftPartType.aileronRight,
          trackCondition: true,
          systemKey: 'ailerons',
          colorHint: Colors.teal,
          points: [
            NormalizedPoint(0.765, 0.403),
            NormalizedPoint(0.905, 0.395),
            NormalizedPoint(0.905, 0.425),
            NormalizedPoint(0.765, 0.432),
          ],
        ),
        AircraftPolygonPart(
          id: 'elevator_left',
          name: 'Left Elevator',
          type: AircraftPartType.elevatorLeft,
          trackCondition: true,
          systemKey: 'elevators',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.485, 0.845),
            NormalizedPoint(0.335, 0.822),
            NormalizedPoint(0.290, 0.846),
            NormalizedPoint(0.482, 0.868),
          ],
        ),
        AircraftPolygonPart(
          id: 'elevator_right',
          name: 'Right Elevator',
          type: AircraftPartType.elevatorRight,
          trackCondition: true,
          systemKey: 'elevators',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.515, 0.845),
            NormalizedPoint(0.665, 0.822),
            NormalizedPoint(0.710, 0.846),
            NormalizedPoint(0.518, 0.868),
          ],
        ),
        AircraftPolygonPart(
          id: 'rudder',
          name: 'Rudder',
          type: AircraftPartType.rudder,
          trackCondition: true,
          systemKey: 'rudder',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.486, 0.760),
            NormalizedPoint(0.514, 0.760),
            NormalizedPoint(0.525, 0.860),
            NormalizedPoint(0.500, 0.915),
            NormalizedPoint(0.475, 0.860),
          ],
        ),
        AircraftPolygonPart(
          id: 'nose_gear',
          name: 'Nose Gear',
          type: AircraftPartType.noseGear,
          trackCondition: true,
          systemKey: 'nose_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.485, 0.175),
            NormalizedPoint(0.515, 0.175),
            NormalizedPoint(0.518, 0.215),
            NormalizedPoint(0.482, 0.215),
          ],
        ),
        AircraftPolygonPart(
          id: 'main_gear_left',
          name: 'Left Main Gear',
          type: AircraftPartType.mainGearLeft,
          trackCondition: true,
          systemKey: 'left_main_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.410, 0.530),
            NormalizedPoint(0.445, 0.530),
            NormalizedPoint(0.450, 0.580),
            NormalizedPoint(0.405, 0.580),
          ],
        ),
        AircraftPolygonPart(
          id: 'main_gear_right',
          name: 'Right Main Gear',
          type: AircraftPartType.mainGearRight,
          trackCondition: true,
          systemKey: 'right_main_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.555, 0.530),
            NormalizedPoint(0.590, 0.530),
            NormalizedPoint(0.595, 0.580),
            NormalizedPoint(0.550, 0.580),
          ],
        ),
      ],
      doors: const [
        GroundDoor(
          id: 'main_left',
          name: 'Main Door',
          type: DoorType.mainEntry,
          code: 'L1',
          points: [
            NormalizedPoint(0.435, 0.210),
            NormalizedPoint(0.468, 0.210),
            NormalizedPoint(0.468, 0.315),
            NormalizedPoint(0.435, 0.315),
          ],
        ),
        GroundDoor(
          id: 'baggage',
          name: 'Baggage Door',
          type: DoorType.baggage,
          code: 'BAG',
          points: [
            NormalizedPoint(0.532, 0.250),
            NormalizedPoint(0.565, 0.250),
            NormalizedPoint(0.565, 0.320),
            NormalizedPoint(0.532, 0.320),
          ],
        ),
      ],
      lights: const [
        GroundLight(
          id: 'beacon',
          name: 'Beacon',
          type: LightType.beacon,
          position: NormalizedPoint(0.500, 0.255),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_left',
          name: 'Left Nav',
          type: LightType.navLeft,
          position: NormalizedPoint(0.072, 0.395),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_right',
          name: 'Right Nav',
          type: LightType.navRight,
          position: NormalizedPoint(0.928, 0.395),
          color: Colors.green,
        ),
        GroundLight(
          id: 'strobe_left',
          name: 'Left Strobe',
          type: LightType.strobeLeft,
          position: NormalizedPoint(0.075, 0.392),
          color: Colors.white,
        ),
        GroundLight(
          id: 'strobe_right',
          name: 'Right Strobe',
          type: LightType.strobeRight,
          position: NormalizedPoint(0.925, 0.392),
          color: Colors.white,
        ),
      ],
      servicePoints: const [
        GroundServicePoint(
          id: 'fuel_left',
          name: 'Fuel Left',
          type: ServicePointType.fuel,
          position: NormalizedPoint(0.300, 0.350),
        ),
        GroundServicePoint(
          id: 'fuel_right',
          name: 'Fuel Right',
          type: ServicePointType.fuel,
          position: NormalizedPoint(0.700, 0.350),
        ),
        GroundServicePoint(
          id: 'gpu',
          name: 'GPU',
          type: ServicePointType.gpu,
          position: NormalizedPoint(0.580, 0.185),
        ),
      ],
      propCenter: const NormalizedPoint(0.500, 0.060),
      propRadius: 0.040,
    );
  }

  static GroundOpsTemplate _airliner({
    required String aircraftId,
    required String aircraftName,
    String? manufacturer,
    String? variant,
  }) {
    return GroundOpsTemplate(
      id: aircraftId,
      name: aircraftName,
      aircraftCode: aircraftId.toUpperCase(),
      manufacturer: manufacturer,
      variant: variant ?? 'Airliner',
      parts: const [
        AircraftPolygonPart(
          id: 'fuselage',
          name: 'Fuselage',
          type: AircraftPartType.fuselage,
          trackCondition: true,
          systemKey: 'fuselage',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.482, 0.03),
            NormalizedPoint(0.518, 0.03),
            NormalizedPoint(0.550, 0.08),
            NormalizedPoint(0.565, 0.18),
            NormalizedPoint(0.560, 0.82),
            NormalizedPoint(0.545, 0.93),
            NormalizedPoint(0.518, 0.985),
            NormalizedPoint(0.482, 0.985),
            NormalizedPoint(0.455, 0.93),
            NormalizedPoint(0.440, 0.82),
            NormalizedPoint(0.435, 0.18),
            NormalizedPoint(0.450, 0.08),
          ],
        ),
        AircraftPolygonPart(
          id: 'wing_left',
          name: 'Left Wing',
          type: AircraftPartType.wingLeft,
          trackCondition: true,
          systemKey: 'left_wing',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.485, 0.42),
            NormalizedPoint(0.230, 0.33),
            NormalizedPoint(0.085, 0.29),
            NormalizedPoint(0.055, 0.34),
            NormalizedPoint(0.145, 0.43),
            NormalizedPoint(0.300, 0.48),
            NormalizedPoint(0.485, 0.46),
          ],
        ),
        AircraftPolygonPart(
          id: 'wing_right',
          name: 'Right Wing',
          type: AircraftPartType.wingRight,
          trackCondition: true,
          systemKey: 'right_wing',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.515, 0.42),
            NormalizedPoint(0.770, 0.33),
            NormalizedPoint(0.915, 0.29),
            NormalizedPoint(0.945, 0.34),
            NormalizedPoint(0.855, 0.43),
            NormalizedPoint(0.700, 0.48),
            NormalizedPoint(0.515, 0.46),
          ],
        ),
        AircraftPolygonPart(
          id: 'engine_left',
          name: 'Left Engine',
          type: AircraftPartType.engineLeft,
          trackCondition: true,
          systemKey: 'left_engine',
          colorHint: Colors.redAccent,
          points: [
            NormalizedPoint(0.285, 0.425),
            NormalizedPoint(0.340, 0.425),
            NormalizedPoint(0.350, 0.500),
            NormalizedPoint(0.275, 0.500),
          ],
        ),
        AircraftPolygonPart(
          id: 'engine_right',
          name: 'Right Engine',
          type: AircraftPartType.engineRight,
          trackCondition: true,
          systemKey: 'right_engine',
          colorHint: Colors.redAccent,
          points: [
            NormalizedPoint(0.660, 0.425),
            NormalizedPoint(0.715, 0.425),
            NormalizedPoint(0.725, 0.500),
            NormalizedPoint(0.650, 0.500),
          ],
        ),
        AircraftPolygonPart(
          id: 'flap_left',
          name: 'Left Flap',
          type: AircraftPartType.flapLeft,
          trackCondition: true,
          systemKey: 'flaps',
          colorHint: Colors.orange,
          points: [
            NormalizedPoint(0.420, 0.455),
            NormalizedPoint(0.225, 0.430),
            NormalizedPoint(0.210, 0.456),
            NormalizedPoint(0.405, 0.480),
          ],
        ),
        AircraftPolygonPart(
          id: 'flap_right',
          name: 'Right Flap',
          type: AircraftPartType.flapRight,
          trackCondition: true,
          systemKey: 'flaps',
          colorHint: Colors.orange,
          points: [
            NormalizedPoint(0.580, 0.455),
            NormalizedPoint(0.775, 0.430),
            NormalizedPoint(0.790, 0.456),
            NormalizedPoint(0.595, 0.480),
          ],
        ),
        AircraftPolygonPart(
          id: 'aileron_left',
          name: 'Left Aileron',
          type: AircraftPartType.aileronLeft,
          trackCondition: true,
          systemKey: 'ailerons',
          colorHint: Colors.teal,
          points: [
            NormalizedPoint(0.225, 0.430),
            NormalizedPoint(0.090, 0.382),
            NormalizedPoint(0.082, 0.405),
            NormalizedPoint(0.210, 0.456),
          ],
        ),
        AircraftPolygonPart(
          id: 'aileron_right',
          name: 'Right Aileron',
          type: AircraftPartType.aileronRight,
          trackCondition: true,
          systemKey: 'ailerons',
          colorHint: Colors.teal,
          points: [
            NormalizedPoint(0.775, 0.430),
            NormalizedPoint(0.910, 0.382),
            NormalizedPoint(0.918, 0.405),
            NormalizedPoint(0.790, 0.456),
          ],
        ),
        AircraftPolygonPart(
          id: 'elevator_left',
          name: 'Left Elevator',
          type: AircraftPartType.elevatorLeft,
          trackCondition: true,
          systemKey: 'elevators',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.485, 0.875),
            NormalizedPoint(0.330, 0.850),
            NormalizedPoint(0.270, 0.875),
            NormalizedPoint(0.482, 0.900),
          ],
        ),
        AircraftPolygonPart(
          id: 'elevator_right',
          name: 'Right Elevator',
          type: AircraftPartType.elevatorRight,
          trackCondition: true,
          systemKey: 'elevators',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.515, 0.875),
            NormalizedPoint(0.670, 0.850),
            NormalizedPoint(0.730, 0.875),
            NormalizedPoint(0.518, 0.900),
          ],
        ),
        AircraftPolygonPart(
          id: 'rudder',
          name: 'Rudder',
          type: AircraftPartType.rudder,
          trackCondition: true,
          systemKey: 'rudder',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.486, 0.760),
            NormalizedPoint(0.514, 0.760),
            NormalizedPoint(0.528, 0.885),
            NormalizedPoint(0.500, 0.950),
            NormalizedPoint(0.472, 0.885),
          ],
        ),
        AircraftPolygonPart(
          id: 'nose_gear',
          name: 'Nose Gear',
          type: AircraftPartType.noseGear,
          trackCondition: true,
          systemKey: 'nose_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.485, 0.165),
            NormalizedPoint(0.515, 0.165),
            NormalizedPoint(0.520, 0.225),
            NormalizedPoint(0.480, 0.225),
          ],
        ),
        AircraftPolygonPart(
          id: 'main_gear_left',
          name: 'Left Main Gear',
          type: AircraftPartType.mainGearLeft,
          trackCondition: true,
          systemKey: 'left_main_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.445, 0.555),
            NormalizedPoint(0.470, 0.555),
            NormalizedPoint(0.475, 0.625),
            NormalizedPoint(0.442, 0.625),
          ],
        ),
        AircraftPolygonPart(
          id: 'main_gear_right',
          name: 'Right Main Gear',
          type: AircraftPartType.mainGearRight,
          trackCondition: true,
          systemKey: 'right_main_gear',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.530, 0.555),
            NormalizedPoint(0.555, 0.555),
            NormalizedPoint(0.558, 0.625),
            NormalizedPoint(0.525, 0.625),
          ],
        ),
      ],
      doors: const [
        GroundDoor(
          id: 'l1',
          name: 'L1',
          type: DoorType.mainEntry,
          code: 'L1',
          points: [
            NormalizedPoint(0.438, 0.145),
            NormalizedPoint(0.466, 0.145),
            NormalizedPoint(0.466, 0.225),
            NormalizedPoint(0.438, 0.225),
          ],
        ),
        GroundDoor(
          id: 'r1',
          name: 'R1',
          type: DoorType.mainEntry,
          code: 'R1',
          points: [
            NormalizedPoint(0.534, 0.145),
            NormalizedPoint(0.562, 0.145),
            NormalizedPoint(0.562, 0.225),
            NormalizedPoint(0.534, 0.225),
          ],
        ),
        GroundDoor(
          id: 'l2',
          name: 'L2',
          type: DoorType.service,
          code: 'L2',
          points: [
            NormalizedPoint(0.438, 0.505),
            NormalizedPoint(0.466, 0.505),
            NormalizedPoint(0.466, 0.585),
            NormalizedPoint(0.438, 0.585),
          ],
        ),
        GroundDoor(
          id: 'r2',
          name: 'R2',
          type: DoorType.service,
          code: 'R2',
          points: [
            NormalizedPoint(0.534, 0.505),
            NormalizedPoint(0.562, 0.505),
            NormalizedPoint(0.562, 0.585),
            NormalizedPoint(0.534, 0.585),
          ],
        ),
        GroundDoor(
          id: 'cargo_fwd',
          name: 'Forward Cargo',
          type: DoorType.cargo,
          code: 'FWD',
          points: [
            NormalizedPoint(0.410, 0.280),
            NormalizedPoint(0.438, 0.280),
            NormalizedPoint(0.438, 0.345),
            NormalizedPoint(0.410, 0.345),
          ],
        ),
        GroundDoor(
          id: 'cargo_aft',
          name: 'Aft Cargo',
          type: DoorType.cargo,
          code: 'AFT',
          points: [
            NormalizedPoint(0.410, 0.620),
            NormalizedPoint(0.438, 0.620),
            NormalizedPoint(0.438, 0.690),
            NormalizedPoint(0.410, 0.690),
          ],
        ),
      ],
      lights: const [
        GroundLight(
          id: 'beacon_top',
          name: 'Beacon Top',
          type: LightType.beacon,
          position: NormalizedPoint(0.500, 0.260),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_left',
          name: 'Left Nav',
          type: LightType.navLeft,
          position: NormalizedPoint(0.058, 0.338),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_right',
          name: 'Right Nav',
          type: LightType.navRight,
          position: NormalizedPoint(0.942, 0.338),
          color: Colors.green,
        ),
        GroundLight(
          id: 'strobe_left',
          name: 'Left Strobe',
          type: LightType.strobeLeft,
          position: NormalizedPoint(0.060, 0.336),
          color: Colors.white,
        ),
        GroundLight(
          id: 'strobe_right',
          name: 'Right Strobe',
          type: LightType.strobeRight,
          position: NormalizedPoint(0.940, 0.336),
          color: Colors.white,
        ),
        GroundLight(
          id: 'logo',
          name: 'Logo',
          type: LightType.logo,
          position: NormalizedPoint(0.500, 0.850),
          color: Colors.white,
        ),
        GroundLight(
          id: 'taxi',
          name: 'Taxi',
          type: LightType.taxi,
          position: NormalizedPoint(0.500, 0.145),
          color: Colors.white,
        ),
      ],
      servicePoints: const [
        GroundServicePoint(
          id: 'fuel_left',
          name: 'Fuel Left',
          type: ServicePointType.fuel,
          position: NormalizedPoint(0.325, 0.425),
        ),
        GroundServicePoint(
          id: 'fuel_right',
          name: 'Fuel Right',
          type: ServicePointType.fuel,
          position: NormalizedPoint(0.675, 0.425),
        ),
        GroundServicePoint(
          id: 'gpu',
          name: 'GPU',
          type: ServicePointType.gpu,
          position: NormalizedPoint(0.575, 0.165),
        ),
        GroundServicePoint(
          id: 'catering',
          name: 'Catering',
          type: ServicePointType.catering,
          position: NormalizedPoint(0.610, 0.205),
        ),
        GroundServicePoint(
          id: 'baggage_fwd',
          name: 'Baggage FWD',
          type: ServicePointType.baggage,
          position: NormalizedPoint(0.385, 0.315),
        ),
        GroundServicePoint(
          id: 'baggage_aft',
          name: 'Baggage AFT',
          type: ServicePointType.baggage,
          position: NormalizedPoint(0.385, 0.655),
        ),
        GroundServicePoint(
          id: 'water',
          name: 'Water',
          type: ServicePointType.water,
          position: NormalizedPoint(0.605, 0.540),
        ),
        GroundServicePoint(
          id: 'lav',
          name: 'Lavatory',
          type: ServicePointType.lavatory,
          position: NormalizedPoint(0.392, 0.720),
        ),
        GroundServicePoint(
          id: 'pushback',
          name: 'Pushback',
          type: ServicePointType.pushback,
          position: NormalizedPoint(0.500, 0.055),
        ),
      ],
      propCenter: null,
      propRadius: 0.0,
    );
  }

  static GroundOpsTemplate _helicopter({
    required String aircraftId,
    required String aircraftName,
    String? manufacturer,
    String? variant,
  }) {
    return GroundOpsTemplate(
      id: aircraftId,
      name: aircraftName,
      aircraftCode: aircraftId.toUpperCase(),
      manufacturer: manufacturer,
      variant: variant ?? 'Helicopter',
      parts: const [
        AircraftPolygonPart(
          id: 'fuselage',
          name: 'Fuselage',
          type: AircraftPartType.fuselage,
          trackCondition: true,
          systemKey: 'fuselage',
          colorHint: Colors.blueGrey,
          points: [
            NormalizedPoint(0.470, 0.18),
            NormalizedPoint(0.530, 0.18),
            NormalizedPoint(0.580, 0.26),
            NormalizedPoint(0.575, 0.42),
            NormalizedPoint(0.535, 0.50),
            NormalizedPoint(0.520, 0.62),
            NormalizedPoint(0.510, 0.83),
            NormalizedPoint(0.500, 0.95),
            NormalizedPoint(0.490, 0.83),
            NormalizedPoint(0.480, 0.62),
            NormalizedPoint(0.465, 0.50),
            NormalizedPoint(0.425, 0.42),
            NormalizedPoint(0.420, 0.26),
          ],
        ),
        AircraftPolygonPart(
          id: 'main_rotor',
          name: 'Main Rotor Disc',
          type: AircraftPartType.rotorMain,
          trackCondition: true,
          systemKey: 'main_rotor',
          colorHint: Colors.lightBlue,
          points: [
            NormalizedPoint(0.170, 0.330),
            NormalizedPoint(0.500, 0.180),
            NormalizedPoint(0.830, 0.330),
            NormalizedPoint(0.500, 0.480),
          ],
        ),
        AircraftPolygonPart(
          id: 'engine_center',
          name: 'Engine Bay',
          type: AircraftPartType.engineCenter,
          trackCondition: true,
          systemKey: 'engine',
          colorHint: Colors.redAccent,
          points: [
            NormalizedPoint(0.455, 0.205),
            NormalizedPoint(0.545, 0.205),
            NormalizedPoint(0.560, 0.285),
            NormalizedPoint(0.440, 0.285),
          ],
        ),
        AircraftPolygonPart(
          id: 'tail_fin',
          name: 'Tail Fin',
          type: AircraftPartType.rudder,
          trackCondition: true,
          systemKey: 'tail_fin',
          colorHint: Colors.indigo,
          points: [
            NormalizedPoint(0.485, 0.735),
            NormalizedPoint(0.515, 0.735),
            NormalizedPoint(0.535, 0.895),
            NormalizedPoint(0.500, 0.960),
            NormalizedPoint(0.465, 0.895),
          ],
        ),
        AircraftPolygonPart(
          id: 'skid_left',
          name: 'Left Skid',
          type: AircraftPartType.mainGearLeft,
          trackCondition: true,
          systemKey: 'left_skid',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.360, 0.475),
            NormalizedPoint(0.395, 0.475),
            NormalizedPoint(0.420, 0.625),
            NormalizedPoint(0.385, 0.625),
          ],
        ),
        AircraftPolygonPart(
          id: 'skid_right',
          name: 'Right Skid',
          type: AircraftPartType.mainGearRight,
          trackCondition: true,
          systemKey: 'right_skid',
          colorHint: Colors.brown,
          points: [
            NormalizedPoint(0.605, 0.475),
            NormalizedPoint(0.640, 0.475),
            NormalizedPoint(0.615, 0.625),
            NormalizedPoint(0.580, 0.625),
          ],
        ),
      ],
      doors: const [
        GroundDoor(
          id: 'main_left',
          name: 'Crew Door Left',
          type: DoorType.mainEntry,
          code: 'L1',
          points: [
            NormalizedPoint(0.420, 0.285),
            NormalizedPoint(0.455, 0.285),
            NormalizedPoint(0.455, 0.395),
            NormalizedPoint(0.420, 0.395),
          ],
        ),
        GroundDoor(
          id: 'main_right',
          name: 'Crew Door Right',
          type: DoorType.mainEntry,
          code: 'R1',
          points: [
            NormalizedPoint(0.545, 0.285),
            NormalizedPoint(0.580, 0.285),
            NormalizedPoint(0.580, 0.395),
            NormalizedPoint(0.545, 0.395),
          ],
        ),
      ],
      lights: const [
        GroundLight(
          id: 'beacon',
          name: 'Beacon',
          type: LightType.beacon,
          position: NormalizedPoint(0.500, 0.210),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_left',
          name: 'Left Nav',
          type: LightType.navLeft,
          position: NormalizedPoint(0.205, 0.325),
          color: Colors.red,
        ),
        GroundLight(
          id: 'nav_right',
          name: 'Right Nav',
          type: LightType.navRight,
          position: NormalizedPoint(0.795, 0.325),
          color: Colors.green,
        ),
        GroundLight(
          id: 'strobe_top',
          name: 'Top Strobe',
          type: LightType.generic,
          position: NormalizedPoint(0.500, 0.180),
          color: Colors.white,
        ),
        GroundLight(
          id: 'landing',
          name: 'Landing',
          type: LightType.landing,
          position: NormalizedPoint(0.500, 0.420),
          color: Colors.white,
        ),
      ],
      servicePoints: const [
        GroundServicePoint(
          id: 'fuel',
          name: 'Fuel',
          type: ServicePointType.fuel,
          position: NormalizedPoint(0.640, 0.355),
        ),
        GroundServicePoint(
          id: 'gpu',
          name: 'GPU',
          type: ServicePointType.gpu,
          position: NormalizedPoint(0.590, 0.470),
        ),
      ],
      propCenter: const NormalizedPoint(0.500, 0.330),
      propRadius: 0.220,
    );
  }
}