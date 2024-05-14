import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'redis_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:terpiez/global.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

final FlutterSecureStorage _storage = const FlutterSecureStorage();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


void main() async {
  //final redisService = RedisService();
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  await initializeNotifications();
  await initializeService();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserModel()),
        //Provider<RedisService>.value(value: redisService),  // Provide RedisService
      ],
      child: MyApp(),
    ),
  );
}

Future<void> requestPermissions() async {
  await [
    Permission.locationAlways,
    Permission.notification,
  ].request();
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
      String? payload = notificationResponse.payload;
      if (payload != null) {
        handleNotificationNavigation(payload);
      }
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // name // description
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  final NotificationAppLaunchDetails? notificationAppLaunchDetails = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    // Handle notification launch
    handleNotificationNavigation(notificationAppLaunchDetails!.notificationResponse?.payload ?? '');
  }
}

void handleNotificationNavigation(String payload) {
  if (navigatorKey.currentState != null) {
    if (payload == 'proximity_alert') {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MyHomePage(initialTab: 1)),
        (Route<dynamic> route) => false,
      );
    }
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'high_importance_channel',
      initialNotificationTitle: 'Terpiez Service',
      initialNotificationContent: 'Monitoring your proximity to Terpiez.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      autoStart: true,
    ),
  );

  await service.startService();
}

void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Your periodic task to check proximity
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        LatLng currentPosition = LatLng(position.latitude, position.longitude);

        final RedisService redisService = RedisService();
        await redisService.connect(await _storage.read(key: 'username') ?? "", await _storage.read(key: 'password') ?? "");
        List<Map<String, dynamic>> terpiezLocations = await redisService.fetchAllLocations();
        await redisService.disconnect();

        for (var location in terpiezLocations) {
          double distance = Geolocator.distanceBetween(
            currentPosition.latitude, currentPosition.longitude,
            location['lat'], location['lon'],
          );
          if (distance <= 20) {
            print('trying to show Proximity alert: $distance');
            await showProximityNotification();
            break;
          }
        }
      }
    }
  });
}

Future<void> showProximityNotification() async {
  print('showing proximity notification');
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'high_importance_channel', 'High Importance Notifications',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('proximity_alert'),
  );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0,
    'Terpiez Nearby!',
    'You are within 20m of a Terpiez. Open the app to catch it!',
    platformChannelSpecifics,
    payload: 'proximity_alert',
  );
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLoggedInStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return MaterialApp(
            title: 'Terpiez Game',
            theme: ThemeData(
              primarySwatch: Colors.blue,
            ),
            home: LoginPage(),
          );
        } else {
          if (snapshot.data == true) {
            return ChangeNotifierProvider(
              create: (context) => UserModel(),
              child: MaterialApp(
                title: 'Terpiez Game',
                theme: ThemeData(
                  primarySwatch: Colors.blue,
                ),
                home: MyHomePage(),
              ),
            );
          } else {
            return ChangeNotifierProvider(
              create: (context) => UserModel(),
              child: MaterialApp(
                navigatorKey: navigatorKey,
                title: 'Terpiez Game',
                theme: ThemeData(
                  primarySwatch: Colors.blue,
                ),
                home: LoginPage(),
              ),
            );
          }
        }
      },
    );
  }

