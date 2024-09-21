import 'package:flutter_gaia/utils/gaia/parameter.dart';
import 'package:intl/intl.dart';

/// The parameter "gain" refers to a band parameter, and its configuration and bounds depend on the selected
/// band filter. The factor for this parameter is 60 times the real value.
class Gain extends Parameter {
  /// To define a human-readable format for the decimal numbers.
  final NumberFormat _numberFormat = NumberFormat();

  /// To convert the gain from the packet value to the displayed one and vice-versa,
  /// we have to multiply by a certain factor defined in the GAIA protocol.
  static const int FACTOR = 60;

  /// To build a new [Parameter] of the type [ParameterType.GAIN].
  Gain() : super(ParameterType.GAIN);

  @override
  String getLabel(double value) {
    if (isConfigurable) {
      _numberFormat.maximumFractionDigits = 1;
      return '${_numberFormat.format(value)} dB';
    } else {
      return '- dB';
    }
  }

  @override
  int get factor {
    return FACTOR;
  }
}
