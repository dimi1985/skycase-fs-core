// lib/models/ground_ops_response.dart

class GroundOpsResponse {
  final String type;
  final String message;
  final int delaySeconds;
  final int reward;
  final Map<String, dynamic> cargo;

  GroundOpsResponse({
    required this.type,
    required this.message,
    required this.delaySeconds,
    required this.reward,
    required this.cargo,
  });

  factory GroundOpsResponse.fromJson(Map<String, dynamic> json) {
    return GroundOpsResponse(
      type: json['type'] ?? 'unknown',
      message: json['message'] ?? '',
      delaySeconds: json['delaySeconds'] ?? 0,
      reward: json['reward'] ?? 0,
      cargo: json['cargo'] ?? {},
    );
  }
}
