import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class LocationService {
  static Future<void> updateStatus() async {
    try {
      // 1. Kiểm tra quyền GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ GPS service is disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ GPS permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ GPS permissions are permanently denied.');
        return;
      }

      // 2. Lấy tọa độ hiện tại
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Gọi API cập nhật lên Backend
      final response = await ApiService.toggleOnline(
        lat: position.latitude,
        lng: position.longitude,
        isOnline: true,
      );

      if (response != null) {
        debugPrint('✅ Updated Online Status & Location: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('❌ Error updating location status: $e');
    }
  }
}
