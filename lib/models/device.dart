class Device {
  final String id;
  final String category;
  final String brandName;
  final String? modelCode;
  final String? location;
  final DateTime? nextMaintenanceDate;
  final int? maintenanceCycleMonths;

  Device({
    required this.id,
    required this.category,
    required this.brandName,
    this.modelCode,
    this.location,
    this.nextMaintenanceDate,
    this.maintenanceCycleMonths,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'].toString(),
      category: json['category'] ?? 'Khác',
      brandName: json['brandName'] ?? '',
      modelCode: json['modelCode'],
      location: json['location'],
      nextMaintenanceDate: json['nextMaintenanceDate'] != null
          ? DateTime.parse(json['nextMaintenanceDate'])
          : null,
      maintenanceCycleMonths: json['maintenanceCycleMonths'],
    );
  }
}
