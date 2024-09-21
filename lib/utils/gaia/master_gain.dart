import 'package:flutter_gaia/utils/gaia/parameter.dart';
import 'package:intl/intl.dart';

/// The parameter "master gain" refers to a band parameter and its configuration and bounds depend on the selected
/// band filter.
/// The master gain is in a range from -36dB to 12 dB.
/// The factor for this parameter is 60 times the real value.
class MasterGain extends Parameter {
  /// To define a human readable format for the decimal numbers.
  final NumberFormat _decimalFormat = NumberFormat();

  /// To convert the master gain from the packet value to the displayed one and vice-versa,
  /// we have to multiply by a certain factor defined in the GAIA protocol.
  static const int FACTOR = 60;
  static const int MIN = 0;
  static const int MAX = 100;

  /// To build a new [Parameter] without any type which corresponds to the Master Gain of the Bank.
  MasterGain() : super(null);

  @override
  String getLabel(double masterGain) {
    if (isConfigurable) {
      _decimalFormat.maximumFractionDigits = 1;
      return "${_decimalFormat.format(masterGain)} dB";
    } else {
      return "- dB";
    }
  }

  @override
  int get factor {
    return FACTOR;
  }
}
