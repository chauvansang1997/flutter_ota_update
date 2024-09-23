import 'package:flutter_gaia/utils/gaia/GaiaPacketBLE.dart';

/// GaiaRequest - The data structure to define a GAIA request.
class GaiaRequest {
  final GaiaRequestType type;
  final GaiaPacketBLE packet;

  /// Constructor to create a GaiaRequest object.
  GaiaRequest({
    this.type = GaiaRequestType.SINGLE_REQUEST,
    required this.packet,
  });

  /// Factory constructors for different request types.
  factory GaiaRequest.singleRequest(GaiaPacketBLE packet) {
    GaiaRequest request = GaiaRequest(
      type: GaiaRequestType.SINGLE_REQUEST,
      packet: packet,
    );
    return request;
  }

  factory GaiaRequest.acknowledgement(GaiaPacketBLE packet) {
    GaiaRequest request = GaiaRequest(
      type: GaiaRequestType.ACKNOWLEDGEMENT,
      packet: packet,
    );

    return request;
  }

  factory GaiaRequest.unacknowledgedRequest(GaiaPacketBLE packet) {
    GaiaRequest request = GaiaRequest(
      type: GaiaRequestType.UNACKNOWLEDGED_REQUEST,
      packet: packet,
    );

    return request;
  }
}

/// Enum representing the type of a GaiaRequest.
enum GaiaRequestType {
  SINGLE_REQUEST,
  ACKNOWLEDGEMENT,
  UNACKNOWLEDGED_REQUEST,
}

/// Enum representing different statuses for GAIA.
enum GaiaStatus {
  /// No valid status or an undefined status.
  NOT_STATUS(-1),

  /// The request completed successfully.
  SUCCESS(0),

  /// The command ID sent is invalid or is not supported by the device.
  NOT_SUPPORTED(1),

  /// The host is not authenticated to use a command or control a specific feature.
  NOT_AUTHENTICATED(2),

  /// The command ID is valid but the GAIA device could not complete it due to insufficient resources.
  INSUFFICIENT_RESOURCES(3),

  /// The GAIA device is in the process of authenticating the host.
  AUTHENTICATING(4),

  /// The parameters sent were invalid, such as missing parameters, too many parameters, or out of range.
  INVALID_PARAMETER(5),

  /// The GAIA device is not in the correct state to process the command, such as needing to stream music or use a certain source.
  INCORRECT_STATE(6),

  /// The command is in progress. Acknowledgements with `IN_PROGRESS` status may be sent during time-consuming operations to indicate the operation has not stalled.
  IN_PROGRESS(7);

  /// The integer value associated with each status.
  final int value;

  /// Constructor to assign a value to each status.
  const GaiaStatus(this.value);

  /// Method to retrieve the GaiaStatus corresponding to a given integer value.
  /// If no matching status is found, it returns [GaiaStatus.NOT_STATUS].
  static GaiaStatus fromValue(int value) {
    return GaiaStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => GaiaStatus.NOT_STATUS,
    );
  }
}




/// GaiaAcknowledgementRequest - The data structure to define an acknowledgement request.
class GaiaAcknowledgementRequest extends GaiaRequest {
  final GaiaStatus status;

  /// Constructor to build a new acknowledgement request.
  GaiaAcknowledgementRequest({
    required this.status,
    required super.packet,
  }) : super(type: GaiaRequestType.ACKNOWLEDGEMENT);
}

// /// GaiaPacket - Placeholder for the actual GaiaPacket class.
// class GaiaPacket {
//   final int command;
//   final List<int> payload;

//   GaiaPacket(this.command, this.payload);

//   // Implement other methods and properties based on the actual GaiaPacket structure.
// }
