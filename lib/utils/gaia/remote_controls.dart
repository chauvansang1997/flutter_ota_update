enum RemoteControls {
  /// The AV remote control operation for volume up.
  VOLUME_UP(0x41),

  /// The AV remote control operation for volume down.
  VOLUME_DOWN(0x42),

  /// The AV remote control operation for mute.
  MUTE(0x43),

  /// The AV remote control operation for play.
  PLAY(0x44),

  /// The AV remote control operation for stop.
  STOP(0x45),

  /// The AV remote control operation for pause.
  PAUSE(0x46),

  /// The AV remote control operation for rewind.
  REWIND(0x4C),

  /// The AV remote control operation for forward.
  FORWARD(0x4B);

  final int value;

  const RemoteControls(this.value);
}