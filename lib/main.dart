import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Same basemap and default view as the web app (see PulseMap.vue /
// mapStyle.ts) - dark only for now, theme switching comes later.
const _darkBasemapUrl = 'https://tiles.openfreemap.org/styles/fiord';
const _helsinkiCenter = LatLng(60.1719, 24.9414);

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: _darkBasemapUrl,
        initialCameraPosition: const CameraPosition(
          target: _helsinkiCenter,
          zoom: 12.5,
        ),
      ),
    );
  }
}
