import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class UserModel with ChangeNotifier {
  int _terpiezCaught = 0;
  DateTime _startDate = DateTime.now();
  String _userId = Uuid().v4();

  int get terpiezCaught => _terpiezCaught;
  DateTime get startDate => _startDate;
  String get userId => _userId;

  void incrementTerpiez() {
    _terpiezCaught++;
    notifyListeners();
  }

  int getDaysPlayed() {
    return DateTime.now().difference(_startDate).inDays;
  }
}
