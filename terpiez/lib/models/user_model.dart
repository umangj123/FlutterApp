import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terpiez/redis_service.dart';



class UserModel with ChangeNotifier {
  int _terpiezCaught = 0;
  DateTime? _startDate;
  String? _userId;
  Set<String> caughtLocations = Set<String>(); // To store caught locations as "lat,lon"
  Map<String, List<LatLng>> terpiezIDLoc = {};
  RedisService redisService = RedisService();


  //Map<String, List<LatLng>> _terpiezMaster = {}; 

  int get terpiezCaught => _terpiezCaught;
  DateTime get startDate => _startDate ?? DateTime.now();
  String get userId => _userId ?? Uuid().v4();
  Map<String, List<LatLng>> get terpiezMaster => terpiezIDLoc;
  Set<String> get caughtLocationSet => caughtLocations;

  UserModel() {
    loadPreferences();
    //savePreferences();
  }

  Future<void> loadUserTerpiezData() async {
    try {
      await loadPreferences();
      var jsonData = await redisService.fetchUserTerpiez(userId);
      print('To update we got: $jsonData');
      if (jsonData != null  && jsonData != "{}") {
        updateTerpiezData(jsonData);
      }
      _terpiezCaught = caughtLocationSet.length;
    } catch (e) {
      print('Error loading Terpiez data in UserModel: $e');
    }
}


  void updateTerpiezData(Map<String, dynamic> jsonData) {
    //Map<String, dynamic> data = jsonDecode(jsonData);
    terpiezIDLoc.clear();
    caughtLocations.clear();

    jsonData.forEach((terpiezId, locationsJson) {
        List<LatLng> locations = (locationsJson as List).map((locationMap) {
            // Extract coordinates, noting that the array has longitude first, latitude second
            double lon = locationMap['coordinates'][0];
            double lat = locationMap['coordinates'][1];
            // Add to caughtLocations with latitude first
            caughtLocations.add("$lat,$lon");
            return LatLng(lat, lon);
        }).toList();
        // Update the map with the new list of LatLng objects
        terpiezIDLoc[terpiezId] = locations;
    });
    print('Updated Terpiez data: $terpiezIDLoc');
    print('Updated caught locations: $caughtLocations');
    notifyListeners();  // Notify all listening widgets of data change
}


  void incrementTerpiez() async {
    _terpiezCaught++;
    await redisService.saveUserTerpiez(userId, terpiezMaster);
    print('incrementTerpiez with userId: $userId');
    notifyListeners();
    savePreferences();
  }

  int getDaysPlayed() {
    if (_startDate != null) {
      return DateTime.now().difference(_startDate!).inDays;
    }
    return 0;
  }

  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    String? storedDate = prefs.getString('startDate');
    if (storedDate != null) {
      _startDate = DateTime.parse(storedDate);
    } else {
      // Set and save the start date if it's not already stored
      _startDate = DateTime.now();
      await prefs.setString('startDate', _startDate!.toIso8601String());
    }

    if (_userId == null) {
      _userId = Uuid().v4();
      await prefs.setString('userId', _userId!);
    }
    
    _terpiezCaught = prefs.getInt('terpiezCaught') ?? 0;
    notifyListeners();
  }

  Future<void> savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('terpiezCaught', 0);
    if (_userId != null) {
      await prefs.setString('userId', _userId!);
    }
    if (_startDate != null) {
      await prefs.setString('startDate', _startDate!.toIso8601String());
    }
  }
}

