import 'package:skycase/models/radio_state.dart';

typedef J = Map<String, dynamic>;

bool b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v == 1;
  return false;
}

class SimLinkData {
  // ========= BASIC AIRCRAFT STATE =========
  final String title;
  final double latitude;
  final double longitude;
  final double altitude;
  final double heading;
  final double airspeed;
  final double verticalSpeed;
  final double pitch;
  final bool onGround;

  // ========= FUEL =========
  final double fuelGallons;
  final double fuelCapacityGallons;

  // ========= ELECTRICAL =========
  final double mainBusVolts;
  final bool avionicsOn;

  // ========= RADIO =========
  final double com1Active;
  final double com1Standby;
  final bool transmitting;
  final bool receive;

  // ========= ICE =========
  final double structural;

  // ========= GEAR / FLAPS =========
  final bool gearHandleDown;
  final double gearPosition;
  final int flapsIndex;
  final double flapsPercent;

  // ========= ENGINE =========
  final double rpm;

  // ========= PAYLOAD =========
  final PayloadData payload;

  // ========= LIGHTS / DOORS =========
  final MissionData mission;

  // ========= AUTOPILOT =========
  final AutopilotData autopilot;

  // ========= GEAR CONFIG (TYPE) =========
  final GearConfig gear;

  // ========= WEATHER =========
  final WeatherData weather;

  // ========= WEIGHTS =========
  final WeightData weights;

  // ========= ENGINE TYPE =========
  final int engineType;

  // ========= ENGINE COMBUSTION =========
  final bool combustion;

  // ========= SYSTEMS =========
  final bool pitot;
  final bool antiIce;
  final bool parkingBrake;
  final double leftBrake;
  final double rightBrake;

  final bool isAvatar;
  final bool isAircraft;

  final bool onRunway;

  final double yawRateDeg;
  final double slipBetaDeg;
  final double elevatorTrim;
  final double rudderDeflectionDeg;

  SimLinkData({
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.heading,
    required this.airspeed,
    required this.verticalSpeed,
    required this.pitch,
    required this.onGround,
    required this.fuelGallons,
    required this.fuelCapacityGallons,
    required this.mainBusVolts,
    required this.avionicsOn,
    required this.com1Active,
    required this.com1Standby,
    required this.transmitting,
    required this.receive,
    required this.structural,
    required this.gearHandleDown,
    required this.gearPosition,
    required this.flapsIndex,
    required this.flapsPercent,
    required this.rpm,
    required this.payload,
    required this.mission,
    required this.autopilot,
    required this.gear,
    required this.weather,
    required this.weights,
    required this.engineType,
    required this.combustion,
    required this.pitot,
    required this.antiIce,
    required this.parkingBrake,
    required this.leftBrake,
    required this.rightBrake,
    required this.isAvatar,
    required this.isAircraft,
    required this.onRunway,
    required this.yawRateDeg,
    required this.slipBetaDeg,
    required this.elevatorTrim,
    required this.rudderDeflectionDeg,
  });

