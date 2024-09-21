import 'package:flutter_gaia/utils/gaia/parameter.dart';
import 'package:intl/intl.dart';

/// The parameter "quality" refers to a band parameter, and its configuration and bounds depend on the selected
/// band filter. The factor for this parameter is 4096 times the real value.
class Quality extends Parameter {
  /// To define a human-readable format for the decimal numbers.
  final NumberFormat _numberFormat = NumberFormat();

  /// To convert the quality from the packet value to the displayed one and vice-versa,
  /// we have to multiply by a certain factor defined in the GAIA protocol.
  static const int FACTOR = 4096;

  /// To build a new [Parameter] of the type [ParameterType.QUALITY].
  Quality() : super(ParameterType.QUALITY);

  @override
  String getLabel(double value) {
    if (isConfigurable) {
      _numberFormat.maximumFractionDigits = 2;
      return _numberFormat.format(value);
    } else {
      return '-';
    }
  }

  @override
  int get factor {
    return FACTOR;
  }
}
