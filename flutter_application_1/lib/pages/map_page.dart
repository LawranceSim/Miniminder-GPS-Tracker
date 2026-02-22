import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final Location _locationController = Location();

  bool serviceEnabled = false;
  PermissionStatus permissionGranted = PermissionStatus.denied;
  LatLng? _currentP;
  List<LatLng> _trackerLocations = [];
  Map<int, String> _trackerNames = {}; // Store tracker names
  bool _isLoading = false;
  Map<int, double> _distances = {};

  final Set<Marker> _markers = {};
  Map<PolylineId, Polyline> polylines = {};

  @override
  void initState() {
    super.initState();
    requestPermissionAndLocationUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Miniminder GPS Tracking App'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getTrackerLocationFromServer,
            tooltip: "Refresh tracker locations",
          ),
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            onPressed: _showManualLocationInputDialog,
            tooltip: "Add tracker location manually",
          ),
        ],
      ),
      body: _isLoading
          ? Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) => _mapController.complete(controller),
                  initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 1), // Placeholder position
                  markers: _markers,
                  polylines: Set<Polyline>.of(polylines.values),
                  zoomControlsEnabled: true, // Enable zoom controls
                ),
                const Center(child: CircularProgressIndicator()), // Show loading on top of the map
              ],
            )
          : _currentP == null
              ? const Center(child: Text("Loading..."))
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (GoogleMapController controller) => _mapController.complete(controller),
                      initialCameraPosition: CameraPosition(target: _currentP!, zoom: 13),
                      markers: _markers,
                      polylines: Set<Polyline>.of(polylines.values),
                      zoomControlsEnabled: true, // Enable zoom controls
                      myLocationButtonEnabled: false,
                      myLocationEnabled: true,
                    ),
                    Positioned(
                      bottom: 120,
                      right: 20,
                      child: FloatingActionButton.extended(
                        onPressed: _recenterMap, // Re-center the map
                        icon: const Icon(Icons.my_location),
                        label: const Text("Re-center"),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _distances.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0), // Added spacing
                  child: Chip(
                    label: Text(
                      'Route ${entry.key + 1}: ${entry.value.toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 18),
                    ),
                    backgroundColor: Colors.deepPurpleAccent,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showManualLocationInputDialog() {
    TextEditingController latController = TextEditingController();
    TextEditingController lngController = TextEditingController();
    TextEditingController nameController = TextEditingController(); // Controller for tracker name

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Tracker Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tracker Name',
                ),
              ),
              TextField(
                controller: latController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                ),
              ),
              TextField(
                controller: lngController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add Location'),
              onPressed: () {
                double? lat = double.tryParse(latController.text);
                double? lng = double.tryParse(lngController.text);
                String trackerName = nameController.text.trim();

                if (lat != null && lng != null && trackerName.isNotEmpty) {
                  setState(() {
                    int index = _trackerLocations.length;
                    _trackerLocations.add(LatLng(lat, lng));
                    _trackerNames[index] = trackerName; // Save tracker name
                    _updateMarkers();
                    _drawPolyline();
                    _moveCameraToFitBounds();
                    _calculateDistance(); // Update distance with each new location
                  });
                  Navigator.of(context).pop();
                } else {
                  _showErrorSnackBar('Invalid input. Please enter valid coordinates and a tracker name.');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> requestPermissionAndLocationUpdates() async {
    serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) {
        _showErrorSnackBar("Location service is not enabled.");
        return;
      }
    }

    permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        _showErrorSnackBar("Location permission denied.");
        return;
      }
    }

    _locationController.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        setState(() {
          _currentP = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          //_trackerLocations.add(const LatLng(1.5595, 103.6375)); // UTM Johor 
          _updateMarkers();
          _drawPolyline();
        });
        _moveCameraToFitBounds();
        _calculateDistance();
      }
    });
  }

  Future<void> _getTrackerLocationFromServer() async {
  final url = 'https://run.mocky.io/v3/d119dd06-a9e5-4878-8fc8-fff326fa34de'; 
  setState(() {
    _isLoading = true;
  });

  try {
    print('Fetching tracker location from: $url'); // Debug print
    final response = await http.get(Uri.parse(url));
    print('Response status: ${response.statusCode}'); // Debug print

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Data from server: $data'); 

      // Check if required fields are present
      if (data.containsKey('latitude') && data.containsKey('longitude')) {
        double latitude = data['latitude'];
        double longitude = data['longitude'];
        double? speed = data['speed']; // Optional field
        double? altitude = data['altitude']; // Optional field
        double? accuracy = data['accuracy']; // Optional field

        setState(() {
          _trackerLocations.add(LatLng(latitude, longitude));
          _updateMarkers();
          _drawPolyline();

          // Display optional data in the console (or handle as necessary)
          print('Speed: ${speed ?? "N/A"}');
          print('Altitude: ${altitude ?? "N/A"}');
          print('Accuracy: ${accuracy ?? "N/A"}');
        });

        _moveCameraToFitBounds();
        _calculateDistance();
      } else {
        _showErrorSnackBar('Invalid data format from server');
      }
    } else {
      _showErrorSnackBar('Server error: ${response.statusCode}');
    }
  } catch (error) {
    print('Error occurred: $error'); 
    _showErrorSnackBar('Something went wrong. Please try again.');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}


  void _updateMarkers() {
    _markers.clear();

    // Add a marker for the current location
    if (_currentP != null) {
      _markers.add(Marker(
        markerId: const MarkerId("Current Location"),
        position: _currentP!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    // Add a marker for each tracker location
    for (int i = 0; i < _trackerLocations.length; i++) {
      _markers.add(Marker(
        markerId: MarkerId("Tracker Location $i"),
        position: _trackerLocations[i],
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        // Display a dialog with details when a marker is tapped
        onTap: () {
          _showTrackerDetailsDialog(i, _trackerLocations[i]);
        },
      ));
    }
  }

  // Method to show tracker details in a dialog
  void _showTrackerDetailsDialog(int index, LatLng location) {
    double? distance = _distances[index];
    String trackerName = _trackerNames[index] ?? 'Unknown';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tracker: $trackerName'),
          content: Text(
            'Coordinates: (${location.latitude}, ${location.longitude})\n'
            'Distance from current location: ${distance != null ? distance.toStringAsFixed(2) : "N/A"} km',
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _drawPolyline() {
    polylines.clear();

    for (int i = 0; i < _trackerLocations.length; i++) {
      if (_currentP != null) {
        final polylineId = PolylineId('route$i');
        final polyline = Polyline(
          polylineId: polylineId,
          color: Colors.purpleAccent,
          width: 4,
          points: [_currentP!, _trackerLocations[i]],
        );
        polylines[polylineId] = polyline;
      }
    }
  }

  void _moveCameraToFitBounds() async {
    if (_currentP == null || _trackerLocations.isEmpty) {
      return;
    }

    LatLngBounds bounds;
    if (_trackerLocations.length == 1) {
      bounds = LatLngBounds(
        southwest: LatLng(
          min(_currentP!.latitude, _trackerLocations[0].latitude),
          min(_currentP!.longitude, _trackerLocations[0].longitude),
        ),
        northeast: LatLng(
          max(_currentP!.latitude, _trackerLocations[0].latitude),
          max(_currentP!.longitude, _trackerLocations[0].longitude),
        ),
      );
    } else {
      bounds = LatLngBounds(
        southwest: LatLng(
          _trackerLocations.map((t) => t.latitude).reduce(min),
          _trackerLocations.map((t) => t.longitude).reduce(min),
        ),
        northeast: LatLng(
          _trackerLocations.map((t) => t.latitude).reduce(max),
          _trackerLocations.map((t) => t.longitude).reduce(max),
        ),
      );
    }

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _calculateDistance() {
    if (_currentP == null) return;

    setState(() {
      _distances.clear();
      for (int i = 0; i < _trackerLocations.length; i++) {
        final LatLng destination = _trackerLocations[i];
        final double distance = _calculateHaversineDistance(_currentP!, destination);
        _distances[i] = distance;
      }
    });
  }

  double _calculateHaversineDistance(LatLng start, LatLng end) {
    const earthRadius = 6371; // Radius of Earth in kilometers
    final double latDiff = _degreesToRadians(end.latitude - start.latitude);
    final double lngDiff = _degreesToRadians(end.longitude - start.longitude);

    final double a = sin(latDiff / 2) * sin(latDiff / 2) +
        cos(_degreesToRadians(start.latitude)) *
            cos(_degreesToRadians(end.latitude)) *
            sin(lngDiff / 2) * sin(lngDiff / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c;
    return distance;
  }


  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _recenterMap() async {
    final GoogleMapController controller = await _mapController.future;
    if (_currentP != null) {
      controller.animateCamera(CameraUpdate.newLatLng(_currentP!));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
