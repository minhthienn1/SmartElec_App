import 'package:flutter/material.dart';
import 'package:smart_elec/models/device.dart';
import 'package:smart_elec/services/api_service.dart';
import 'package:smart_elec/services/notification_service.dart';

class DeviceProvider extends ChangeNotifier {
  List<Device> _devices = [];
  bool _isLoading = false;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;

  Future<void> fetchDevices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _devices = await ApiService.getDevices();
      
      // Tự động lên lịch nhắc nhở bảo trì thực tế
      for (var device in _devices) {
        NotificationService.scheduleDeviceMaintenance(device);
      }
    } catch (e) {
      debugPrint("Lỗi khi fetch devices: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNewDevice(Map<String, dynamic> data) async {
    try {
      await ApiService.addDevice(data);
      await fetchDevices(); // Reload the list after adding
    } catch (e) {
      debugPrint("Lỗi khi thêm thiết bị: $e");
      rethrow;
    }
  }

  Future<void> updateDevice(String id, Map<String, dynamic> data) async {
    try {
      await ApiService.updateDevice(id, data);
      await fetchDevices(); // Reload the list after updating
    } catch (e) {
      debugPrint("Lỗi khi cập nhật thiết bị: $e");
      rethrow;
    }
  }

  Future<void> deleteDevice(String id) async {
    try {
      await ApiService.deleteDevice(id);
      await fetchDevices(); // Reload the list after deleting
    } catch (e) {
      debugPrint("Lỗi khi xóa thiết bị: $e");
      rethrow;
    }
  }
}
