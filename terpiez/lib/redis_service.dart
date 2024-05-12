import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:redis/redis.dart';


class RedisService {
  Command? _command;
  final RedisConnection _connection = RedisConnection();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<bool> connect(String username, String password) async {
    try {
      _command = await _connection.connect('cmsc436-0101-redis.cs.umd.edu', 6380);
      await _command!.send_object(['AUTH', username, password]);
      print('Connected to Redis');
      return true; // Connection successful
      
    } catch (e) {
      print('Failed to connect to Redis: $e');
      return false; // Connection failed
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllLocations() async {
    List<Map<String, dynamic>> locations = [];
    String username = await _storage.read(key: 'username') ?? "";
    String password = await _storage.read(key: 'password') ?? "";
    await connect(username,password); // Ensure connection is established

    try {
      var result = await _command!.send_object(['JSON.GET', 'locations']);
      if (result != null) {

        locations = List<Map<String, dynamic>>.from(jsonDecode(result));
        print('all locations:  $locations');
      }
    } catch (e) {
      print('Failed to fetch locations: $e');
    }
    await disconnect(); // Ensure connection is closed
    print(locations);
    return locations;
  }

  Future<Map<String, dynamic>?> fetchTerpiezData(String terpiezId) async {
    String username = await _storage.read(key: 'username') ?? "";
    String password = await _storage.read(key: 'password') ?? "";
      try {
        await connect(username, password);
        var response = await _command!.send_object(['JSON.GET', 'terpiez', '.$terpiezId']);
        if (response != null) {
          response = jsonDecode(response);
          print('Downloaded Terpiez data: $response');
          await disconnect();
          return response;
        }
      } catch (e) {
        print('Error fetching Terpiez data: $e');
      }
      await disconnect();
      return null;
  }

  Future<String?> fetchImageData(String imageKey) async {
    String username = await _storage.read(key: 'username') ?? "";
    String password = await _storage.read(key: 'password') ?? "";
      try {
        // Using JSON.GET to fetch the image data as a base64 string
        await connect(username, password);
        var response = await _command!.send_object(['JSON.GET', 'images', '.$imageKey']);
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
    return null;
  }



  Future<void> disconnect() async {
    if (_command != null) {
      await _command!.get_connection().close();
      _command = null; // Ensure the command is set to null after disconnecting
    }
    print('Disconnected from Redis');
  }
}
