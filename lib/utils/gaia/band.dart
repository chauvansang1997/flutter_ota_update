import 'package:flutter_gaia/utils/gaia/filter.dart';
import 'package:flutter_gaia/utils/gaia/frequency.dart';
import 'package:flutter_gaia/utils/gaia/gain.dart';
import 'package:flutter_gaia/utils/gaia/parameter.dart';
import 'package:flutter_gaia/utils/gaia/quality.dart';

/// This class represents a Band for the custom equalizer configuration and regroups 4 different parameters:
/// The [Filter] of the band, the [Gain] of the band, the [Frequency] of the band, and the [Quality] of the band.
/// Depending on the selected filter of the band, the other parameters will be configurable or not.
class Band {
  /// The band filter.
  Filter _filter = Filter.BYPASS;

  /// To know if the filter is up to date and has the latest possible value from the device.
  bool _isFilterUpToDate = false;

  /// All the parameters which characterize a band.
  final List<Parameter> _parameters = [];

  /// To build a new instance of the class Band. This will initialize all the parameters.
  Band() {
    _parameters.add(Parameter(ParameterType.FILTER));
    _parameters.add(Frequency());
    _parameters.add(Gain());
    _parameters.add(Quality());
    // _parameters[ParameterType.FREQUENCY.index] = Frequency();
    // _parameters[ParameterType.GAIN.index] = Gain();
    // _parameters[ParameterType.QUALITY.index] = Quality();
  }

  /// To define the filter of the band.
  /// This method will also update the configurability and the bounds of each parameter
  /// using the method [Filter.defineParameters].
  /// If the filter value is from the device, the band filter is considered as up to date.
  void setFilter(Filter filter, bool fromUser) {
    _filter = filter;
    defineParameters(
      filter,
      _parameters[ParameterType.FREQUENCY.index],
      _parameters[ParameterType.GAIN.index],
      _parameters[ParameterType.QUALITY.index],
    );
    if (!fromUser) {
      _isFilterUpToDate = true;
    }
  }

  /// To get the filter of the band.
  Filter getFilter() => _filter;

  /// To get the frequency parameter of the band.
  Parameter getFrequency() => _parameters[ParameterType.FREQUENCY.index];

  /// To get the gain parameter of the band.
  Parameter getGain() => _parameters[ParameterType.GAIN.index];

  /// To get the quality parameter of the band.
  Parameter getQuality() => _parameters[ParameterType.QUALITY.index];

  /// To know if all parameters of the band are considered as being up to date.
  bool isUpToDate() {
    for (int i = 1; i < _parameters.length; i++) {
      if (_parameters[i].isConfigurable && !_parameters[i].isUpToDate) {
        return false;
      }
    }
    return _isFilterUpToDate;
  }

  /// To define the band as being out of date for each of its parameters.
  void hasToBeUpdated() {
    _isFilterUpToDate = false;
    for (int i = 1; i < _parameters.length; i++) {
      _parameters[i].hasToBeUpdated();
    }
  }
}
