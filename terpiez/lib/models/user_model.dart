import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel with ChangeNotifier {
  int _terpiezCaught = 0;
  DateTime? _startDate;
  String? _userId;
  //Map<String, List<LatLng>> _terpiezMaster = {}; 

  int get terpiezCaught => _terpiezCaught;
  DateTime get startDate => _startDate ?? DateTime.now();
  String get userId => _userId ?? Uuid().v4();
  //Map<String, List<LatLng>> get terpiezMaster => _terpiezMaster;

  UserModel() {
    loadPreferences();
  }

  void incrementTerpiez() {
    _terpiezCaught++;
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
    await prefs.setInt('terpiezCaught', _terpiezCaught);
    if (_userId != null) {
      await prefs.setString('userId', _userId!);
    }
    if (_startDate != null) {
      await prefs.setString('startDate', _startDate!.toIso8601String());
    }
  }
}
