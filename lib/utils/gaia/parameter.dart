import 'package:flutter/material.dart';

/// This class defines all the properties for each customizable parameter. Each parameter is defined
/// by a range, a value and a [ParameterType] parameter type.
/// The value corresponds to an [int] in a range defined by the parameter type.
/// This value is the raw value get from the device. To get a human readable value for a parameter it is calculated
/// as follows: `readableValue = deviceValue / factor`
/// The bounds follow the same principle: they are kept as bounds of the raw value and to get a human readable
/// version the same calculation will be used.
class Parameter {
  // ====== CONSTS ===============================================================================

  /// The allocated case in an array to get the minimum value for a parameter.
  static const int MIN_BOUND_OFFSET = 0;

  /// The allocated case in an array to get the maximum value for a parameter.
  static const int MAX_BOUND_OFFSET = 1;

  // ====== PRIVATE FIELDS ===============================================================================

  /// The bounds for the raw range of this parameter value.
  final List<int> _rawBounds = List.filled(2, 0);

  /// The label values for the readable bounds of the parameter.
  final List<String> _labelBounds = List.filled(2, '');

  /// To know if this parameter has to be updated.
  bool _isUpToDate = false;

  /// To know the type if this parameter.
  final ParameterType? _type;

  /// The current raw value of this parameter.
  int _rawValue = 0;

  int get factor => 1;

  // ====== PACKAGE FIELD ===============================================================================

  /// To know if this parameter can be modified - depending on the filter of a band, a parameter can be no modifiable.
  bool _isConfigurable = false;

  // ====== CONSTRUCTOR ===============================================================================

  /// To build a Parameter object defined by its type.
  Parameter(this._type);

  // ====== GETTERS ===============================================================================

  /// To get the type of this parameter.
  ParameterType? get parameterType => _type;

  /// To get the raw value of this parameter as known by the device.
  int get value => _rawValue;

  /// To get the position of this parameter value in a range from 0 to the value given by
  /// [getBoundsLength]. This can be used to set up a [Slider] for instance.
  /// This method will calculate the returned value as follows: `rawValue - minBound`.
  int get positionValue => _rawValue - _rawBounds[MIN_BOUND_OFFSET];

  /// To get the length of range. This could be used to create an interval from 0 to this
  /// value, for instance to know the maximum bound of a [Slider].
  int get boundsLength =>
      _rawBounds[MAX_BOUND_OFFSET] - _rawBounds[MIN_BOUND_OFFSET];

  /// To know if this parameter is configurable. A parameter is configurable depending on the filter set up on
  /// the device for the band to which this parameter is attached.
  /// If this parameter represents a Master Gain, the parameter is always configurable.
  bool get isConfigurable => _isConfigurable;

  /// To know if this parameter is up to date.
  /// When one of the parameters of the bank had changed it can impact all other parameters. For
  /// instance, if the filter of a band is set up to a new value, the gain, quality and frequency values of the band
  /// have to be updated as well. In which case all the parameters are set up to an out of date state.
  bool get isUpToDate => _isUpToDate;

  /// To get the label which corresponds to the minimum bound - as a readable value - for the range of this
  /// parameter.
  String get labelMinBound =>
      _isConfigurable ? _labelBounds[MIN_BOUND_OFFSET] : '';

  /// To get the label which corresponds to the maximum bound - as a readable value - for the range of this parameter.
  String get labelMaxBound =>
      _isConfigurable ? _labelBounds[MAX_BOUND_OFFSET] : '';

  /// To get the label which corresponds to the readable value of this parameter.
  /// This method first calculates the readable value of the parameter and then uses the method
  /// [getLabel] to get the corresponding String value which includes the unit.
  String get labelValue {
    double realValue = _rawValue / factor;
    return getLabel(realValue);
  }

  /// To get the raw value of the minimum bound of the range.
  int get minBound => _rawBounds[MIN_BOUND_OFFSET];

  /// To get the raw value of the maximum bound of the range.
  int get maxBound => _rawBounds[MAX_BOUND_OFFSET];

  // ====== SETTERS ===============================================================================

  /// To define the raw value of this parameter.
  set value(int parameterValue) {
    _isUpToDate = true;
    _rawValue = parameterValue;
  }

  /// To define the raw value of this parameter by giving the corresponding proportion value in an interval from
  /// 0 to the range between the 2 bounds of this parameter.
  set valueFromProportion(int lengthValue) {
    _rawValue = lengthValue + _rawBounds[MIN_BOUND_OFFSET];
  }

  /// To define this parameter as configurable by giving its new readable range bounds values.
  void setConfigurable(double minBound, double maxBound) {
    _isConfigurable = true;
    _setBound(MIN_BOUND_OFFSET, minBound);
    _setBound(MAX_BOUND_OFFSET, maxBound);
  }

  /// To define this parameter as not configurable by the user.
  void setNotConfigurable() {
    _isConfigurable = false;
  }

  /// To define this parameter as out of date.
  /// When one of the parameters of the bank has changed it can impact all other parameters. For
  /// instance, if the filter of a band is set up to a new value, the gain, quality and frequency values of the band
  /// have to be updated as well. In which case all the parameters are set up to an out of date state.
  void hasToBeUpdated() {
    _isUpToDate = false;
  }

  // ====== PRIVATE METHODS ===============================================================================

  /// To define one of the bounds of this parameter range. This method will create the label corresponding to
  /// the readable bound, and will create the raw value corresponding to the raw range.
  void _setBound(int position, double value) {
    _labelBounds[position] = getLabel(value);
    _rawBounds[position] = (value * factor).toInt();
  }

  // ====== ABSTRACT METHODS ===============================================================================

  /// To get a human readable value to display.
  String getLabel(double value) {
    return '';
  }

  // /// To get the factor corresponding to this parameter.
  // int getFactor() {
  //   return 1;
  // }
}

/// This enumeration defines all the different parameters a [Band] has.
enum ParameterType {
  /// Each band has a filter type which is defined in the Filter enumeration.
  FILTER,

  /// Each band has a frequency parameter depending on the selected filter type.
  FREQUENCY,

  /// Each band has a gain parameter depending on the selected filter type.
  GAIN,

  /// Each band has a quality parameter depending on the selected filter type.
  QUALITY,

  // MATER_GAIN
}

// extension ParameterTypeExtension on ParameterType {
//   static const List<ParameterType> values = ParameterType.values;

//   /// To get the band type matching the corresponding int value in this enumeration.
//   static ParameterType? valueOf(int value) {
//     if (value < 0 || value >= values.length) {
//       return null;
//     }
//     return values[value];
//   }

//   /// To get the number of values for this enumeration.
//   static int getSize() {
//     return values.length;
//   }
// }

extension ParameterTypeExtension on int {
  ParameterType? toParameterType() {
    if (this < 0 || this >= ParameterType.values.length) {
      return null;
    }
    return ParameterType.values[this];
  }
}
