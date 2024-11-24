import 'dart:io';  // Platform 클래스를 위한 import 추가
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/notification.dart';

// 앱의 시작점
void main() async {



   // 네이버 맵 SDK 초기화
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(
    clientId: 'hnogoubv6j',
    onAuthFailed: (error) {
      print('인증 실패: $error');
    },
  );
  runApp(const MyApp());
}
// 앱의 루트 위젯
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '지오펜싱 앱',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const GeofencingMap(),// 메인 화면으로 지오펜싱 맵 설정
    );
  }
}


// 지오펜싱 맵 위젯 (상태 관리가 필요하므로 StatefulWidget)

class GeofencingMap extends StatefulWidget {
  const GeofencingMap({Key? key}) : super(key: key);

  @override
  State<GeofencingMap> createState() => _GeofencingMapState();
}


// 지오펜싱 맵의 상태 관리 클래스

class _GeofencingMapState extends State<GeofencingMap> with WidgetsBindingObserver {
  NaverMapController? _mapController;// 네이버 맵 컨트롤러
  final NotificationService _notificationService = NotificationService();
  NCircleOverlay? _geofenceCircle;// 지오펜스 원형 오버레이
  bool _isInsideGeofence = false;// 사용자가 지오펜스 내부에 있는지 여부


  // 지오펜스 중심점과 반경 설정
  final NLatLng _geofenceCenter = const NLatLng(35.3215, 129.1756); // 정관 동원로얄듀크2차 좌표
  final double _geofenceRadius = 50; // 50m 반경

    // 권한 체크 및 요청 함수

  Future<void> checkPermission() async {
    try {
      print('권한 요청 시작');
      
      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('위치 서비스 활성화 상태: $serviceEnabled');
      
      if (!serviceEnabled) {
        throw '위치 서비스를 활성화해주세요.';
      }

      // 위치 권한 상태 확인
      LocationPermission permission = await Geolocator.checkPermission();
      print('위치 권한 상태: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
      }

      // 알림 권한 요청
      print('알림 권한 요청');
      final status = await Permission.notification.request();
      print('알림 권한 결과: $status');

      // 알림 권한 요청 (안드로이드)
      if (Platform.isAndroid) {
        if (status.isDenied) {
          print('알림 권한 요청');
          final result = await Permission.notification.request();
          print('알림 권한 결과: $result');
        }
      }
    } catch (e) {
      print('권한 요청 중 오류 발생: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    checkPermission().then((_) {
      _notificationService.initialize();
      startLocationTracking();
    });
  }

  Future<void> startLocationTracking() async {
    print('위치 추적 시작');
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print('위치 서비스 활성화 상태: $serviceEnabled');
    
    if (!serviceEnabled) {
      print('위치 서비스가 비활성화되어 있습니다.');
      return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      checkGeofence(position);
      _updateCurrentLocationMarker(position);
    });
  }

  void _updateCurrentLocationMarker(Position position) {
    if (_mapController != null) {
      _mapController!.addOverlay(
        NMarker(
          id: 'current_location',
          position: NLatLng(position.latitude, position.longitude),
          caption: NOverlayCaption(text: '현재 위치'),
          iconTintColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지오펜싱 앱')),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: _geofenceCenter,
            zoom: 13,
          ),
          liteModeEnable: true,
        ),
        onMapReady: _onMapReady,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Position position = await Geolocator.getCurrentPosition();
          NLatLng currentPosition = NLatLng(position.latitude, position.longitude);
          _mapController?.updateCamera(
            NCameraUpdate.withParams(
              target: currentPosition,
              zoom: 15,
            ),
          );
          _updateCurrentLocationMarker(position);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _onMapReady(NaverMapController controller) {
    _mapController = controller;
    _mapController?.addOverlay(
      NCircleOverlay(
        id: 'geofence_circle',
        center: _geofenceCenter,
        radius: _geofenceRadius,
        color: Colors.blue.withOpacity(0.3),
      ),
    );
  }

  void checkGeofence(Position position) {
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _geofenceCenter.latitude,
      _geofenceCenter.longitude,
    );

    bool isCurrentlyInZone = distance <= _geofenceRadius;
    
    if (isCurrentlyInZone && !_isInsideGeofence) {
      _notificationService.showNotification('지역 진입', '지정된 영역에 들어왔습니다.');
      print('영역 진입: 거리 = ${distance.toStringAsFixed(2)}m');
    } else if (!isCurrentlyInZone && _isInsideGeofence) {
      _notificationService.showNotification('지역 이탈', '지정된 영역을 벗어났습니다.');
      print('영역 이탈: 거리 = ${distance.toStringAsFixed(2)}m');
    }

    _isInsideGeofence = isCurrentlyInZone;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, 
        overlays: SystemUiOverlay.values);
    _mapController?.dispose();
    super.dispose();
  }
}