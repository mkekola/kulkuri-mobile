import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'hfp.dart';
import 'vehicle_modes.dart';

// Same basemap and default view as the web app (see PulseMap.vue /
// mapStyle.ts) - dark only for now, theme switching comes later.
const _darkBasemapUrl = 'https://tiles.openfreemap.org/styles/fiord';
const _helsinkiCenter = LatLng(60.1719, 24.9414);
const _vehiclesSourceId = 'vehicles';
const _vehiclesLayerId = 'vehicles';

void main() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: _darkBasemapUrl,
        initialCameraPosition: const CameraPosition(
          target: _helsinkiCenter,
          zoom: 12.5,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
      ),
    );
  }
}
