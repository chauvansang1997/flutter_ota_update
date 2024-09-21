enum Speaker {
  /// The value to send to the speaker when a message concerns the master speaker.
  MASTER_SPEAKER,

  /// The value to send to the speaker when a message concerns the slave speaker.
  SLAVE_SPEAKER,
}

extension SpeakerExtension on Speaker {
  int get value {
    switch (this) {
      case Speaker.MASTER_SPEAKER:
        return 0x00;
      case Speaker.SLAVE_SPEAKER:
        return 0x01;
    }
  }
}