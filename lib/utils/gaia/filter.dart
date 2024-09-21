import 'parameter.dart';

/// This enumeration encapsulates all possible values for the band filter parameter.
enum Filter {
  /// The "Bypass" band filter has the following characteristics:
  /// - number: 0
  /// - no frequency
  /// - no gain
  /// - no quality
  BYPASS,

  /// The "First Order Low Pass" band filter has the following characteristics:
  /// - number: 1
  /// - frequency from 0.3Hz to 20 kHz
  /// - no gain
  /// - no quality
  LOW_PASS_1,

  /// The "First Order High Pass" band filter has the following characteristics:
  /// - number: 2
  /// - frequency from 0.3Hz to 20 kHz
  /// - no gain
  /// - no quality
  HIGH_PASS_1,

  /// The "First Order All Pass" band filter has the following characteristics:
  /// - number: 3
  /// - frequency from 0.3Hz to 20 kHz
  /// - no gain
  /// - no quality
  ALL_PASS_1,

  /// The "First Order Low Shelf" band filter has the following characteristics:
  /// - number: 4
  /// - frequency from 20Hz to 20 kHz
  /// - gain from -12dB to 12dB
  /// - no quality
  LOW_SHELF_1,

  /// The "First Order High Shelf" band filter has the following characteristics:
  /// - number: 5
  /// - frequency from 20Hz to 20 kHz
  /// - gain from -12dB to 12dB
  /// - no quality
  HIGH_SHELF_1,

  /// The "First Order Tilt" band filter has the following characteristics:
  /// - number: 6
  /// - frequency from 20Hz to 20 kHz
  /// - gain from -12dB to 12dB
  /// - no quality
  TILT_1,

  /// The "Second Order Low Pass" band filter has the following characteristics:
  /// - number: 7
  /// - frequency from 40Hz to 20kHz
  /// - no gain
  /// - quality from 0.25 to 2
  LOW_PASS_2,

  /// The "Second Order High Pass" band filter has the following characteristics:
  /// - number: 8
  /// - frequency from 40Hz to 20kHz
  /// - no gain
  /// - quality from 0.25 to 2
  HIGH_PASS_2,

  /// The "Second Order All Pass" band filter has the following characteristics:
  /// - number: 9
  /// - frequency from 40Hz to 20kHz
  /// - no gain
  /// - quality from 0.25 to 2
  ALL_PASS_2,

  /// The "Second Order Low Shelf" band filter has the following characteristics:
  /// - number: 10
  /// - frequency from 40Hz to 20kHz
  /// - gain from -12 dB to +12 dB
  /// - quality from 0.25 to 2
  LOW_SHELF_2,

  /// The "Second Order High Shelf" band filter has the following characteristics:
  /// - number: 11
  /// - frequency from 40Hz to 20kHz
  /// - gain from -12 dB to +12 dB
  /// - quality from 0.25 to 2
  HIGH_SHELF_2,

  /// The "Second Order Tilt" band filter has the following characteristics:
  /// - number: 12
  /// - frequency from 40Hz to 20kHz
  /// - gain from -12 dB to +12 dB
  /// - quality from 0.25 to 2
  TILT_2,

  /// The "Parametric Equalizer" band filter has the following characteristics:
  /// - number: 13
  /// - frequency from 20Hz to 20kHz
  /// - gain from -36 dB to +12 dB
  /// - quality from 0.25 to 8.0
  PARAMETRIC_EQUALIZER,
}

/// To define the parameter ranges corresponding to the given filter.
void defineParameters(
    Filter filter, Parameter frequency, Parameter gain, Parameter quality) {
  switch (filter) {
    case Filter.HIGH_PASS_1:
    case Filter.ALL_PASS_1:
    case Filter.LOW_PASS_1:
      // frequency 0.3Hz to 20 kHz, no gain, no quality
      frequency.setConfigurable(0.333, 20000);
      gain.setNotConfigurable();
      quality.setNotConfigurable();
      break;

    case Filter.HIGH_PASS_2:
    case Filter.ALL_PASS_2:
    case Filter.LOW_PASS_2:
      // frequency from 40Hz to 20kHz, no gain, quality from 0.25 to 2.0
      frequency.setConfigurable(40, 20000);
      gain.setNotConfigurable();
      quality.setConfigurable(0.25, 2);
      break;

    case Filter.LOW_SHELF_1:
    case Filter.HIGH_SHELF_1:
    case Filter.TILT_1:
      // frequency from 20Hz to 20 kHz, gain from -12dB to 12dB, no quality
      frequency.setConfigurable(20, 20000);
      gain.setConfigurable(-12, 12);
      quality.setNotConfigurable();
      break;

    case Filter.LOW_SHELF_2:
    case Filter.HIGH_SHELF_2:
    case Filter.TILT_2:
      // frequency from 40Hz to 20kHz, gain from -12 dB to +12 dB, quality from 0.25 to 2.0
      frequency.setConfigurable(40, 20000);
      gain.setConfigurable(-12, 12);
      quality.setConfigurable(0.25, 2);
      break;

    case Filter.BYPASS:
      // no frequency, no gain, no quality
      frequency.setNotConfigurable();
      gain.setNotConfigurable();
      quality.setNotConfigurable();
      break;

    case Filter.PARAMETRIC_EQUALIZER:
      // frequency from 20Hz to 20kHz, gain from -36dB to 12dB, quality from 0.25 to 8.0
      frequency.setConfigurable(20, 20000);
      gain.setConfigurable(-36, 12);
      quality.setConfigurable(0.25, 8);
      break;
  }
}

/// Extension on int to convert to Filter enum.
extension FilterExtension on int {
  Filter? toFilter() {
    if (this < 0 || this >= Filter.values.length) {
      return null;
    }
    return Filter.values[this];
  }
}
