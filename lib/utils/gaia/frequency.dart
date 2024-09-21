import 'dart:math';
import 'package:intl/intl.dart'; // Import the intl package

import 'package:flutter_gaia/utils/gaia/parameter.dart';

/// The parameter "frequency" refers to a band parameter and its configuration and bounds depend on the selected
/// band filter.
/// The factor for this parameter is 3 times the real value.
/// This class overrides the methods [Parameter.setValueFromProportion] and [Parameter.getPositionValue] to provide a logarithmic scale. The logarithmic scale follows these equations:
/// - `y = exp(log(min) + x * (log(max) - log(min)) / (max - min))`
/// - `x = (max - min) * (log(y) - log(min)) / (log(max) - log(min))`
/// - `x` represents the integer value
/// - `y` represents the "length"
/// - `min` represents the minimum bound of the integer range
/// - `max` represents the maximum bound of the integer range
class Frequency extends Parameter {
  /// To define a human readable format for the decimal numbers.
  final NumberFormat _decimalFormat = NumberFormat();

  /// To convert the frequency from the packet value to the displayed one and vice-versa,
  /// we have to multiply by a certain factor defined in the GAIA protocol.
  static const int FACTOR = 3;

  /// To keep the needed values to calculate a logarithmic scale value.
  final LogValues _logValues = LogValues();

  /// To build a new [Parameter] of the type [ParameterType.FREQUENCY].
  Frequency() : super(ParameterType.FREQUENCY);

  @override
  String getLabel(double value) {
    if (isConfigurable) {
      if (value < 50) {
        // value displayed as X.X Hz
        _decimalFormat.maximumFractionDigits = 1;
        return '${_decimalFormat.format(value)} Hz';
      } else if (value < 1000) {
        // value displayed as X Hz
        _decimalFormat.maximumFractionDigits = 0;
        return '${_decimalFormat.format(value)} Hz';
      } else {
        // value displayed as X kHz
        value = value / 1000;
        _decimalFormat.maximumFractionDigits = 1;
        return '${_decimalFormat.format(value)} kHz';
      }
    } else {
      // no value to display
      return '- Hz';
    }
  }

  @override
  int get factor {
    return FACTOR;
  }

  @override
  int get positionValue {
    double length = _logValues.rangeLength *
        (log(value) - _logValues.logMin) /
        _logValues.logRange;
    if (length.isNaN) {
      return 0;
    }
    try {
      return length.round();
    } catch (e) {
      return 0;
    }
  }

  @override
  void setConfigurable(double minBound, double maxBound) {
    super.setConfigurable(minBound, maxBound);

    // we calculate the constant values linked to the given range for the logarithmic scale.
    _logValues.rangeLength = maxBound.toInt() - minBound.toInt();
    _logValues.logMax = log(maxBound);
    _logValues.logMin = log(minBound);
    _logValues.logRange = _logValues.logMax - _logValues.logMin;
  }

  @override
  set valueFromProportion(int lengthValue) {
    double result = _logValues.logMin +
        lengthValue * _logValues.logRange / _logValues.rangeLength;
    result = exp(result);
    int integer = result.round();
    if (integer.isNaN) {
      integer = 0;
    }
    value = integer;
  }
}

/// To calculate the logarithmic scale for the frequency, some numbers are independent of the current parameter
/// value and only depend on the integer range. This class allows these constants to be kept without recalculating
/// while the range does not change.
class LogValues {
  /// This value represents the length of the range defined by the minimum integer bound and the maximum integer
  /// bound.
  int rangeLength = 0;

  /// This value represents the log of the maximum integer bound.
  double logMax = 0;

  /// This value represents the log of the minimum integer bound.
  double logMin = 0;

  /// This value represents the range length from [LogValues.logMin] to [LogValues.logMax].
  double logRange = 0;
}
