class RadioState {
  final bool avionicsMaster;
  final bool com1Available;
  final bool com1Transmit;

  RadioState({
    required this.avionicsMaster,
    required this.com1Available,
    required this.com1Transmit,
  });

  factory RadioState.fromJson(Map<String, dynamic> json) {
    return RadioState(
      avionicsMaster: json['avionicsMaster'] ?? false,
      com1Available: json['com1Available'] ?? false,
      com1Transmit: json['com1Transmit'] ?? false,
    );
  }
}
