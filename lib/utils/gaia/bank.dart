import 'package:flutter_gaia/utils/gaia/band.dart';
import 'package:flutter_gaia/utils/gaia/master_gain.dart';
import 'package:flutter_gaia/utils/gaia/parameter.dart';

class Bank {
  /// All bands for this bank.
  List<Band> _bands;

  /// The current band to configure.
  int _currentBand;

  int get currentBandIndex => _currentBand;
  /// The default minimum value for the master gain.
  static const double MASTER_GAIN_MIN = -36;

  /// The default maximum value for the master gain.
  static const double MASTER_GAIN_MAX = 12;

  /// The values for the master gain displayed to the user.
  Parameter _masterGain = MasterGain();

  /// To build a new instance of the class Bank.
  Bank(int number)
      : _bands = List<Band>.generate(number, (_) => Band()),
        _currentBand = 1 {
    _masterGain.setConfigurable(MASTER_GAIN_MIN, MASTER_GAIN_MAX);
  }

  /// To define the band to configure.
  void setCurrentBand(int number) {
    if (number < 1) {
      number = 1;
    } else if (number >= _bands.length) {
      number = _bands.length;
    }
    _currentBand = number;
  }

  /// To get the current band which is configurable.
  int getNumberCurrentBand() {
    return _currentBand;
  }

  /// To get the current configurable band.
  Band getCurrentBand() {
    return _bands[_currentBand - 1];
  }

  /// To get the band which corresponds to the given number.
  Band getBand(int number) {
    if (number < 1) {
      number = 1;
    } else if (number > _bands.length) {
      number = _bands.length;
    }
    return _bands[number - 1];
  }

  /// To get the master gain parameter for this bank.
  Parameter getMasterGain() {
    return _masterGain;
  }

  /// To define this bank as has to be updated.
  void hasToBeUpdated() {
    for (var band in _bands) {
      band.hasToBeUpdated();
    }
  }

  /// Creates a copy of this Bank but with the given fields replaced with the new values.
  Bank copyWith({
    List<Band>? bands,
    int? currentBand,
    Parameter? masterGain,
  }) {
    return Bank(_bands.length)
      .._bands = bands ?? _bands
      .._currentBand = currentBand ?? _currentBand
      .._masterGain = masterGain ?? _masterGain;
  }
}
