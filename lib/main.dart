import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'digitransit.dart';
import 'hfp.dart';
import 'vehicle_modes.dart';
import 'vehicle_stop_sheets.dart';

// Same basemap and default view as the web app (see PulseMap.vue /
// mapStyle.ts) - dark only for now, theme switching comes later.
const _darkBasemapUrl = 'https://tiles.openfreemap.org/styles/fiord';
const _helsinkiCenter = LatLng(60.1719, 24.9414);
const _vehiclesSourceId = 'vehicles';
const _vehiclesLayerId = 'vehicles';
const _stopsSourceId = 'stops';
const _stopsLayerId = 'stops';
// Stops only render once zoomed in enough that the list stays a reasonable
// size - matches the web app's PulseMap.vue.
const _minStopsZoom = 14.0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // Default Virtual Display rendering has known gaps in touch-event
  // forwarding through the platform view (matches the emulator log's own
  // warning, and onMapClick never firing at all) - TextureView costs more
  // to render but behaves like a normal composited widget.
  MapLibreMap.useHybridComposition = true;
  runApp(const KulkuriApp());
}

class KulkuriApp extends StatelessWidget {
  const KulkuriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _controller;
  VehiclePositionsClient? _vehicles;
  bool _stopsSourceReady = false;

  @override
  void dispose() {
    _vehicles?.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.addGeoJsonSource(_vehiclesSourceId, const {
      'type': 'FeatureCollection',
      'features': <Object>[],
    });
    await controller.addCircleLayer(
      _vehiclesSourceId,
      _vehiclesLayerId,
      CircleLayerProperties(
        circleRadius: 5,
        circleColor: modeColorMatchExpression,
        circleStrokeColor: '#0a0f1c',
        circleStrokeWidth: 1.5,
      ),
    );

    _vehicles = VehiclePositionsClient(_onVehiclesUpdate)..connect();

    await controller.addGeoJsonSource(_stopsSourceId, const {
      'type': 'FeatureCollection',
      'features': <Object>[],
    });
    await controller.addCircleLayer(
      _stopsSourceId,
      _stopsLayerId,
      const CircleLayerProperties(
        circleRadius: 3,
        circleColor: '#e9edf4',
        circleStrokeColor: '#0a0f1c',
        circleStrokeWidth: 1,
      ),
    );
    _stopsSourceReady = true;
  }

  Future<void> _onCameraIdle() async {
    final controller = _controller;
    if (controller == null || !_stopsSourceReady) return;

    final zoom = controller.cameraPosition?.zoom ?? 0;
    debugPrint('[stops] camera idle at zoom $zoom');
    if (zoom < _minStopsZoom) {
      await controller.setGeoJsonSource(_stopsSourceId, const {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
      return;
    }

    final bounds = await controller.getVisibleRegion();
    final stops = await fetchStopsInBounds(
      minLat: bounds.southwest.latitude,
      minLon: bounds.southwest.longitude,
      maxLat: bounds.northeast.latitude,
      maxLon: bounds.northeast.longitude,
    );
    debugPrint('[stops] fetched ${stops.length} stops');
    await controller.setGeoJsonSource(_stopsSourceId, {
      'type': 'FeatureCollection',
      'features': stops
          .map(
            (stop) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [stop.lon, stop.lat],
              },
              'properties': {'gtfsId': stop.gtfsId, 'name': stop.name},
            },
          )
          .toList(),
    });
  }

  void _onVehiclesUpdate(List<VehiclePosition> vehicles) {
    final controller = _controller;
    if (controller == null) return;
    controller.setGeoJsonSource(_vehiclesSourceId, {
      'type': 'FeatureCollection',
      'features': vehicles
          .map(
            (v) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [v.lng, v.lat],
              },
              'properties': {'vehicleId': v.vehicleId, 'mode': v.mode, 'line': v.line},
            },
          )
          .toList(),
    });
  }

  Future<void> _onMapClick(Point<double> point, LatLng coordinates) async {
    final controller = _controller;
    debugPrint('[tap] click at $point / $coordinates');
    if (controller == null) return;

    final vehicleFeatures = await controller.queryRenderedFeatures(point, [_vehiclesLayerId], null);
    debugPrint('[tap] ${vehicleFeatures.length} vehicle feature(s) at point');
    if (vehicleFeatures.isNotEmpty) {
      final properties = (vehicleFeatures.first as Map)['properties'] as Map;
      _showSheet(
        VehicleSheetContent(
          vehicleId: properties['vehicleId'] as String,
          mode: properties['mode'] as String,
          line: properties['line'] as String?,
        ),
      );
      return;
    }

    final stopFeatures = await controller.queryRenderedFeatures(point, [_stopsLayerId], null);
    debugPrint('[tap] ${stopFeatures.length} stop feature(s) at point');
    if (stopFeatures.isNotEmpty) {
      final properties = (stopFeatures.first as Map)['properties'] as Map;
      final gtfsId = properties['gtfsId'] as String;
      _showSheet(
        StopSheetContent(
          name: properties['name'] as String,
          departures: fetchStopDepartures(gtfsId),
        ),
      );
    }
  }

  void _showSheet(Widget content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff121a2c),
      builder: (_) => content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: _darkBasemapUrl,
        initialCameraPosition: const CameraPosition(
          target: _helsinkiCenter,
          zoom: 12.5,
        ),
        trackCameraPosition: true,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        onCameraIdle: _onCameraIdle,
        onMapClick: _onMapClick,
      ),
    );
  }
}