  factory SimLinkData.fromJson(J j) {
    return SimLinkData(
      title: j['title'] ?? '—',
      latitude: (j['latitude'] ?? 0).toDouble(),
      longitude: (j['longitude'] ?? 0).toDouble(),
      altitude: (j['altitude'] ?? 0).toDouble(),
      heading: (j['heading'] ?? 0).toDouble(),
      airspeed: (j['airspeed'] ?? 0).toDouble(),
      verticalSpeed: (j['verticalSpeed'] ?? 0).toDouble(),
      pitch: (j['pitch'] ?? 0).toDouble(),
      onGround: b(j['onGround']),

      fuelGallons: (j['fuelGallons'] ?? 0).toDouble(),
      fuelCapacityGallons: (j['fuelCapacityGallons'] ?? 0).toDouble(),

      mainBusVolts: (j['mainBusVolts'] ?? 0).toDouble(),
      avionicsOn: b(j['avionicsOn']),

      com1Active: (j['com1Active'] ?? 0).toDouble(),
      com1Standby: (j['standby'] ?? 0).toDouble(),
      transmitting: b(j['transmitting']),
      receive: b(j['receive']),

      structural: (j['structural'] ?? 0).toDouble(),

      gearHandleDown: b(j['handleDown']),
      gearPosition: (j['position'] ?? 0).toDouble(),
      flapsIndex: (j['index'] ?? 0).toInt(),
      flapsPercent: (j['percent'] ?? 0).toDouble(),

      rpm: (j['rpm'] ?? 0).toDouble(),

      payload: PayloadData.fromJson(j['payload'] ?? {}),
      mission: MissionData.fromJson(j['mission'] ?? {}),
      autopilot: AutopilotData.fromJson(j['autopilot'] ?? {}),
      gear: GearConfig.fromJson(j['gear'] ?? {}),
      weather: WeatherData.fromJson(j['weather'] ?? {}),
      weights: WeightData.fromJson(j['weights'] ?? {}),
      engineType: j['engineType'] ?? 0,
      combustion: b(j['combustion']),
      pitot: b(j['pitot']),
      antiIce: b(j['antiIce']),
      parkingBrake: b(j['parkingBrake']),
      leftBrake: (j['leftBrake'] ?? 0).toDouble(),
      rightBrake: (j['rightBrake'] ?? 0).toDouble(),
      isAvatar: b(j['isAvatar']),
      isAircraft: b(j['isAircraft']),
      onRunway: b(j['onRunway']),
      yawRateDeg: (j['yawRateDeg'] ?? 0).toDouble(),
      slipBetaDeg: (j['slipBetaDeg'] ?? 0).toDouble(),
      elevatorTrim: (j['elevatorTrim'] ?? 0).toDouble(),
      rudderDeflectionDeg: (j['deflectionDeg'] ?? 0).toDouble(),
    );
  }
}

//
// ========================== WEATHER ==========================
//

class WeatherData {
  final double windDirection;
  final double windVelocity;
  final double visibility;
  final double temperature;
  final double seaLevelPressure;
  final double baroPressure;
  final double ambientPressure;
  final int precipState;
  final double precipRate;
  final bool inCloud;
  final double cloudDensity;
  final bool inSmoke;
  final double smokeDensity;

  WeatherData({
    required this.windDirection,
    required this.windVelocity,
    required this.visibility,
    required this.temperature,
    required this.seaLevelPressure,
    required this.baroPressure,
    required this.ambientPressure,
    required this.precipState,
    required this.precipRate,
    required this.inCloud,
    required this.cloudDensity,
    required this.inSmoke,
    required this.smokeDensity,
  });

  factory WeatherData.fromJson(J j) => WeatherData(
    windDirection: (j['windDirection'] ?? 0).toDouble(),
    windVelocity: (j['windVelocity'] ?? 0).toDouble(),
    visibility: (j['visibility'] ?? 0).toDouble(),
    temperature: (j['temperature'] ?? 0).toDouble(),
    seaLevelPressure: (j['seaLevelPressure'] ?? 0).toDouble(),
    baroPressure: (j['baroPressure'] ?? 0).toDouble(),
    ambientPressure: (j['ambientPressure'] ?? 0).toDouble(),
    precipState: j['precipState'] ?? 0,
    precipRate: (j['precipRate'] ?? 0).toDouble(),
    inCloud: b(j['inCloud']),
    cloudDensity: (j['cloudDensity'] ?? 0).toDouble(),
    inSmoke: b(j['inSmoke']),
    smokeDensity: (j['smokeDensity'] ?? 0).toDouble(),
  );
}

//
// ========================== AUTOPILOT ==========================
//

class AutopilotData {
  final bool master;
  final bool headingLock;
  final double headingBug;
  final bool altitudeLock;
  final double altitudeTarget;
  final bool navLock;
  final bool approachHold;
  final bool backcourseHold;
  final bool airspeedHold;
  final double airspeedTarget;
  final bool verticalSpeedHold;
  final double verticalSpeedTarget;

  AutopilotData({
    required this.master,
    required this.headingLock,
    required this.headingBug,
    required this.altitudeLock,
    required this.altitudeTarget,
    required this.navLock,
    required this.approachHold,
    required this.backcourseHold,
    required this.airspeedHold,
    required this.airspeedTarget,
    required this.verticalSpeedHold,
    required this.verticalSpeedTarget,
  });

