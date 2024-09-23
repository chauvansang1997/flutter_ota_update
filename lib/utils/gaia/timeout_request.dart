import 'dart:async';

import 'package:flutter_gaia/utils/gaia/GaiaPacketBLE.dart';
import 'package:flutter_gaia/utils/gaia/gaia_request.dart';

/// TimeoutRequest - Represents a request with a timeout.
class TimeoutRequest {
  final GaiaRequest request;
  final Duration duration;
  final Function(TimeoutRequest request) onTimeout;

  Timer? _timer;

  TimeoutRequest({
    required this.request,
    required this.duration,
    required this.onTimeout,
  });

  void start() {
    _timer = Timer(duration, () => onTimeout(this));
  }

  void cancel() {
    _timer?.cancel();
  }
}