Future<bool> _checkLoggedInStatus() async {
  final prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  if (isLoggedIn) {
    final storage = FlutterSecureStorage();
    String? username = await storage.read(key: 'username');
    String? password = await storage.read(key: 'password');
    if (username != null && password != null) {
      final redisService = RedisService();
      return await redisService.connect(username, password);
    }
  }
  return false;
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
      // Save login status
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

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
  final int initialTab;

  MyHomePage({this.initialTab = 0});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late RedisService _redisService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = widget.initialTab;
    _redisService = RedisService();
    _redisService.startMonitoringConnection();
  }

  @override
  Widget build(BuildContext context) {
    UserModel userModel = Provider.of<UserModel>(context, listen: false);
    userModel.loadUserTerpiezData();

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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.music_note),
              title: Text('Play Sound'),
              trailing: Consumer<UserModel>(
                builder: (context, userModel, child) {
                  return Switch(
                    value: userModel.playSound,
                    onChanged: (value) {
                      userModel.togglePlaySound(value);
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Clear Data'),
              onTap: () => _confirmClearData(context),
            ),
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

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Clear Data'),
          content: Text('Are you sure you want to clear all data? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Clear Data'),
              onPressed: () async {
                await _clearData();
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => MyHomePage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearData() async {
    UserModel userModel = Provider.of<UserModel>(context, listen: false);
    await userModel.clearData();
  }
}


class ListTab extends StatefulWidget {
  @override
  _ListTabState createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  List<String> terpiezIds = [];
  Map<String, String> terpiezNames = {}; // Assumes names are stored or fetched separately if needed
  Map<String, String> terpiezThumbnails = {};
  List<Map<String, dynamic>> loadedData = [];

  @override
  void initState() {
    super.initState();
    loadTerpiezData();
  }

  void loadTerpiezData() async {
    UserModel userModel = Provider.of<UserModel>(context, listen: false);
    terpiezIds = userModel.terpiezMaster.keys.toList();
    final directory = await getApplicationDocumentsDirectory();
    

      // Assuming names and thumbnail paths are managed somehow to be fetched here
    for (String id in terpiezIds) {
      // Assuming the thumbnail is named 'thumb_<id>.jpg' and stored locally
      print(id);
      String thumbnailPath = '${directory.path}/thumb_$id.jpg';
      final filePath = '${directory.path}/terpiez_$id.json';
      final file = File(filePath);

      if (file.existsSync()) {
        final data = jsonDecode(await file.readAsString());
        loadedData.add({
          'name': data['name'],
          'thumbnailPath': thumbnailPath,
          'description': data['description'],
          'stats': data['stats'],
          'imagePath': '${directory.path}/image_$id.jpg',
          'locations': userModel.terpiezMaster[id]?.map((latlng) => latlng).toList() ?? [],
        });
      }
    }
    setState(() {
      terpiezIds = userModel.terpiezMaster.keys.toList();
      print('terpiezIds: $terpiezIds');
    });

    print('All data loaded: $loadedData');
  }

  @override
  Widget build(BuildContext context) {
    if (terpiezIds.isEmpty) {
      print('it is indeed empty');
      return Center(child: Text("No Terpiez caught yet."));
    }
    if (loadedData.isEmpty) {
      return Center(child: Text("No Terpiez caught yet."));
    }

    return ListView.builder(
      itemCount: terpiezIds.length,
      itemBuilder: (context, index) {
        var terpiez = loadedData[index];
        String thumbnailPath = terpiez['thumbnailPath'] ?? '';
        String name = terpiez['name'] ?? 'Unknown';

        return ListTile(
          leading: thumbnailPath.isNotEmpty ? Hero(
            tag: 'hero-$name',
            child: Image.file(File(thumbnailPath), width: 50, height: 50, fit: BoxFit.cover),
          ) : Icon(Icons.image_not_supported),
          title: Text(name),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => DetailsScreen(terpiezData: terpiez)));
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
  //Set<String> caughtLocations = Set<String>(); // To store caught locations as "lat,lon"
  //Map<String, List<LatLng>> terpiezLocations = {}; // New data structure for Terpiez Id  to locations
  List<Marker> terpiezMarkers = [];
  double closestDistance = double.infinity;
  List<Map<String, dynamic>> alllocations = []; 
  //late RedisService redisService = Provider.of<RedisService>(context, listen: false);
  RedisService redisService = RedisService();
  String closestID = "";
  LatLng closestTerpLocation = LatLng(0,0);
  final FlutterSecureStorage _storage = const FlutterSecureStorage();


  StreamSubscription<Position>? positionStreamSubscription; // Declare the subscription variable
  StreamSubscription<AccelerometerEvent>? accelerometerSubscription;


  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeAccelerometer();
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

void _initializeAccelerometer() {
    accelerometerSubscription = SensorsPlatform.instance.accelerometerEvents.listen((AccelerometerEvent event) {
      // Check if the device was moved sharply
      if (event.x.abs() > 10 || event.y.abs() > 10 || event.z.abs() > 10) {
        if (closestDistance <= 10) {
          playSound('sounds/catch.wav');
          Provider.of<UserModel>(context, listen: false).incrementTerpiez();
          handleNewCatch(closestID);
          markTerpiezAsCaught(closestTerpLocation, closestID);
        }
      }
    });
  }

void playSound(String soundFile) async {
  final userModel = Provider.of<UserModel>(context, listen: false);
  if (userModel.playSound) {
    final player = AudioPlayer();
    await player.play(AssetSource(soundFile));
  }
}

void _updateMapMarkers() async {
    double closest = double.infinity;
    Marker? closestMarker;
    // String username = await _storage.read(key: 'username') ?? "defaultUsername";
    // String password = await _storage.read(key: 'password') ?? "defaultPassword";
    // await redisService.connect(username, password);
    // await redisService.disconnect();
    // if (redisService.isConnected) {
      //alllocations = await redisService.fetchAllLocations();
      print(redisService.isConnected);
      for (var location in alllocations) {
        String locationKey = "${location['lat']},${location['lon']}";
        if (!Provider.of<UserModel>(context, listen: false).caughtLocationSet.contains(locationKey)) {
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
    //}
    //print("closestID: $closestID");
    if (closestMarker != null) {
      if (closest <= 20) {
        playSound('sounds/notification.wav');
      }
      closestDistance = closest;
      setState(() {
        terpiezMarkers = [closestMarker!];
      });
    }
    else {
      setState(() {
        terpiezMarkers = [];
        closestDistance = double.infinity;
      });
    }
  }

  void markTerpiezAsCaught(LatLng location, String terpiezId) {
    Provider.of<UserModel>(context, listen: false).caughtLocationSet.add("${location.latitude},${location.longitude}");

    // Add the location to the terpiezLocations map
    if (!Provider.of<UserModel>(context, listen: false).terpiezMaster.containsKey(terpiezId)) {
      Provider.of<UserModel>(context, listen: false).terpiezMaster[terpiezId] = [];
    }
    Provider.of<UserModel>(context, listen: false).terpiezMaster[terpiezId]!.add(location);

    print('Caught Terpiez $terpiezId at $location');
    print('caughtLocations: ${Provider.of<UserModel>(context, listen: false).caughtLocationSet}');
    print('Caught Terpiez Ids and Locations: ${Provider.of<UserModel>(context, listen: false).terpiezMaster}');

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
      final directory = await getApplicationDocumentsDirectory();
      String imagePath = '${directory.path}/image_$terpiezId.jpg';

      await _showCatchDialog(terpiezData['name'], imagePath );
      print('handleNewCatch completed');
    }

  }

  Future<void> _showCatchDialog(String name, String image) async {
    final directory = await getApplicationDocumentsDirectory();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Caught a Terpiez!'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(name),
                SizedBox(height: 10),
                Image.file(File(image)),  // Assuming 'image' field is base64 encoded string
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Dismiss'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
  accelerometerSubscription?.cancel();
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
                zoom: 16.0,              
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
                closestDistance <= 10
                  ? Icon(Icons.notification_important, color: Colors.red, size: 30)
                  : SizedBox.shrink(),

                // ElevatedButton(
                //   onPressed: closestDistance <= 10 ? () {
                //     Provider.of<UserModel>(context, listen: false).incrementTerpiez();
                //     handleNewCatch(closestID);
                //     markTerpiezAsCaught(closestTerpLocation, closestID);
                //   } : null,
                //   child: Text('Catch Terpiez'),
                //   style: ButtonStyle(
                //     backgroundColor: MaterialStateProperty.resolveWith<Color>(
                //       (Set<MaterialState> states) {
                //         if (states.contains(MaterialState.disabled)) return Colors.grey;
                //         return Colors.green; // Use the component's default.
                //       },
                //     ),
                //   ),
                // ),
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
  final Map<String, dynamic> terpiezData;

  DetailsScreen({required this.terpiezData});

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
  Widget build(BuildContext context) {
    List<LatLng> locations = widget.terpiezData['locations'] ?? [];
    String imagePath = widget.terpiezData['imagePath'] ?? '';
    String name = widget.terpiezData['name'] ?? 'Unknown Terpiez';
    String description = widget.terpiezData['description'] ?? 'No description available.';
    String stats = widget.terpiezData['stats'].toString();

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  color: _animation.value,
                );
              },
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 20),
                Hero(
                  tag: 'hero-$name',
                  child: imagePath.isNotEmpty ? Image.file(File(imagePath), width: 200, height: 200) : Icon(Icons.image_not_supported, size: 200),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(description, textAlign: TextAlign.justify),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Stats: $stats"),
                ),
                Container(
                  height: 250,
                  child: FlutterMap(
                    options: MapOptions(
                      center: locations.isNotEmpty ? locations.first : LatLng(0, 0),
                      zoom: 17.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c']
                      ),
                      MarkerLayer(
                        markers: locations.map((location) => Marker(
                          point: location,
                          child: Icon(Icons.location_on, color: Colors.red),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

