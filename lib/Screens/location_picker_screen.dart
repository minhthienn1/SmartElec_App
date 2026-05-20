import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  Timer? _debounceTimer;

  // Tọa độ mặc định (Ngã tư Hàng Xanh, TP.HCM)
  LatLng _currentCenter = const LatLng(10.8016, 106.7115);
  String _currentAddress = "Đang xác định vị trí...";
  String _currentCity = "";
  String _currentDistrict = "";
  String _currentStreet = "";

  bool _isLoading = true;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Xin quyền và lấy GPS hiện tại của máy
  Future<void> _determineInitialPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setFallbackPosition();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setFallbackPosition();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setFallbackPosition();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentCenter = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _mapController.move(_currentCenter, 16.0);
      _getAddressFromLatLng(_currentCenter);
    } catch (e) {
      _setFallbackPosition();
    }
  }

  void _setFallbackPosition() {
    setState(() => _isLoading = false);
    _getAddressFromLatLng(_currentCenter);
  }

  // Dịch Tọa độ -> Văn bản địa chỉ (TỐI ƯU CHO VIỆT NAM - LẮP RÁP BOTTOM-UP)
  Future<void> _getAddressFromLatLng(LatLng position) async {
    // Hủy request cũ nếu người dùng đang kéo liên tục
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    setState(() {
      _currentAddress = "Đang quét địa chỉ...";
    });

    // Chờ 800ms sau khi dừng kéo mới bắt đầu gọi API
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          // 1. Lấy TỈNH / THÀNH PHỐ
          String city = (place.administrativeArea ?? '').trim();

          // 2. Lấy QUẬN / HUYỆN (Thường nằm ở subAdministrativeArea, nếu trống thì mò sang locality)
          String district = (place.subAdministrativeArea ?? '').trim();
          if (district.isEmpty || district == city) {
            district = (place.locality ?? '').trim();
          }

          // 3. Lấy PHƯỜNG / XÃ
          String ward = (place.subLocality ?? '').trim();

          // 4. Lấy SỐ NHÀ & TÊN ĐƯỜNG
          String street = (place.thoroughfare ?? '').trim();
          String houseNum = (place.subThoroughfare ?? '').trim();

          // Lắp ráp phần Chi Tiết (Số nhà, Đường)
          String streetInfo = "";
          if (houseNum.isNotEmpty && street.isNotEmpty) {
            streetInfo = "$houseNum $street";
          } else if (street.isNotEmpty) {
            streetInfo = street;
          } else {
            // Fallback: Nếu hẻm sâu quá API không có tên đường, lấy tên POI (name)
            String rawName = (place.name ?? '').trim();
            // Lọc để tránh việc POI Name lấy nhầm tên Quận/Tỉnh
            if (rawName.isNotEmpty &&
                rawName != district &&
                rawName != city &&
                rawName != ward) {
              streetInfo = rawName;
            }
          }

          // Lắp ráp phần Chi tiết cuối cùng (Số nhà, Đường, Phường)
          List<String> detailParts = [];
          if (streetInfo.isNotEmpty && streetInfo != "Unnamed Road") {
            detailParts.add(streetInfo);
          }
          if (ward.isNotEmpty && ward != district) {
            detailParts.add(ward);
          }
          String detailAddress = detailParts.join(', ');

          // Cập nhật State để đẩy về Form
          _currentCity = city;
          _currentDistrict = district;
          _currentStreet = detailAddress;

          // Tạo chuỗi hiển thị tóm tắt trên bản đồ
          List<String> displayParts = [
            detailAddress,
            district,
            city,
          ].where((part) => part.isNotEmpty).toList();

          if (mounted) {
            setState(() {
              _currentAddress = displayParts.join(', ');
              if (_currentAddress.isEmpty) {
                _currentAddress = "Vị trí này chưa có thông tin tên đường";
              }
            });
          }
        }
      } catch (e) {
        debugPrint("Geocoding Error: $e");
        if (mounted) {
          setState(() {
            _currentAddress = "Không thể định vị địa chỉ tại đây.";
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Chọn vị trí sửa chữa",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. BẢN ĐỒ
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: 16.0,
                    onMapEvent: (MapEvent event) {
                      if (event is MapEventMoveStart) {
                        setState(() => _isDragging = true);
                      } else if (event is MapEventMoveEnd) {
                        setState(() {
                          _isDragging = false;
                          _currentCenter = event.camera.center;
                        });
                        _getAddressFromLatLng(_currentCenter);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smart_elec',
                    ),
                  ],
                ),

                // 2. GHIM GIỮA MÀN HÌNH
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(
                        0,
                        _isDragging ? -15 : 0,
                        0,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        size: 50,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),

                // 3. PANEL THÔNG TIN ĐỊA CHỈ
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Vị trí đã chọn:",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentAddress,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xff0B1B4D),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff0B1B4D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _isDragging
                                  ? null
                                  : () {
                                      Navigator.pop(context, {
                                        'lat': _currentCenter.latitude,
                                        'lng': _currentCenter.longitude,
                                        'address': _currentAddress,
                                        'city': _currentCity,
                                        'district': _currentDistrict,
                                        'street': _currentStreet,
                                      });
                                    },
                              child: const Text(
                                "XÁC NHẬN VỊ TRÍ NÀY",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // NÚT VỀ VỊ TRÍ HIỆN TẠI
                Positioned(
                  right: 16,
                  bottom: 220,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: () => _determineInitialPosition(),
                  ),
                ),
              ],
            ),
    );
  }
}
