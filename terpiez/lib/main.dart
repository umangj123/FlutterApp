import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'redis_service.dart';
import 'package:path_provider/path_provider.dart';



void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserModel(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terpiez Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}


class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _storage = FlutterSecureStorage();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final RedisService _redisService = RedisService();
  bool _loading = false;

  void _login() async {
    setState(() => _loading = true);
    // Save credentials securely
    await _storage.write(key: 'username', value: _usernameController.text);
    await _storage.write(key: 'password', value: _passwordController.text);
    // Attempt to connect to Redis
    bool connected = await _redisService.connect(_usernameController.text, _passwordController.text);
    setState(() => _loading = false);
    if (connected) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MyHomePage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect to Redis')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login to Redis')),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            _loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: Text('Login'),
                  ),
          ],
        ),
      ),
    );
  }
}



class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terpiez Game'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: "List"),
            Tab(icon: Icon(Icons.map), text: "Finder"),
            Tab(icon: Icon(Icons.bar_chart), text: "Statistics"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListTab(),
          FinderTab(),
          StatisticsTab(),
        ],
      ),
    );
  }
}

class ListTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> terpiezTypes = ['Terpiez Type 1', 'Terpiez Type 2', 'Terpiez Type 3'];

    return ListView.builder(
      itemCount: terpiezTypes.length,
      itemBuilder: (context, index) {
        String terpiezType = terpiezTypes[index];
        return ListTile(
          leading: Hero(
            tag: 'hero-$terpiezType',
            child: Icon(Icons.pets),
          ),
          title: Text(terpiezType),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(terpiezType: terpiezType)));
          },
        );
      },
    );
  }
}

class FinderTab extends StatefulWidget {
  @override
  _FinderTabState createState() => _FinderTabState();
}

class _FinderTabState extends State<FinderTab> {
  MapController mapController = MapController();
  LatLng currentPosition = LatLng(38.9072, -77.0369); // Washington D.C.
  Set<String> caughtLocations = Set<String>(); // To store caught locations as "lat,lon"
  Map<String, List<LatLng>> terpiezLocations = {}; // New data structure for Terpiez Id  to locations
  List<Marker> terpiezMarkers = [];
  double closestDistance = double.infinity;
  List<Map<String, dynamic>> alllocations = []; 
  RedisService redisService = RedisService();
  String closestID = "";
  LatLng closestTerpLocation = LatLng(0,0);


  StreamSubscription<Position>? positionStreamSubscription; // Declare the subscription variable


  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

void _initializeLocation() async {
  var status = await Permission.locationWhenInUse.status;
  if (!status.isGranted) {
    await Permission.locationWhenInUse.request();
  }
    alllocations = await redisService.fetchAllLocations();
    positionStreamSubscription = Geolocator.getPositionStream().listen((Position position) {
    if(mounted){
      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
        mapController.move(currentPosition, mapController.camera.zoom);
        _updateMapMarkers();
      });
    }
  });
}

void _updateMapMarkers() async {
    double closest = double.infinity;
    Marker? closestMarker;

    for (var location in alllocations) {
      String locationKey = "${location['lat']},${location['lon']}";
      if (!caughtLocations.contains(locationKey)) {
        double distance = Geolocator.distanceBetween(
          currentPosition.latitude, currentPosition.longitude,
          location['lat'], location['lon']
        );
        if (distance < closest) {
          closest = distance;
          closestID = location['id'];
          closestTerpLocation = LatLng(location['lat'], location['lon']);
          closestMarker = Marker(
            point: LatLng(location['lat'], location['lon']),
            child: Icon(Icons.location_on, color: Colors.red, size:30),
          );
        }
      }
    }
    print("closestID: $closestID");
    if (closestMarker != null) {
      closestDistance = closest;
      setState(() {
        terpiezMarkers = [closestMarker!];
      });
    }
    else {
      setState(() {
        terpiezMarkers = [];
      });
    }
  }

  void markTerpiezAsCaught(LatLng location, String terpiezId) {
    caughtLocations.add("${location.latitude},${location.longitude}");

    // Add the location to the terpiezLocations map
    if (!terpiezLocations.containsKey(terpiezId)) {
      terpiezLocations[terpiezId] = [];
    }
    terpiezLocations[terpiezId]!.add(location);

    print('Caught Terpiez $terpiezId at $location');
    print('caughtLocations: $caughtLocations');
    print('Caught Terpiez Ids and Locations: $terpiezLocations');

    _updateMapMarkers();
  }

  Future<void> handleNewCatch(String terpiezId) async {
    var terpiezData = await redisService.fetchTerpiezData(terpiezId);
    if (terpiezData != null) {
      String thumbnailKey = terpiezData['thumbnail'];
      String imageKey = terpiezData['image'];
      print('id: $terpiezId');
      print('name: ${terpiezData['name']}');
      print('Thumbnail Key: $thumbnailKey');
      print('Image Key: $imageKey');

      var thumbData = await redisService.fetchImageData(thumbnailKey);
      var imageData = await redisService.fetchImageData(imageKey);

      print('Image data obtained');

      if (thumbData != null && imageData != null) {
        await saveImageLocally(thumbData, 'thumb_$terpiezId.jpg');
        await saveImageLocally(imageData, 'image_$terpiezId.jpg');
        print('Images saved locally');
      }
      await saveTerpiezDataLocally(terpiezId, terpiezData);
      print('handleNewCatch completed');
    }

  }

  Future<void> saveImageLocally(String base64Data, String filename) async {
    var bytes = base64Decode(base64Data);
    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = File('$dir/$filename');
    print('File path: ${file.path}');
    await file.writeAsBytes(bytes);
  }

  Future<void> saveTerpiezDataLocally(String terpiezId, Map<String, dynamic> data) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = File('$dir/terpiez_$terpiezId.json');
    await file.writeAsString(jsonEncode(data));
    print('Terpiez data saved locally');
  }



@override
void dispose() {
  positionStreamSubscription?.cancel();  // Cancel the subscription
  redisService.disconnect();
  super.dispose();
}


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 300,
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                center: currentPosition,
                zoom: 13.0,              
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName:'net.tlserver6y.flutter_map_location_marker.example',
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(markers: terpiezMarkers),
                CurrentLocationLayer()
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text('Closest Terpiez: ${closestDistance.toStringAsFixed(2)} m'),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: closestDistance <= 10 ? () {
                    Provider.of<UserModel>(context, listen: false).incrementTerpiez();
                    handleNewCatch(closestID);
                    markTerpiezAsCaught(closestTerpLocation, closestID);
                  } : null,
                  child: Text('Catch Terpiez'),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.disabled)) return Colors.grey;
                        return Colors.green; // Use the component's default.
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    UserModel userModel = Provider.of<UserModel>(context);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Total Captures: ${userModel.terpiezCaught}'),
                Text('Days Played: ${userModel.getDaysPlayed()}'),
                Text('User Id: ${userModel.userId}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DetailsScreen extends StatefulWidget {
  final String terpiezType;

  DetailsScreen({required this.terpiezType});

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _animation = ColorTween(
      begin: Colors.blue,
      end: Colors.red,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details of ${widget.terpiezType}')),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'hero-${widget.terpiezType}',
                child: Icon(Icons.pets, size: 100),
              ),
              SizedBox(height: 20),
              Text(widget.terpiezType, style: Theme.of(context).textTheme.headline5),
              SizedBox(height: 20),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_animation.value!, Colors.yellow],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
