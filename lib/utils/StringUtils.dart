import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_gaia/utils/gaia/GAIA.dart';

class StringUtils {
  final hexDigits = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F'
  ];

  static String byteToString(List<int> list) {
    try {
      String string = const Utf8Decoder().convert(list);
      return string;
    } catch (e) {
      log("转换异常 $e");
    }
    return "";
  }

  /// Converts a list of bytes to a human-readable hexadecimal string.
  ///
  /// If the input is null, it returns "null". Each byte is formatted as "0xXX ".
  static String getHexadecimalStringFromBytes(List<int> value) {
    if (value.isEmpty) {
      return '';
    }

    // Create a StringBuffer to efficiently build the resulting string.
    final StringBuffer stringBuffer = StringBuffer();

    // Iterate through each byte and format it as "0xXX ".
    for (int i = 0; i < value.length; i++) {
      stringBuffer.write("0x${value[i].toRadixString(16).padLeft(2, '0')} ");
    }

    // Convert StringBuffer to String and return.
    return stringBuffer.toString();
  }

  static String byteToHexString(List<int> bytes) {
    const hexDigits = '0123456789ABCDEF';
    var charCodes = Uint8List(bytes.length * 2);
    for (var i = 0, j = 0; i < bytes.length; i++) {
      var byte = bytes[i];
      charCodes[j++] = hexDigits.codeUnitAt((byte >> 4) & 0xF);
      charCodes[j++] = hexDigits.codeUnitAt(byte & 0xF);
    }
    return String.fromCharCodes(charCodes);
  }

  static List<int> hexStringToBytes(String hexString) {
    if (hexString.length % 2 != 0) {
      hexString = "0$hexString";
    }
    List<int> ret = [];
    for (int i = 0; i < hexString.length; i += 2) {
      var hex = hexString.substring(i, i + 2);
      ret.add(int.parse(hex, radix: 16));
    }
    return ret;
  }

  /// 用官方的crypto库同步获取md5
  static String file2md5(List<int> input) {
    return md5.convert(input).toString(); // 283M文件用时14148毫秒
  }

  static List<int> encode(String s) {
    return utf8.encode(s);
  }

  static int minToSecond(String s) {
    if (s.isEmpty || !s.contains(":")) return 0;
    return int.parse(s.split(":")[0]) * 60 + int.parse(s.split(":")[1]);
  }

  /// Convert an integer to a human-readable hexadecimal string.
  static String getHexadecimalStringFromInt(int i) {
    return i.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Get a human-readable label for a given GAIA command.
  static String getGAIACommandToString(int command) {
    String name = "UNKNOWN";
    const String deprecated = "(deprecated)";

    switch (command) {
      case GAIA.COMMAND_SET_RAW_CONFIGURATION:
        name = "COMMAND_SET_RAW_CONFIGURATION $deprecated";
        break;
      case GAIA.COMMAND_GET_CONFIGURATION_VERSION:
        name = "COMMAND_GET_CONFIGURATION_VERSION";
        break;
      case GAIA.COMMAND_SET_LED_CONFIGURATION:
        name = "COMMAND_SET_LED_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_LED_CONFIGURATION:
        name = "COMMAND_GET_LED_CONFIGURATION";
        break;
      case GAIA.COMMAND_SET_TONE_CONFIGURATION:
        name = "COMMAND_SET_TONE_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_TONE_CONFIGURATION:
        name = "COMMAND_GET_TONE_CONFIGURATION";
        break;
      case GAIA.COMMAND_SET_DEFAULT_VOLUME:
        name = "COMMAND_SET_DEFAULT_VOLUME";
        break;
      case GAIA.COMMAND_GET_DEFAULT_VOLUME:
        name = "COMMAND_GET_DEFAULT_VOLUME";
        break;
      case GAIA.COMMAND_FACTORY_DEFAULT_RESET:
        name = "COMMAND_FACTORY_DEFAULT_RESET";
        break;
      case GAIA.COMMAND_GET_CONFIGURATION_ID:
        name = "COMMAND_GET_CONFIGURATION_ID $deprecated";
        break;
      case GAIA.COMMAND_SET_VIBRATOR_CONFIGURATION:
        name = "COMMAND_SET_VIBRATOR_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_VIBRATOR_CONFIGURATION:
        name = "COMMAND_GET_VIBRATOR_CONFIGURATION";
        break;
      case GAIA.COMMAND_SET_VOICE_PROMPT_CONFIGURATION:
        name = "COMMAND_SET_VOICE_PROMPT_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_VOICE_PROMPT_CONFIGURATION:
        name = "COMMAND_GET_VOICE_PROMPT_CONFIGURATION";
        break;
      case GAIA.COMMAND_SET_FEATURE_CONFIGURATION:
        name = "COMMAND_SET_FEATURE_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_FEATURE_CONFIGURATION:
        name = "COMMAND_GET_FEATURE_CONFIGURATION";
        break;
      case GAIA.COMMAND_SET_USER_EVENT_CONFIGURATION:
        name = "COMMAND_SET_USER_EVENT_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_USER_EVENT_CONFIGURATION:
        name = "COMMAND_GET_USER_EVENT_CONFIGURATION";
        break;
      case GAIA.COMMAND_SET_TIMER_CONFIGURATION:
        name = "COMMAND_SET_TIMER_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_TIMER_CONFIGURATION:
        name = "COMMAND_GET_TIMER_CONFIGURATION";
        break;
      case GAIA.COMMAND_SET_AUDIO_GAIN_CONFIGURATION:
        name = "COMMAND_SET_AUDIO_GAIN_CONFIGURATION";
        break;
      case GAIA.COMMAND_GET_AUDIO_GAIN_CONFIGURATION:
        name = "COMMAND_GET_AUDIO_GAIN_CONFIGURATION";
        break;
      default:
        name = "UNKNOWN_COMMAND";
    }

    return '${getHexadecimalStringFromInt(command)} $name';
  }

  /**
   * <p>Extract an <code>int</code> value from a <code>bytes</code> array.</p>
   *
   * @param source
   *         The array to extract from.
   * @param offset
   *         Offset within source array.
   * @param length
   *         Number of bytes to use (maximum 4).
   * @param reverse
   *         True if bytes should be interpreted in reverse (little endian) order.
   *
   * @return The extracted <code>int</code>.
   */
  static int extractIntFromByteArray(
      List<int> source, int offset, int length, bool reverse) {
    const bitsInByte = 8;
    if (length < 0 || length > bitsInByte) {
      return 0;
    }
    int result = 0;
    int shift = (length - 1) * bitsInByte;

    if (reverse) {
      for (int i = offset + length - 1; i >= offset; i--) {
        result |= ((source[i] & 0xFF) << shift);
        shift -= bitsInByte;
      }
    } else {
      for (int i = offset; i < offset + length; i++) {
        result |= ((source[i] & 0xFF) << shift);
        shift -= bitsInByte;
      }
    }
    return result;
  }

  static void copyIntIntoByteArray(
      int value, Uint8List array, int offset, int length, bool reverse) {
    for (int i = 0; i < length; i++) {
      int index = reverse ? offset + length - 1 - i : offset + i;
      array[index] = (value >> (8 * i)) & 0xFF;
    }
  }

  static String intTo2HexString(int mVendorId) {
    var high = mVendorId >> 8 & 0xff;
    var low = mVendorId & 0xff;
    return byteToHexString([high, low]);
  }

  static List<int> intTo2List(int mVendorId) {
    var high = mVendorId >> 8 & 0xff;
    var low = mVendorId & 0xff;
    return [high, low];
  }

  static int byteListToInt(List<int> hex) {
    return hex[1] & 0xff | hex[0] << 8 & 0xff;
    //return int.parse(byteToHexString(hex), radix: 16);
  }
}
