import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:redis/redis.dart';
import 'package:terpiez/global.dart';


class RedisService {
  Command? _command;
  final RedisConnection _connection = RedisConnection();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  bool _isConnected = true;
  bool _lastConnectionState = true;
  Timer? _connectionTimer;

  bool get isConnected => _isConnected;
  


  Future<bool> connect(String username, String password) async {
    try {
      _command = await _connection.connect('cmsc436-0101-redis.cs.umd.edu', 6380).timeout(const Duration(seconds: 1));
      await _command!.send_object(['AUTH', username, password]);
      print('Connected to Redis');
      _isConnected  = true;
      print('current status: $_isConnected');
      print('previous status: $_lastConnectionState');
      //await _notifyConnectionChange();
      return true; // Connection successful
      
    } catch (e) {
      print('Failed to connect to Redis: $e');
      _isConnected = false;
      //await _notifyConnectionChange();
      return false; // Connection failed
    }
  }

  Future<void> startMonitoringConnection() async {
    _connectionTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        print('Checking connection status');
        print('Is connected: $_isConnected');
        print('Last connection state: $_lastConnectionState');
        String username = await _storage.read(key: 'username') ?? "defaultUsername";
        String password = await _storage.read(key: 'password') ?? "defaultPassword";
        print('Attempting to connect');
        await connect(username, password);
        await _notifyConnectionChange();
        await disconnect();
        
      } catch (e) {
        print('Connection check failed: $e');
        await _notifyConnectionChange();
        await disconnect();
        _isConnected = false;
        //await _notifyConnectionChange();
      }
    });
    //_connectionTimer?.cancel();
  }

  Future<void> _notifyConnectionChange() async {
    if (_isConnected != _lastConnectionState) {
      if (_isConnected) {
        print("Sending that Connected to Redis");
        showGlobalSnackbar('Connected to Redis');
      } else if (!_isConnected) {
        print("Sending that not connected to Redis");
        showGlobalSnackbar('Disconnected from Redis');
      }
      _lastConnectionState = _isConnected;
    }
  }


  Future<List<Map<String, dynamic>>> fetchAllLocations() async {
      if (isConnected == false) {
        return [];
      }

      List<Map<String, dynamic>> locations = [];
      String username = await _storage.read(key: 'username') ?? "";
      String password = await _storage.read(key: 'password') ?? "";
      await connect(username,password); // Ensure connection is established

      try {
        var result = await _command!.send_object(['JSON.GET', 'locations']).timeout(Duration(seconds: 1));
        if (result != null) {

          locations = List<Map<String, dynamic>>.from(jsonDecode(result));
          print('all locations:  $locations');
        }
      } catch (e) {
        print('Failed to fetch locations: $e');
        
      }
      await disconnect(); // Ensure connection is closed
      return locations;

  }

  Future<Map<String, dynamic>?> fetchTerpiezData(String terpiezId) async {
      if (isConnected == false) {
        return null;
      }
      String username = await _storage.read(key: 'username') ?? "";
      String password = await _storage.read(key: 'password') ?? "";
        try {
          await connect(username, password);
          var response = await _command!.send_object(['JSON.GET', 'terpiez', '.$terpiezId']).timeout(Duration(seconds: 1));
          if (response != null) {
            response = jsonDecode(response);
            print('Downloaded Terpiez data: $response');
            await disconnect();
            return response;
          }
          return null;
        } catch (e) {
          print('Error fetching Terpiez data: $e');
          await disconnect();
          return null;
        }
  }

  Future<String?> fetchImageData(String imageKey) async {
    if (isConnected == false) {
      return null;
    }
      String username = await _storage.read(key: 'username') ?? "";
      String password = await _storage.read(key: 'password') ?? "";
        try {
          // Using JSON.GET to fetch the image data as a base64 string
          await connect(username, password);
          var response = await _command!.send_object(['JSON.GET', 'images', '.$imageKey']).timeout(Duration(seconds: 1));
          if (response != null) {
            // Extracting image data from the JSON object
            var decodedResponse = jsonDecode(response);
            print('Downloaded image data: $decodedResponse');
            await disconnect();
            return decodedResponse as String; // Assuming the image data is directly a string in the JSON object
          }
        } catch (e) {
          print('Error fetching image data using JSON.GET: $e');
        } finally {
          await disconnect();
        }

  }

  // Future<void> saveTerpiezMasterData(Map<String, List<LatLng>> terpiezMaster, String username, String userId) async {
  //   String username = await _storage.read(key: 'username') ?? "";
  //   String password = await _storage.read(key: 'password') ?? "";
  //   String path = ".$userId";  // The path targets the specific UUID
  //   var jsonData = terpiezMaster.map((id, locations) {
  //     return MapEntry(id, locations.map((location) => {'lat': location.latitude, 'lon': location.longitude}).toList());
  //   });

  //   try {
  //     // Convert the map data to a JSON string
  //     String jsonString = jsonEncode(jsonData);
  //     await connect(username, password); // Ensure connection is established
  //     // Directly set (overwrite) the data at the specific path
  //     await _command?.send_object(['JSON.SET', username, path, jsonString]);
  //     await disconnect();
  //     print('Data overwritten for UUID: $userId under key: $username');
  //   } catch (e) {
  //     print('Error saving data to Redis: $e');
  //   }
  // }

  Future<void> saveUserTerpiez(String userId, Map<String, List<LatLng>> terpiez) async {

      if (isConnected == false) {
        return;
      }
      
      String username = await _storage.read(key: 'username') ?? "defaultUsername";
      
      try{
        await connect(username, await _storage.read(key: 'password') ?? "");

        String key = username;  // Use the username as the top-level key
        //String jsonData = jsonEncode({userId: terpiez});  // Create a JSON object with the UUID as key

      // Retrieve the existing data for the user
        var existingData = await _command!.send_object(['JSON.GET', key]).timeout(Duration(seconds: 1));
        Map<String, dynamic> data;
        if (existingData != null) {
          data = jsonDecode(existingData);
        // Update or add the new UUID and its Terpiez IDs
          data[userId] = terpiez;
        } else {
        // If no existing data, initialize with the current UUID and Terpiez IDs
          data = {userId: terpiez};
        }
        String updatedJsonData = jsonEncode(data);
        await _command!.send_object(['JSON.SET', key, '.', updatedJsonData]).timeout(Duration(seconds: 1));
        await disconnect();
        print('Saved user Terpiez data for user ID: $userId under username: $username');
      } catch (e) {
        print('Error saving user Terpiez data: $e');
        await disconnect();
      }
    
  }

  Future<Map<String, dynamic>?> fetchUserTerpiez(String userId) async {

    if (isConnected == false) {
      return null;
    }
      String username = await _storage.read(key: 'username') ?? "defaultUsername";
      String password= await _storage.read(key: 'password') ?? "defaultPassword";
      try {
        await connect(username, password);
        var response = await _command!.send_object(['JSON.GET', username, '.$userId']).timeout(Duration(seconds: 1));
        if (response != null) {
          response = jsonDecode(response);
          print('Downloaded user Terpiez data: $response');
          await disconnect();
          return response;
        }
        return null;
      } catch (e) {
        print('Error fetching user Terpiez data: $e');
        await disconnect();
        return null;
      }
    
  }




  Future<void> disconnect() async {
    if (_command != null) {
      await _command!.get_connection().close();
      _command = null; // Ensure the command is set to null after disconnecting
      //_isConnected = false;
    }
    print('Disconnected from Redis');
  }
}
