enum Channel {
  /// A speaker acts on a STEREO route.
  STEREO,

  /// A speaker acts on a LEFT route.
  LEFT,

  /// A speaker acts on a RIGHT route.
  RIGHT,

  /// A speaker acts on a MONO route.
  MONO,
}

extension ChannelExtension on Channel {
  int get value {
    switch (this) {
      case Channel.STEREO:
        return 0x00;
      case Channel.LEFT:
        return 0x01;
      case Channel.RIGHT:
        return 0x02;
      case Channel.MONO:
        return 0x03;
    }
  }
}
