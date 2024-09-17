import '../../StringUtils.dart';
import 'RWCP.dart';

/// This class represents the data structure of the messages sent over RWCP. These messages are
/// called segments and their structure is as follows:
///
/// ```
/// 0 byte     1         ...         n
/// +----------+----------+----------+
/// |  HEADER  |       PAYLOAD       |
/// +----------+----------+----------+
/// ```
///
/// The header of a RWCP segment contains the information to identify the segment: a sequence number and an
/// operation code. The header is contained in one byte for which the bits are allocated as follows:
///
/// ```
/// 0 bit     ...         6          7          8
/// +----------+----------+----------+----------+
/// |   SEQUENCE NUMBER   |   OPERATION CODE    |
/// +----------+----------+----------+----------+
/// ```
///
/// @since 3.3.0
class Segment {
// ====== FIELDS ====================================================================
  /// The tag to display for logs.
  final String TAG = "Segment";

  /// The operation code which defines the type of segment.
  int mOperationCode = -1;

  /// The sequence number which defines the segment in a RWCP session.
  int mSequenceNumber = -1;

  /// The value of the header built on a combination of the operation code and the sequence number.
  int mHeader = 0;

  /// The payload contains the data of the segment which is transferred using RWCP.
  List<int>? mPayload;

  /// The bytes array which contains this segment.
  List<int>? mBytes;

  /// To build a segment with its operation code, its sequence number, and payload.
  ///
  /// @param operationCode
  ///        The code which defines the type of segment.
  /// @param sequenceNumber
  ///        The sequence number which identifies this segment in a RWCP session.
  /// @param payload
  ///        The data which is transferred using this segment.
  static Segment get(int operationCode, int sequenceNumber,
      {List<int>? payload}) {
    final seg = Segment();
    seg.mOperationCode = operationCode;
    seg.mSequenceNumber = sequenceNumber;
    seg.mPayload = payload ?? [];
    seg.mHeader = (operationCode << SegmentHeader.SEQUENCE_NUMBER_BITS_LENGTH) |
        sequenceNumber;
    return seg;
  }

  static Segment parse(List<int>? bytes) {
    int mOperationCode = -1;
    int mSequenceNumber = -1;
    int mHeader = -1;
    List<int> mPayload = [];

    if (bytes == null ||
        bytes.length < RWCPSegment.REQUIRED_INFORMATION_LENGTH) {
      mOperationCode = -1;
      mSequenceNumber = -1;
      mHeader = -1;
      mPayload = bytes ?? [];
    } else {
      mHeader = bytes[RWCPSegment.HEADER_OFFSET];
      mOperationCode = getBits(mHeader, SegmentHeader.OPERATION_CODE_BIT_OFFSET,
          SegmentHeader.OPERATION_CODE_BITS_LENGTH);
      mSequenceNumber = getBits(
          mHeader,
          SegmentHeader.SEQUENCE_NUMBER_BIT_OFFSET,
          SegmentHeader.SEQUENCE_NUMBER_BITS_LENGTH);
      mPayload = bytes.sublist(1);
    }
    final seg = Segment();
    seg.mBytes = bytes;
    seg.mOperationCode = mOperationCode;
    seg.mSequenceNumber = mSequenceNumber;
    seg.mPayload = mPayload;
    seg.mHeader = mHeader;
    return seg;
  }

  /// To get the bytes of this segment.
  ///
  /// If the bytes have not been built yet this method builds the byte array as follows:
  ///
  /// ```
  /// 0 byte     1         ...         n
  /// +----------+----------+----------+
  /// |  HEADER  |       PAYLOAD       |
  /// +----------+----------+----------+
  /// ```
  ///
  /// @return The byte array which contains this segment information.
  List<int> getBytes() {
    if (mBytes == null) {
      mBytes = [];
      int payloadLength = (mPayload == null) ? 0 : mPayload?.length ?? 0;
      mBytes?.add(mHeader);
      // data if exists
      if (payloadLength > 0) {
        mBytes?.addAll(mPayload ?? []);
      }
    }

    return mBytes ?? [];
  }

  // ====== STATIC METHODS ====================================================================

  /// To get an information contained in a byte, starting at the given offset bit and of the given bit length.
  ///
  /// @param value
  ///        The 8 bits value.
  /// @param offset
  ///        The bit offset at which to find the information.
  /// @param length
  ///        The number of bits representing the information.
  ///
  /// @return The split value.
  static int getBits(int value, int offset, int length) {
    int mask = ((1 << length) - 1) << offset;
    return (value & mask) >>> offset;
  }

  @override
  String toString() {
    var res = "";
    res += "mOperationCode $mOperationCode";
    res += "mSequenceNumber $mSequenceNumber";
    res += "mPayload ${StringUtils.byteToHexString(mPayload ?? [])}";
    return res;
  }

  int getOperationCode() {
    return mOperationCode;
  }

  List<int> getPayload() {
    return mPayload ?? [];
  }

  int getSequenceNumber() {
    return mSequenceNumber;
  }

  int getHeader() {
    return mHeader;
  }
}