  factory AutopilotData.fromJson(J j) => AutopilotData(
    master: b(j['master']),
    headingLock: b(j['headingLock']),
    headingBug: (j['headingBug'] ?? 0).toDouble(),
    altitudeLock: b(j['altitudeLock']),
    altitudeTarget: (j['altitudeTarget'] ?? 0).toDouble(),
    navLock: b(j['navLock']),
    approachHold: b(j['approachHold']),
    backcourseHold: b(j['backcourseHold']),
    airspeedHold: b(j['airspeedHold']),
    airspeedTarget: (j['airspeedTarget'] ?? 0).toDouble(),
    verticalSpeedHold: b(j['verticalSpeedHold']),
    verticalSpeedTarget: (j['verticalSpeedTarget'] ?? 0).toDouble(),
  );
}

//
// ========================== MISSION (lights + doors) ==========================
//

class MissionData {
  final bool battery;
  final bool beacon;
  final bool nav;
  final bool landing;
  final bool taxi;
  final bool strobe;
  final bool mainLeft;
  final bool mainRight;
  final bool cargo;
  final bool passenger;

  MissionData({
    required this.battery,
    required this.beacon,
    required this.nav,
    required this.landing,
    required this.taxi,
    required this.strobe,
    required this.mainLeft,
    required this.mainRight,
    required this.cargo,
    required this.passenger,
  });

  factory MissionData.fromJson(J j) => MissionData(
    battery: b(j['battery']),
    beacon: b(j['beacon']),
    nav: b(j['nav']),
    landing: b(j['landing']),
    taxi: b(j['taxi']),
    strobe: b(j['strobe']),
    mainLeft: b(j['mainLeft']),
    mainRight: b(j['mainRight']),
    cargo: b(j['cargo']),
    passenger: b(j['passenger']),
  );
}

//
// ========================== PAYLOAD ==========================
//

class PayloadData {
  final double totalWeight;
  final List<PayloadStation> stations;

  PayloadData({required this.totalWeight, required this.stations});

  factory PayloadData.fromJson(J j) {
    final raw = (j['stations'] as List? ?? []);
    return PayloadData(
      totalWeight: (j['totalWeight'] ?? 0).toDouble(),
      stations: raw.map((e) => PayloadStation.fromJson(e)).toList(),
    );
  }
}

class PayloadStation {
  final int index;
  final String name;
  final double weight;

  PayloadStation({
    required this.index,
    required this.name,
    required this.weight,
  });

  factory PayloadStation.fromJson(J j) => PayloadStation(
    index: j['index'] ?? 0,
    name: j['name'] ?? "Station",
    weight: (j['weight'] ?? 0).toDouble(),
  );
}

//
// ========================== GEAR TYPE ==========================
//

class GearConfig {
  final bool floats;
  final bool retractable;
  final bool skids;
  final bool skis;
  final bool wheels;

  GearConfig({
    required this.floats,
    required this.retractable,
    required this.skids,
    required this.skis,
    required this.wheels,
  });

  factory GearConfig.fromJson(J j) => GearConfig(
    floats: b(j['floats']),
    retractable: b(j['retractable']),
    skids: b(j['skids']),
    skis: b(j['skis']),
    wheels: b(j['wheels']),
  );
}

//
// ========================== WEIGHTS ==========================
//

class WeightData {
  final double emptyWeight;
  final double totalWeight;
  final double zfw;
  final double fuelWeight;
  final double payloadWeight;
  final double maxTakeoffWeight;
  final double maxZeroFuelWeight;
  final double maxGrossWeight;

  WeightData({
    required this.emptyWeight,
    required this.totalWeight,
    required this.zfw,
    required this.fuelWeight,
    required this.payloadWeight,
    required this.maxTakeoffWeight,
    required this.maxZeroFuelWeight,
    required this.maxGrossWeight,
  });

  factory WeightData.fromJson(J j) => WeightData(
    emptyWeight: (j['emptyWeight'] ?? 0).toDouble(),
    totalWeight: (j['totalWeight'] ?? 0).toDouble(),
    zfw: (j['zfw'] ?? 0).toDouble(),
    fuelWeight: (j['fuelWeight'] ?? 0).toDouble(),
    payloadWeight: (j['payload'] ?? 0).toDouble(),
    maxTakeoffWeight: (j['maxTakeoffWeight'] ?? 0).toDouble(),
    maxZeroFuelWeight: (j['maxZeroFuelWeight'] ?? 0).toDouble(),
    maxGrossWeight: (j['maxGrossWeight'] ?? 0).toDouble(),
  );
}
