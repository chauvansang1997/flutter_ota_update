enum EqualizerControls {
  /// This application can control the 3D enhancement using the following commands:
  /// - COMMAND_GET_3D_ENHANCEMENT_CONTROL: to get the current activation state (enabled/disabled).
  /// - COMMAND_SET_3D_ENHANCEMENT_CONTROL: to set up the activation state.
  ENHANCEMENT_3D,

  /// This application can control the Boost bass using the following commands:
  /// - COMMAND_GET_BASS_BOOST_CONTROL: to get the current activation state (enabled/disabled).
  /// - COMMAND_SET_BASS_BOOST_CONTROL: to set up the activation state.
  BASS_BOOST,

  /// This application can control the pre-set banks using the following commands:
  /// - COMMAND_GET_USER_EQ_CONTROL: to get the current activation state of the pre-sets (enabled/disabled).
  /// - COMMAND_SET_USER_EQ_CONTROL: to set up the activation state.
  /// - COMMAND_GET_EQ_CONTROL: to get the current pre-set.
  /// - COMMAND_SET_EQ_CONTROL: to set up the selected pre-set.
  PRESETS,
}

extension ControlsExtension on EqualizerControls {
  int get value {
    switch (this) {
      case EqualizerControls.ENHANCEMENT_3D:
        return 1;
      case EqualizerControls.BASS_BOOST:
        return 2;
      case EqualizerControls.PRESETS:
        return 3;
    }
  }
}
