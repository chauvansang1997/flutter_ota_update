import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_gaia/utils/gaia/band.dart';
import 'package:flutter_gaia/utils/gaia/bank.dart';
import 'package:flutter_gaia/utils/gaia/channel.dart';
import 'package:flutter_gaia/utils/gaia/equalizer_controls.dart';
import 'package:flutter_gaia/utils/gaia/filter.dart';
import 'package:flutter_gaia/utils/gaia/parameter.dart';
import 'package:flutter_gaia/utils/gaia/remote_controls.dart';
import 'package:flutter_gaia/utils/gaia/speaker.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart' hide Rx;
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';
import '../../../utils/gaia/ConfirmationType.dart';
import '../../../utils/gaia/GAIA.dart';
import '../../../utils/gaia/GaiaPacketBLE.dart';
import '../../../utils/gaia/OpCodes.dart';
import '../../../utils/gaia/ResumePoints.dart';
import '../../../utils/gaia/UpgradeStartCFMStatus.dart';
import '../../../utils/gaia/VMUPacket.dart';
import '../../../utils/gaia/rwcp/RWCPClient.dart';
import '../utils/StringUtils.dart';
import '../utils/gaia/rwcp/RWCPListener.dart';

class TransferModes {
  static const int MODE_RWCP = 1;
  static const int MODE_NONE = 0;
}

class OtaServer extends GetxService implements RWCPListener {
  final flutterReactiveBle = FlutterReactiveBle();
  var logText = "".obs;
  final String TAG = "OtaServer";
  var devices = <DiscoveredDevice>[].obs;
  var connectedDevices = <String>[].obs;
  StreamSubscription<DiscoveredDevice>? _scanConnection;
  Timer? _connectTimer;
  final isConnecting = false.obs;
  final isRegisterNotification = false.obs;
  final isRWCPRegisterNotification = false.obs;

  // final requestSendingValue = [];

  final mapTimeOutRequest = <int, Timer>{};
  final mapCompleterRequest = <int, Completer>{};
  final mapSendingRequest = <int, RxBool>{};

  String connectDeviceId = "";
  Uuid otaUUID = Uuid.parse("00001100-d102-11e1-9b23-00025b00a5a5");
  Uuid notifyUUID = Uuid.parse("00001102-d102-11e1-9b23-00025b00a5a5");
  Uuid writeUUID = Uuid.parse("00001101-d102-11e1-9b23-00025b00a5a5");
  Uuid writeNoResUUID = Uuid.parse("00001103-d102-11e1-9b23-00025b00a5a5");
  StreamSubscription<ConnectionStateUpdate>? _connection;
  String _selectedFile = '';
  final int MAX_VOLUME = 100; // Assuming MAX_VOLUME is defined somewhere
  final int PARAMETER_MASTER_GAIN = 0x01; // Assuming a constant value

  final deviceVersion = "".obs;
  /**
   * To know if the upgrade process is currently running.
   */
  final isUpgrading = false.obs;
  final isBandUpdating = false.obs;

  bool transferComplete = false;
  bool controllEqualizer = false;
  final controllEqualizerError = false.obs;
  final bassBoost = false.obs;
  final enhancement3D = false.obs;
  final presets = false.obs;
  final currentPreset = (-1).obs;
  final selectedPreset = (-1).obs;
  final volume = 0.0.obs;
  // final masterGain = 0.0.obs;
  // final gain = 0.obs;
  // final quality = 0.obs;
  // final frequency = 0.obs;
  final filterIndex = (-1).obs;

  final mBank = Bank(5).obs;
  /**
   * To know how many times we try to start the upgrade.
   */
  var mStartAttempts = 0;

  /**
   * The offset to use to upload data on the device.
   */
  var mStartOffset = 0;

  /**
   * The file to upload on the device.
   */
  List<int>? mBytesFile;

  // List<int> writeBytes = [];

  /**
   * The maximum value for the data length of a VM upgrade packet for the data transfer step.
   */
  var mMaxLengthForDataTransfer = 16;

  var mPayloadSizeMax = 16;
  // var mReceivedPayloadSizeMax = 16;

  /**
   * To know if the packet with the operation code "UPGRADE_DATA" which was sent was the last packet to send.
   */
  bool wasLastPacket = false;

  // bool _isUpgradeComplete = false;
  // bool _isUpgradeStart = false;

  int mBytesToSend = 0;

  int mResumePoint = -1;
  bool _disconnectWhenUpgrading = false;
  var mIsRWCPEnabled = true.obs;
  int sendPkgCount = 0;

  bool _requestEqualizer = false;

  RxDouble updatePer = RxDouble(0);

  /**
   * To know if we have to disconnect after any event which occurs as a fatal error from the board.
   */
  bool hasToAbort = false;

  final writeQueue = Queue<List<int>>();

  final upgradeComplete = false.obs;

  StreamSubscription<List<int>>? _subscribeConnection;

  StreamSubscription<List<int>>? _subscribeConnectionRWCP;

  String fileMd5 = "";

  var percentage = 0.0.obs;

  Timer? _timer;
  Timer? _notificationRegisterTimer;
  Timer? _notificationRWCPRegisterTimer;
  Timer? _rwcpStartTimer;

  var timeCount = 0.obs;

  //RWCP
  final ListQueue<double> _progressQueue = ListQueue();

  late RWCPClient mRWCPClient;

  int mTransferStartTime = 0;

  int writeRTCPCount = 0;

  int maxRetry = 5;

  File? file;

  static OtaServer get to => Get.find();

  void requestEqualizer() {
    bassBoost.value = false;
    enhancement3D.value = false;
    presets.value = false;
    _requestEqualizer = true;
  }

  void unRequestEqualizer() {
    bassBoost.value = false;
    enhancement3D.value = false;
    presets.value = false;
    _requestEqualizer = false;
  }

  @override
  void onInit() {
    super.onInit();
    mRWCPClient = RWCPClient(this);
    // mRWCPClient.setInitialWindowSize(mRWCPClient.mMaximumWindow);
    flutterReactiveBle.statusStream.listen((event) {
      switch (event) {
        case BleStatus.ready:
          addLog("Bluetooth is on");
          break;
        case BleStatus.poweredOff:
          addLog("Bluetooth is off");
          break;
        case BleStatus.unknown:
          break;
        case BleStatus.unsupported:
          break;
        case BleStatus.unauthorized:
          break;
        case BleStatus.locationServicesDisabled:
          break;
      }
    });
  }

  String connectingDeviceId = '';
  int _retryCount = 0;
  void connectDevice(String id, [bool isRetry = false]) async {
    try {
      deviceVersion.value = "";
      if (isRetry && connectingDeviceId == id && !isUpgrading.value) {
        _retryCount++;
      }

      if (isRetry &&
          connectingDeviceId == id &&
          _retryCount > maxRetry &&
          !isUpgrading.value) {
        isConnecting.value = false;
        _connectTimer?.cancel();
        _retryCount = 0;
        connectingDeviceId = '';

        return;
      }

      connectingDeviceId = id;

      addLog('Starting connection to $id');
      isConnecting.value = true;

      Fluttertoast.showToast(
        msg: "Connecting to device $id",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      isRegisterNotification.value = false;
      _connectTimer?.cancel();
      _connectTimer = Timer.periodic(const Duration(seconds: 5), (timeer) {
        if (isConnecting.value) {
          isConnecting.value = false;
          addLog('Connection timeout');
          _retryCount = 0;
          // connectDevice(id);
          Fluttertoast.showToast(
            msg: "Connection timeout. Please try again",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      });

      flutterReactiveBle.connectedDeviceStream.listen((connectedDevice) {
        if (connectedDevice.connectionState ==
            DeviceConnectionState.connected) {
          connectedDevices.add(connectedDevice.deviceId);
        } else {
          connectedDevices.remove(connectedDevice.deviceId);
        }
      });

      await disconnect();
      await Future.delayed(const Duration(seconds: 1));

      _connection = flutterReactiveBle
          .connectToDevice(
        id: id,
        connectionTimeout: const Duration(seconds: 5),
      )
          .listen(
        (connectionState) async {
          if (connectionState.connectionState ==
              DeviceConnectionState.connected) {
            isConnecting.value = false;

            _connectTimer?.cancel();
            connectDeviceId = id;
            addLog("Connection successful $connectDeviceId");

            try {
              // iOS BUG
              await flutterReactiveBle.discoverAllServices(id);
            } catch (e) {
              Fluttertoast.showToast(
                msg: "Can not bonded to device $id",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                fontSize: 16.0,
              );
              addLog("Failed to start connection $e");
              return;
            }

            Fluttertoast.showToast(
              msg: "Bonded to device $id",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 16.0,
            );

            // if (!isUpgrading.value) {
            //   Get.to(() => const TestOtaView());
            // }

            // flutterReactiveBle.connectToAdvertisingDevice(id: id, withServices: withServices, prescanDuration: prescanDuration)
            Future.delayed(const Duration(seconds: 1))
                .then((value) => registerNotice());
          } else if (connectionState.connectionState ==
              DeviceConnectionState.disconnected) {
            _connectTimer?.cancel();

            addLog('Disconnected');

            Fluttertoast.showToast(
              msg: "Device disconnected",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );

            isConnecting.value = false;

            if (isUpgrading.value) {
              _disconnectWhenUpgrading = false;
              connectDevice(id, true);
              return;
            }

            connectDevice(id, true);
          } else {
            // isConnecting.value = false;

            // Fluttertoast.showToast(
            //   msg: "Disconnected ${connectionState.connectionState}",
            //   toastLength: Toast.LENGTH_SHORT,
            //   gravity: ToastGravity.BOTTOM,
            //   timeInSecForIosWeb: 1,
            //   backgroundColor: Colors.red,
            //   textColor: Colors.white,
            //   fontSize: 16.0,
            // );

            addLog('${connectionState.connectionState}');
          }
        },
        onError: (e) {
          isConnecting.value = false;

          addLog('Connection error $e');
        },
      );
    } catch (e) {
      isConnecting.value = false;

      addLog('Failed to start connection $e');
    }
  }

  void writeMsg(List<int> data) {
    scheduleMicrotask(() {
      writeData(data);
    });
  }

  void getInformation() {
    final pkg = GaiaPacketBLE(GAIA.COMMAND_GET_API_VERSION, mPayload: [0]);
    writeMsg(pkg.getBytes());
  }

  void receivePacketGetAPIVersionACK(GaiaPacketBLE packet) {
    List<int>? payload = packet.getPayload();
    const int PAYLOAD_VALUE_1_OFFSET = 1;
    const int PAYLOAD_VALUE_2_OFFSET = PAYLOAD_VALUE_1_OFFSET + 1;
    const int PAYLOAD_VALUE_3_OFFSET = PAYLOAD_VALUE_2_OFFSET + 1;
    const int PAYLOAD_VALUE_LENGTH = 3;
    const int PAYLOAD_MIN_LENGTH =
        PAYLOAD_VALUE_LENGTH + 1; // ACK status length is 1

    if (payload != null && payload.length >= PAYLOAD_MIN_LENGTH) {
      String verion =
          "${payload[PAYLOAD_VALUE_1_OFFSET]}.${payload[PAYLOAD_VALUE_2_OFFSET]}.${payload[PAYLOAD_VALUE_3_OFFSET]}";
      deviceVersion.value = verion;
      // print("API Version: $verion");
      // mListener.onGetAPIVersion(
      //   payload[PAYLOAD_VALUE_1_OFFSET],
      //   payload[PAYLOAD_VALUE_2_OFFSET],
      //   payload[PAYLOAD_VALUE_3_OFFSET],
      // );
    }
  }

  Future<void> registerRWCP() async {
    // int mode = mIsRWCPEnabled.value
    //     ? TransferModes.MODE_RWCP
    //     : TransferModes.MODE_NONE;

    // Uint8List RWCPMode = Uint8List(1)..[0] = mode;

    // final pkg =
    //     GaiaPacketBLE(GAIA.COMMAND_SET_DATA_ENDPOINT_MODE, mPayload: RWCPMode);

    // writeMsg(pkg.getBytes());

    _notificationRWCPRegisterTimer?.cancel();
    _notificationRWCPRegisterTimer = Timer(const Duration(seconds: 5), () {
      if (isRWCPRegisterNotification.value) {
        return;
      }

      isRWCPRegisterNotification.value = false;
    });
    writeMsg(StringUtils.hexStringToBytes("000A022E01"));
  }

  // Timer? _receiveDataTimer;
  void startRegisterRWCP() async {
    await _subscribeConnectionRWCP?.cancel();
    //IOS BUG
    await flutterReactiveBle.discoverAllServices(connectDeviceId);
    await Future.delayed(const Duration(seconds: 1));
    // disconnectUpgrade();
    // await Future.delayed(const Duration(seconds: 3));

    final characteristic = QualifiedCharacteristic(
      serviceId: otaUUID,
      characteristicId: writeNoResUUID,
      deviceId: connectDeviceId,
    );

    _subscribeConnectionRWCP = flutterReactiveBle
        .subscribeToCharacteristic(characteristic)
        .listen((data) {
      //addLog("wenDataRec2>${StringUtils.byteToHexString(data)}");
      mRWCPClient.onReceiveRWCPSegment(data);
      _rwcpStartTimer?.cancel();
      // code to handle incoming data
    }, onError: (dynamic error) {
      // code to handle errors
      isRWCPRegisterNotification.value = false;

      Fluttertoast.showToast(
        msg: "RegisterRWCP error $error",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      if (isUpgrading.value) {
        stopUpgrade();
      }
    });
    isRWCPRegisterNotification.value = true;
    addLog("isUpgrading: $isUpgrading transFerComplete: $transferComplete");
    // await Future.delayed(const Duration(seconds: 1));
    // if (isUpgrading.value && transFerComplete) {
    //   transFerComplete = false;
    //   sendUpgradeConnect();
    // }

    //  else {
    //   if (!isUpgrading.value) {
    //     startUpdate(_selectedFile);
    //   }
    // }
  }

  // Register notifications
  void registerNotice() async {
    _notificationRegisterTimer?.cancel();
    _notificationRegisterTimer = Timer(const Duration(seconds: 5), () {
      if (isRegisterNotification.value) {
        return;
      }

      isRegisterNotification.value = false;
    });

    await _subscribeConnection?.cancel();
    // iOS requires discovering services first, otherwise subscription will fail
    try {
      await flutterReactiveBle.discoverAllServices(connectDeviceId);
      await Future.delayed(const Duration(seconds: 1));
    } catch (_) {
      Fluttertoast.showToast(
        msg: "Failed to bond to device",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    Fluttertoast.showToast(
      msg: "Registering notice to device",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );

    final characteristic = QualifiedCharacteristic(
      serviceId: otaUUID,
      characteristicId: notifyUUID,
      deviceId: connectDeviceId,
    );

    _subscribeConnection = flutterReactiveBle
        .subscribeToCharacteristic(characteristic)
        .listen((data) {
      addLog("Notification received > ${StringUtils.byteToHexString(data)}");
      handleRecMsg(data);
      // code to handle incoming data
    }, onError: (dynamic error) {
      // print(error);
      // code to handle errors
    });

    GaiaPacketBLE packet = GaiaPacketBLE.buildGaiaNotificationPacket(
        GAIA.COMMAND_REGISTER_NOTIFICATION, GAIA.VMU_PACKET, null, GAIA.BLE);

    await Future.delayed(const Duration(seconds: 1));

    writeMsg(packet.getBytes());
    // If RWCP is enabled, re-enable it after reconnecting
    // if (isUpgrading.value && transFerComplete && mIsRWCPEnabled.value) {
    //   // Enable RWCP
    //   await Future.delayed(const Duration(seconds: 1));
    //   writeMsg(StringUtils.hexStringToBytes("000A022E01"));
    // }
    await Future.delayed(const Duration(seconds: 1));

    if (isUpgrading.value) {
      // int mode = mIsRWCPEnabled.value
      //     ? TransferModes.MODE_RWCP
      //     : TransferModes.MODE_NONE;

      // // Uint8List RWCPMode = Uint8List(1)..[0] = 0x01;
      // Uint8List RWCPMode = Uint8List(1)..[0] = mode;

      // final pkg = GaiaPacketBLE(GAIA.COMMAND_SET_DATA_ENDPOINT_MODE,
      //     mPayload: RWCPMode);

      // writeMsg(pkg.getBytes());

      // transFerComplete = false;
      sendUpgradeConnect();
    }

    if (mIsRWCPEnabled.value) {
      if (!isUpgrading.value) {
        await Future.delayed(const Duration(seconds: 1));
        await restPayloadSize();
      }

      await Future.delayed(const Duration(seconds: 1));

      // Enable RWCP
      writeMsg(StringUtils.hexStringToBytes("000A022E01"));

      _notificationRWCPRegisterTimer?.cancel();
      _notificationRWCPRegisterTimer = Timer(const Duration(seconds: 5), () {
        if (isRWCPRegisterNotification.value) {
          return;
        }

        connectDevice(connectDeviceId);
        isRWCPRegisterNotification.value = false;
      });
    } else {
      writeMsg(StringUtils.hexStringToBytes("000A022E00"));
    }

    // int mode = mIsRWCPEnabled.value
    //     ? TransferModes.MODE_RWCP
    //     : TransferModes.MODE_NONE;

    // // Uint8List RWCPMode = Uint8List(1)..[0] = 0x01;
    // Uint8List RWCPMode = Uint8List(1)..[0] = mode;

    // final pkg =
    //     GaiaPacketBLE(GAIA.COMMAND_SET_DATA_ENDPOINT_MODE, mPayload: RWCPMode);

    // writeMsg(pkg.getBytes());
  }

  // bool _cancelPreviousUpgrade = false;

  void startUpdate(String filePath) async {
    // await stopUpgrade();
    // _haveSendUpgradeDisconnected = false;
    // _isUpgradeStart = false;
    // _numberConnected = 0;
    _selectedFile = filePath;
    logText.value = "";
    transferComplete = false;
    // writeBytes.clear();
    writeRTCPCount = 0;
    _progressQueue.clear();
    mTransferStartTime = 0;
    timeCount.value = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timeCount.value += 1;
    });
    sendPkgCount = 0;
    updatePer.value = 0;
    isUpgrading.value = false;
    writeQueue.clear();
    resetUpload();
    // registerNotice();
    sendUpgradeConnect();
    //startUpgradeProcess();
  }

  void handleRecMsg(List<int> data) async {
    GaiaPacketBLE packet = GaiaPacketBLE.fromByte(data) ?? GaiaPacketBLE(0);
    if (packet.isAcknowledgement()) {
      int status = packet.getStatus();
      if (status == GAIA.SUCCESS) {
        receiveSuccessfulAcknowledgement(packet);
      } else {
        receiveUnsuccessfulAcknowledgement(packet);
      }
    } else if (packet.getCommand() == GAIA.COMMAND_EVENT_NOTIFICATION) {
      final payload = packet.mPayload ?? [];
      //000AC0010012
      if (payload.isNotEmpty) {
        int event = packet.getEvent();
        if (event == GAIA.VMU_PACKET) {
          createAcknowledgmentRequest(packet, 0);
          await Future.delayed(const Duration(milliseconds: 1000));
          receiveVMUPacket(payload.sublist(1));
          return;
        } else {
          createAcknowledgmentRequest(packet, 1);
          // not supported
          return;
        }
      } else {
        createAcknowledgmentRequest(packet, 5);
        // await Future.delayed(const Duration(milliseconds: 1000));
        return;
      }
    }
  }

  ///Create response packet.
  void createAcknowledgmentRequest(GaiaPacketBLE packet, int status) {
    // writeMsg(StringUtils.hexStringToBytes("000AC00300"));
    // final bytes = packet.getAcknowledgementPacketBytes(status, null);
    writeMsg(StringUtils.hexStringToBytes("000AC00300"));
    // writeMsg(bytes);
  }

  bool hasToRestartUpgrade = false;

  void processRequest(int status, List<int>? data) {}

  // int _numberConnected = 0;

  void receiveSuccessfulAcknowledgement(GaiaPacketBLE packet) {
    // addLog(
    //     "receiveSuccessfulAcknowledgement ${StringUtils.intTo2HexString(packet.getCommand())}");
    // print(GAIA.COMMAND_VM_UPGRADE_CONNECT.toString() +
    //     " " +
    // packet.getCommand().toString());
    final command = packet.getCommand();
    switch (command) {
      case GAIA.COMMAND_SET_EQ_PARAMETER:
        // receiveGetEQParameterACK(packet);
        break;
      case GAIA.COMMAND_SET_3D_ENHANCEMENT_CONTROL:
        // receiveGetEQParameterACK(packet);
        break;
      case GAIA.COMMAND_GET_EQ_PARAMETER:
        receiveGetEQParameterACK(packet);
        break;
      case GAIA.COMMAND_GET_TWS_AUDIO_ROUTING:
        receiveGetChannelACK(packet);
        break;

      case GAIA.COMMAND_GET_TWS_VOLUME:
        receiveGetVolumeACK(packet);
        break;
      case GAIA.COMMAND_GET_USER_EQ_CONTROL:
        receiveGetControlACK(EqualizerControls.PRESETS, packet);
        break;

      case GAIA.COMMAND_GET_EQ_CONTROL:
        receiveGetEQControlACK(packet);
        break;

      case GAIA.COMMAND_GET_3D_ENHANCEMENT_CONTROL:
        receiveGetControlACK(EqualizerControls.ENHANCEMENT_3D, packet);
        break;

      case GAIA.COMMAND_GET_BASS_BOOST_CONTROL:
        receiveGetControlACK(EqualizerControls.BASS_BOOST, packet);
        break;
      case GAIA.COMMAND_REGISTER_NOTIFICATION:
        {
          Fluttertoast.showToast(
            msg: "Register notice successful",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          _notificationRegisterTimer?.cancel();

          getInformation();
          isRegisterNotification.value = true;

          if (_requestEqualizer) {
            getActivationState(EqualizerControls.BASS_BOOST);
            getActivationState(EqualizerControls.ENHANCEMENT_3D);
            getActivationState(EqualizerControls.PRESETS);
          }
          // if (isUpgrading) {
          //   resetUpload();
          //   sendSyncReq();
          // } else {
          //   int size = mPayloadSizeMax;
          //   if (mIsRWCPEnabled.value) {
          //     size = mPayloadSizeMax - 1;
          //     size = (size % 2 == 0) ? size : size - 1;
          //   }
          //   mMaxLengthForDataTransfer =
          //       size - VMUPacket.REQUIRED_INFORMATION_LENGTH;
          //   addLog(
          //       "mMaxLengthForDataTransfer $mMaxLengthForDataTransfer mPayloadSizeMax $mPayloadSizeMax");
          //   // Start sending the upgrade package
          //   startUpgradeProcess();
          // }
        }
        break;
      case GAIA.COMMAND_VM_UPGRADE_CONNECT:
        {
          Fluttertoast.showToast(
            msg: "Upgrade connected",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );

          // _numberConnected++;

          // if (_numberConnected == 3) {
          //   return;
          // }
          if (isUpgrading.value) {
            resetUpload();
            sendSyncReq();
          } else {
            int size = mPayloadSizeMax;
            if (mIsRWCPEnabled.value) {
              size = mPayloadSizeMax - 1;
              size = (size % 2 == 0) ? size : size - 1;
            }
            mMaxLengthForDataTransfer =
                size - VMUPacket.REQUIRED_INFORMATION_LENGTH;
            addLog(
                "mMaxLengthForDataTransfer $mMaxLengthForDataTransfer mPayloadSizeMax $mPayloadSizeMax");
            // Start sending the upgrade package
            startUpgradeProcess();
          }
        }
        break;
      case GAIA.COMMAND_VM_UPGRADE_DISCONNECT:
        if (hasToRestartUpgrade) {
          hasToRestartUpgrade = false;
          startUpgradeProcess();
        } else {
          Fluttertoast.showToast(
            msg: "Upgrade disconnected",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );

          stopUpgrade();
        }
        // if (!_isUpgradeComplete) {
        //   connectDevice(connectDeviceId);
        //   return;
        // }

        break;
      case GAIA.COMMAND_VM_UPGRADE_CONTROL:
        onSuccessfulTransmission();
        break;
      case GAIA.COMMAND_SET_DATA_ENDPOINT_MODE:
        if (mIsRWCPEnabled.value) {
          startRegisterRWCP();
        } else {
          _subscribeConnectionRWCP?.cancel();
        }
        break;
      case GAIA.COMMAND_GET_DATA_ENDPOINT_MODE:
        // print(packet.getCommand());
        break;
      case GAIA.COMMAND_GET_API_VERSION:
        // print(packet.getCommand());
        receivePacketGetAPIVersionACK(packet);
        break;
    }
    completeSendingRequest(command);
  }

  void completeSendingRequest(int command) {
    bool isAnyTrue = false;

    try {
      mapSendingRequest[command]?.value = false;
      mapTimeOutRequest[command]?.cancel();
      mapCompleterRequest[command]?.complete();
    } catch (_) {}

    /// Loop through the map and check if any of the value is true
    for (final entry in mapSendingRequest.entries) {
      if (entry.value.value == false) {
        continue;
      }

      isAnyTrue = true;
      break;
    }

    if (isAnyTrue) {
      isSendingRequest.value = true;
    } else {
      isSendingRequest.value = false;
    }

    // switch (command) {
    //   case GAIA.COMMAND_SET_EQ_CONTROL:
    //     break;
    //   case GAIA.COMMAND_SET_USER_EQ_CONTROL:
    //     break;
    //   case GAIA.COMMAND_SET_SPEAKER_EQ_CONTROL:
    //     break;
    //   case GAIA.COMMAND_SET_TWS_VOLUME:
    //     break;
    // }
  }

  void startConfigure() {
    controllEqualizer = true;
    controllEqualizerError.value = false;
    mBank.value.hasToBeUpdated();

    ///getMasterGain
    getEQParameter(GENERAL_BAND, PARAMETER_MASTER_GAIN);
    int band = mBank.value.getNumberCurrentBand();
    getEQParameter(band, ParameterType.FILTER.index);

    getPreset();
    mBank.value = mBank.value.copyWith();
    // createRequest(createPacket(GAIA.COMMAND_GET_EQ_CONTROL));

    // getMasterGain();
  }

  void receiveGetEQParameterACK(GaiaPacketBLE packet) {
    List<int>? payload = packet.getPayload();
    const int OFFSET_PARAMETER_ID_LOW_BYTE = 2;
    const int VALUE_OFFSET = 3;
    const int VALUE_LENGTH = 2;
    const int GET_EQ_PARAMETER_PAYLOAD_LENGTH = 5; // Assuming a constant value
    const int GENERAL_BAND = 0; // Assuming a constant value

    if (payload == null || payload.length < GET_EQ_PARAMETER_PAYLOAD_LENGTH) {
      print(
          "Received \"COMMAND_GET_EQ_PARAMETER\" packet with missing arguments.");
      return;
    }

    int bandNumber = (payload[OFFSET_PARAMETER_ID_LOW_BYTE] & 0xF0) >> 4;
    int param = payload[OFFSET_PARAMETER_ID_LOW_BYTE] & 0x0F;

    if (bandNumber == GENERAL_BAND && param == PARAMETER_MASTER_GAIN) {
      int masterGainValue = StringUtils.extractIntFromByteArray(
          payload, VALUE_OFFSET, VALUE_LENGTH, false);

      // int masterGainValue = StringUtils.extractShortFromByteArray(
      //     payload, VALUE_OFFSET, VALUE_LENGTH, false);
      // mListener.onGetMasterGain(masterGainValue);
      mBank.value.getMasterGain().value = masterGainValue;
      if (mBank.value.getCurrentBand().isUpToDate()) {
        isBandUpdating.value = false;
      }
      print("MASTER GAIN - value: $masterGainValue");
    } else {
      ParameterType? parameterType = param.toParameterType();
      // mBank.getMasterGain().setValue(value);

      if (parameterType == null) {
        print(
            "Received \"COMMAND_GET_EQ_PARAMETER\" packet with an unknown parameter type: $param");
        return;
      }

      switch (parameterType) {
        case ParameterType.FILTER:
          int filterValue = StringUtils.extractIntFromByteArray(
              payload, VALUE_OFFSET, VALUE_LENGTH, false);
          Filter? filter = filterValue.toFilter();
          if (filter == null) {
            print(
                "Received \"COMMAND_GET_EQ_PARAMETER\" packet with an unknown filter type: $filterValue");
            return;
          }

          // final isCurrentBand =
          //     bandNumber == mBank.value.getNumberCurrentBand();

          // mBank.value.setCurrentBand(bandNumber);
          // filterIndex.value = filter.index;
          // final bandNumber = mBank.value.getNumberCurrentBand();

          setFilter(bandNumber, filter, false);
          // Band band = mBank.value.getBand(bandNumber);
          // band.setFilter(filter, false);

          // final isFrequencyConfigurable = band.getFrequency().isConfigurable;

          // if (isFrequencyConfigurable) {
          //   getEQParameter(bandNumber, ParameterType.FREQUENCY.index);
          // }

          // final isGainConfigurable = band.getGain().isConfigurable;

          // if (isGainConfigurable) {
          //   getEQParameter(bandNumber, ParameterType.GAIN.index);
          // }

          // final isQualityConfigurable = band.getQuality().isConfigurable;

          // if (isQualityConfigurable) {
          //   getEQParameter(bandNumber, ParameterType.QUALITY.index);
          // }

          // if (mBank.value.getCurrentBand().isUpToDate()) {
          //   isBandUpdating.value = false;
          // }
          // mBank.getBand(band) = filter;
          // mListener.onGetFilter(band, filter);

          print(
              "BAND: $bandNumber - PARAM: ${parameterType.toString()} - FILTER: ${filter.toString()}");
          break;

        case ParameterType.FREQUENCY:
          int frequencyValue = StringUtils.extractIntFromByteArray(
              payload, VALUE_OFFSET, VALUE_LENGTH, false);

          // frequency.value = frequencyValue;
          mBank.value.getCurrentBand().getFrequency().value = frequencyValue;
          // mListener.onGetFrequency(band, frequencyValue);

          if (mBank.value.getCurrentBand().isUpToDate()) {
            isBandUpdating.value = false;
          }
          print(
              "BAND: $bandNumber - PARAM: ${parameterType.toString()} - FREQUENCY: $frequencyValue");
          break;

        case ParameterType.GAIN:
          int gainValue = StringUtils.extractIntFromByteArray(
              payload, VALUE_OFFSET, VALUE_LENGTH, false);
          mBank.value.getCurrentBand().getGain().value = gainValue;
          // gain.value = gainValue;

          if (mBank.value.getCurrentBand().isUpToDate()) {
            isBandUpdating.value = false;
          }
          // mListener.onGetGain(band, gainValue);
          print(
              "BAND: $bandNumber - PARAM: ${parameterType.toString()} - GAIN: $gainValue");
          break;

        case ParameterType.QUALITY:
          int qualityValue = StringUtils.extractIntFromByteArray(
              payload, VALUE_OFFSET, VALUE_LENGTH, false);

          // quality.value = qualityValue;
          mBank.value.getCurrentBand().getQuality().value = qualityValue;

          if (mBank.value.getCurrentBand().isUpToDate()) {
            isBandUpdating.value = false;
          }
          // mListener.onGetQuality(band, qualityValue);
          print(
              "BAND: $bandNumber - PARAM: ${parameterType.toString()} - QUALITY: $qualityValue");
          break;
      }
    }
  }

  void setFilter(int bandNumber, Filter filter, bool fromUser) {
    filterIndex.value = filter.index;
    Band band = mBank.value.getBand(bandNumber);
    band.setFilter(filter, fromUser);

    final isFrequencyConfigurable = band.getFrequency().isConfigurable;

    if (isFrequencyConfigurable) {
      getEQParameter(bandNumber, ParameterType.FREQUENCY.index);
    }

    final isGainConfigurable = band.getGain().isConfigurable;

    if (isGainConfigurable) {
      getEQParameter(bandNumber, ParameterType.GAIN.index);
    }

    final isQualityConfigurable = band.getQuality().isConfigurable;

    if (isQualityConfigurable) {
      getEQParameter(bandNumber, ParameterType.QUALITY.index);
    }

    if (mBank.value.getCurrentBand().isUpToDate()) {
      isBandUpdating.value = false;
    }

    mBank.value = mBank.value.copyWith();
  }

  void sendControlCommand(RemoteControls control) {
    const int PAYLOAD_LENGTH = 1;
    const int CONTROL_OFFSET = 0;

    Uint8List payload = Uint8List(PAYLOAD_LENGTH);
    payload[CONTROL_OFFSET] = control.value;

    // createRequest(createPacket(GAIA.COMMAND_AV_REMOTE_CONTROL, payload));

    GaiaPacketBLE packet =
        GaiaPacketBLE(GAIA.COMMAND_AV_REMOTE_CONTROL, mPayload: payload);
    writeMsg(packet.getBytes());
  }

  void setEQParameter(int band, int parameter, int value) {
    const int PAYLOAD_LENGTH = 5;
    const int ID_PARAMETER_HIGH_OFFSET = 0;
    const int ID_PARAMETER_LOW_OFFSET = 1;
    const int VALUE_OFFSET = 2;
    const int VALUE_LENGTH = 2;
    const int RECALCULATION_OFFSET = 4;
    const int EQ_PARAMETER_FIRST_BYTE = 0x01; // Assuming a constant value
    // const int GAIA_COMMAND_SET_EQ_PARAMETER = 0x00; // Assuming a constant value

    Uint8List payload = Uint8List(PAYLOAD_LENGTH);
    payload[ID_PARAMETER_HIGH_OFFSET] = EQ_PARAMETER_FIRST_BYTE;
    payload[ID_PARAMETER_LOW_OFFSET] = buildParameterIDLowByte(band, parameter);

    StringUtils.copyIntIntoByteArray(
      value,
      payload,
      VALUE_OFFSET,
      VALUE_LENGTH,
      false,
    );

    payload[RECALCULATION_OFFSET] = true ? 0x01 : 0x00;

    // createRequest(createPacket(GAIA_COMMAND_SET_EQ_PARAMETER, payload));

    GaiaPacketBLE packet =
        GaiaPacketBLE(GAIA.COMMAND_SET_EQ_PARAMETER, mPayload: payload);
    writeMsg(packet.getBytes());
  }

  void selectBand(int band) {
    // Deselect previous values on the UI
    // mBandButtons[mBank.getNumberCurrentBand()].isSelected = false;
    // mFilters[mBank.getCurrentBand().getFilter().index].isSelected = false;

    // Select new values on the UI
    // mBandButtons[band].isSelected = true;

    // Define the new band
    mBank.value.setCurrentBand(band);
    // Update the displayed values
    // updateDisplayParameters();
    mBank.value = mBank.value.copyWith();
    mBank.value.getBand(band).hasToBeUpdated();

    // print(
    //     "Request GET eq parameter for band $band and parameter ${ParameterType.FILTER.toString()}");

    getEQParameter(band, ParameterType.FILTER.index);
  }

  Timer? _gainDebounce;

  void onGainChange(int gainValue) {
    if (_gainDebounce?.isActive ?? false) {
      _gainDebounce?.cancel();
    }
    final parameter = mBank.value.getCurrentBand().getGain();

    parameter.valueFromProportion = gainValue;
    mBank.value = mBank.value.copyWith();

    final parameterType = parameter.parameterType;
    int parameterValue =
        parameterType != null ? parameterType.index : PARAMETER_MASTER_GAIN;
    int band = parameterType != null
        ? mBank.value.getNumberCurrentBand()
        : GENERAL_BAND;

    // Set a delay of 500ms before calling the API
    _gainDebounce = Timer(const Duration(milliseconds: 500), () {
      setEQParameter(band, parameterValue, gainValue);
    });
  }

  Timer? _frequencyDebounce;

  void onFrequencyChange(int frequencyValue) {
    if (_frequencyDebounce?.isActive ?? false) {
      _frequencyDebounce?.cancel();
    }

    final parameter = mBank.value.getCurrentBand().getFrequency();

    parameter.valueFromProportion = frequencyValue;

    mBank.value = mBank.value.copyWith();

    ParameterType? parameterType = parameter.parameterType;

    int parameterValue =
        parameterType != null ? parameterType.index : PARAMETER_MASTER_GAIN;

    int band = parameterType != null
        ? mBank.value.getNumberCurrentBand()
        : GENERAL_BAND;

    // Set a delay of 500ms before calling the API
    _frequencyDebounce = Timer(const Duration(milliseconds: 500), () {
      setEQParameter(band, parameterValue, frequencyValue);
    });
  }

  Timer? _qualityDebounce;

  void onQualityChange(int qualityValue) {
    if (_qualityDebounce?.isActive ?? false) {
      _qualityDebounce?.cancel();
    }
    final parameter = mBank.value.getCurrentBand().getQuality();

    parameter.valueFromProportion = qualityValue;
    mBank.value = mBank.value.copyWith();

    ParameterType? parameterType = parameter.parameterType;
    int parameterValue =
        parameterType != null ? parameterType.index : PARAMETER_MASTER_GAIN;
    int band = parameterType != null
        ? mBank.value.getNumberCurrentBand()
        : GENERAL_BAND;

    // Set a delay of 500ms before calling the API
    _qualityDebounce = Timer(const Duration(milliseconds: 500), () {
      setEQParameter(band, parameterValue, qualityValue);
    });
  }

  Timer? _masterGainDebounce;
  void onMaterGain(int masterGainValue) {
    // OtaServer.to.mBank.value.getMasterGain().value = masterGainValue;
    // Debouncing logic: Cancel previous timer and start a new one
    if (_masterGainDebounce?.isActive ?? false) {
      _masterGainDebounce?.cancel();
    }

    final parameter = mBank.value.getMasterGain();
    parameter.valueFromProportion = masterGainValue;
    mBank.value = mBank.value.copyWith();

    ParameterType? parameterType = parameter.parameterType;
    int parameterValue = parameterType != null ? parameterType.index : 0x01;
    int band = parameterType != null
        ? mBank.value.getNumberCurrentBand()
        : GENERAL_BAND;

    // Set a delay of 500ms before calling the API
    _masterGainDebounce = Timer(const Duration(milliseconds: 500), () {
      setEQParameter(band, parameterValue, masterGainValue);
    });
  }

  // static const int PARAMETER_MASTER_GAIN = 0; // Assuming a constant value
  static const int GENERAL_BAND = 0; // Assuming a constant value
  // static const int EQ_PARAMETER_FIRST_BYTE = 0; // Assuming a constant value
  static const int GET_EQ_PARAMETER_PAYLOAD_LENGTH =
      0; // Assuming a constant value

  void getEQParameter(int band, int parameterType) async {
    const int PAYLOAD_LENGTH = 2;
    const int ID_PARAMETER_HIGH_OFFSET = 0;
    const int ID_PARAMETER_LOW_OFFSET = 1;
    const int EQ_PARAMETER_FIRST_BYTE = 0x01; // Assuming a constant value
    // const int GAIA_COMMAND_GET_EQ_PARAMETER = 0x00; // Assuming a constant value

    Uint8List payload = Uint8List(PAYLOAD_LENGTH);
    payload[ID_PARAMETER_HIGH_OFFSET] = EQ_PARAMETER_FIRST_BYTE;
    payload[ID_PARAMETER_LOW_OFFSET] =
        buildParameterIDLowByte(band, parameterType);
    GaiaPacketBLE packet =
        GaiaPacketBLE(GAIA.COMMAND_GET_EQ_PARAMETER, mPayload: payload);
    const controlType = GAIA.COMMAND_GET_EQ_PARAMETER;

    isSendingRequest.value = true;

    if (mapCompleterRequest[controlType]?.isCompleted == false) {
      await mapCompleterRequest[controlType]?.future;
    }

    mapCompleterRequest[controlType] = Completer();

    if (!mapSendingRequest.containsKey(controlType)) {
      mapSendingRequest[controlType] = true.obs;
    } else {
      mapSendingRequest[controlType]?.value = true;
    }

    mapTimeOutRequest[controlType]?.cancel();

    mapTimeOutRequest[controlType] = Timer(const Duration(seconds: 5), () {
      mapSendingRequest[controlType]?.value = false;
      mapCompleterRequest[controlType]?.complete();
    });

    registerSendingRequest();

    writeMsg(packet.getBytes());
    // createRequest(createPacket(GAIA_COMMAND_GET_EQ_PARAMETER, payload));
  }

  int buildParameterIDLowByte(int band, int parameter) {
    // Implementation for building the parameter ID low byte
    return (band << 4) | (parameter & 0x0F);
  }

  void receiveGetControlACK(EqualizerControls control, GaiaPacketBLE packet) {
    List<int>? payload = packet.getPayload();
    const int PAYLOAD_VALUE_OFFSET = 1;
    const int PAYLOAD_VALUE_LENGTH = 1;
    const int PAYLOAD_MIN_LENGTH =
        PAYLOAD_VALUE_LENGTH + 1; // ACK status length is 1

    if (payload != null && payload.length >= PAYLOAD_MIN_LENGTH) {
      bool activate = payload[PAYLOAD_VALUE_OFFSET] == 0x01;
      switch (control) {
        case EqualizerControls.BASS_BOOST:
          bassBoost.value = activate;
          break;
        case EqualizerControls.ENHANCEMENT_3D:
          enhancement3D.value = activate;
          break;
        case EqualizerControls.PRESETS:
          presets.value = activate;
          if (activate) {
            getPreset();
          }
          break;
      }
      // mListener.onGetControlActivationState(control, activate);
    }
  }

  void receiveGetEQControlACK(GaiaPacketBLE packet) {
    List<int>? payload = packet.getPayload();
    const int PAYLOAD_VALUE_OFFSET = 1;
    const int PAYLOAD_VALUE_LENGTH = 1;
    const int PAYLOAD_MIN_LENGTH =
        PAYLOAD_VALUE_LENGTH + 1; // ACK status length is 1

    if (payload != null && payload.length >= PAYLOAD_MIN_LENGTH) {
      int preset = payload[PAYLOAD_VALUE_OFFSET];

      currentPreset.value = preset;
      selectedPreset.value = preset;
      // mListener.onGetPreset(preset);
    }
  }

  Speaker getSpeakerType(int value) {
    switch (value) {
      case 0x00:
        return Speaker.MASTER_SPEAKER;
      case 0x01:
        return Speaker.SLAVE_SPEAKER;
      case 0x02:
      default:
        throw ArgumentError('Invalid speaker value');
    }
  }

  void receiveGetChannelACK(GaiaPacketBLE packet) {
    const int PAYLOAD_LENGTH = 3;
    const int SPEAKER_OFFSET = 1;
    const int CHANNEL_OFFSET = 2;

    List<int>? payload = packet.getPayload();

    if (payload != null && payload.length >= PAYLOAD_LENGTH) {
      int speaker = payload[SPEAKER_OFFSET];
      int channel = payload[CHANNEL_OFFSET];

      // mListener.onGetChannel(getSpeakerType(speaker), getChannelType(channel));
    }
  }

  Channel getChannelType(int value) {
    switch (value) {
      case 0x01:
        return Channel.LEFT;
      case 0x03:
        return Channel.MONO;
      case 0x02:
        return Channel.RIGHT;
      case 0x00:
        return Channel.STEREO;
      default:
        throw ArgumentError('Invalid channel value');
    }
  }

  void receiveGetVolumeACK(GaiaPacketBLE packet) {
    const int PAYLOAD_LENGTH = 3;
    const int SPEAKER_OFFSET = 1;
    const int VOLUME_OFFSET = 2;
    const int MAX_VOLUME = 100; // Assuming MAX_VOLUME is defined somewhere

    List<int>? payload = packet.getPayload();

    if (payload != null && payload.length >= PAYLOAD_LENGTH) {
      int speaker = payload[SPEAKER_OFFSET];
      int volume = payload[VOLUME_OFFSET];
      volume = volume > MAX_VOLUME ? MAX_VOLUME : (volume < 0 ? 0 : volume);

      // mListener.onGetVolume(getSpeakerType(speaker), volume);
    }
  }

  void receiveUnsuccessfulAcknowledgement(GaiaPacketBLE packet) {
    // Fluttertoast.showToast(
    //   msg:
    //       "Command sending failed ${StringUtils.intTo2HexString(packet.getCommand())}",
    //   toastLength: Toast.LENGTH_SHORT,
    //   gravity: ToastGravity.BOTTOM,
    //   timeInSecForIosWeb: 1,
    //   backgroundColor: Colors.red,
    //   textColor: Colors.white,
    //   fontSize: 16.0,
    // );

    if (controllEqualizer) {
      controllEqualizerError.value = true;

      Fluttertoast.showToast(
        msg: "Please stream some music to use this feature.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }

    final command = packet.getCommand();
    if (packet.getStatus() == GAIA.NOT_SUPPORTED) {
      switch (command) {
        case GAIA.COMMAND_VM_UPGRADE_DISCONNECT:
          break;
        case GAIA.COMMAND_GET_EQ_PARAMETER:
          Fluttertoast.showToast(
            msg: "Control ENHANCEMENT_3D is not supported",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          break;

        case GAIA.COMMAND_GET_USER_EQ_CONTROL:
        case GAIA.COMMAND_SET_USER_EQ_CONTROL:
        case GAIA.COMMAND_GET_EQ_CONTROL:
        case GAIA.COMMAND_SET_EQ_CONTROL:
          Fluttertoast.showToast(
            msg: "Control PRESETS is not supported",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          break;
        case GAIA.COMMAND_GET_3D_ENHANCEMENT_CONTROL:
        case GAIA.COMMAND_SET_3D_ENHANCEMENT_CONTROL:
          Fluttertoast.showToast(
            msg: "Control ENHANCEMENT_3D is not supported",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );

          break;
        case GAIA.COMMAND_GET_BASS_BOOST_CONTROL:
        case GAIA.COMMAND_SET_BASS_BOOST_CONTROL:
          Fluttertoast.showToast(
            msg: "Control BASS_BOOST is not supported",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );

          break;
      }
    }

    completeSendingRequest(command);

    addLog(
        "Command sending failed ${StringUtils.intTo2HexString(packet.getCommand())}");

    // sendUpgradeDisconnect();
    if (packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_CONNECT ||
        packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_CONTROL) {
      // sendSyncReq();
      if (transferComplete) {
        return;
      }

      sendUpgradeDisconnect();

      Fluttertoast.showToast(
        msg: "Upgrade failed. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } else if (packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_DISCONNECT) {
    } else if (packet.getCommand() == GAIA.COMMAND_SET_DATA_ENDPOINT_MODE ||
        packet.getCommand() == GAIA.COMMAND_GET_DATA_ENDPOINT_MODE) {
      mIsRWCPEnabled.value = false;
      onRWCPNotSupported();
    }
  }

  void startUpgradeProcess() {
    if (!isUpgrading.value || transferComplete) {
      isUpgrading.value = true;
      resetUpload();
      sendSyncReq();
    } else if (isUpgrading.value) {
      stopUpgrade();
      // addLog("Upgrading");
    }
    // else {
    //   stopUpgrade();
    //   // mBytesFile == null
    //   addLog("Upgrade file does not exist");
    // }
  }

  /**
   * <p>To reset the file transfer.</p>
   */
  void resetUpload() {
    mStartAttempts = 0;
    mBytesToSend = 0;
    mStartOffset = 0;
  }

  Future<void> stopUpgrade() async {
    _timer?.cancel();
    // _isUpgradeStart = false;
    // _isUpgradeComplete = false;
    isUpgrading.value = false;
    timeCount.value = 0;
    transferComplete = false;
    hasToAbort = true;
    abortUpgrade();
    resetUpload();
    writeRTCPCount = 0;
    updatePer.value = 0;
    upgradeComplete.value = false;

    // flutterReactiveBle.deinitialize()
    // await Future.delayed(const Duration(milliseconds: 500));
    sendUpgradeDisconnect();
    // await Future.delayed(const Duration(milliseconds: 1000));
    // connectDevice(connectDeviceId);
  }

  void sendSyncReq() async {
    // A2305C3A9059C15171BD33F3BB08ADE4 MD5
    // 000A0642130004BB08ADE4
    // final filePath = await getApplicationDocumentsDirectory();
    // final saveBinPath = filePath.path + "/1.bin";
    // File file = File(saveBinPath);

    if (_selectedFile.isEmpty) {
      return;
    }

    mBytesFile = await File(_selectedFile).readAsBytes();
    fileMd5 = StringUtils.file2md5(mBytesFile ?? []).toUpperCase();
    addLog("Read file MD5: $fileMd5");
    final endMd5 = StringUtils.hexStringToBytes(fileMd5.substring(24));
    VMUPacket packet = VMUPacket.get(OpCodes.UPGRADE_SYNC_REQ, data: endMd5);
    sendVMUPacket(packet, false);
  }

  /// <p>To send a VMUPacket over the defined protocol communication.</p>
  ///
  /// @param bytes
  ///              The packet to send.
  /// @param isTransferringData
  ///              True if the packet is about transferring the file data, false for any other packet.
  void sendVMUPacket(VMUPacket packet, bool isTransferringData) {
    List<int> bytes = packet.getBytes();
    if (isTransferringData && mIsRWCPEnabled.value) {
      final packet =
          GaiaPacketBLE(GAIA.COMMAND_VM_UPGRADE_CONTROL, mPayload: bytes);
      try {
        List<int> bytes = packet.getBytes();
        if (mTransferStartTime <= 0) {
          mTransferStartTime = DateTime.now().millisecond;
        }
        bool success = mRWCPClient.sendData(bytes);
        if (!success) {
          Fluttertoast.showToast(
            msg:
                "Fail to send GAIA packet for GAIA command: ${packet.getCommandId()}",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          addLog(
              "Fail to send GAIA packet for GAIA command: ${packet.getCommandId()}");
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Exception when attempting to create GAIA packet: $e",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        addLog("Exception when attempting to create GAIA packet: $e");
      }
    } else {
      final pkg =
          GaiaPacketBLE(GAIA.COMMAND_VM_UPGRADE_CONTROL, mPayload: bytes);
      writeMsg(pkg.getBytes());
    }
  }

  void receiveVMUPacket(List<int> data) {
    try {
      final packet = VMUPacket.getPackageFromByte(data);
      if (isUpgrading.value || packet?.mOpCode == OpCodes.UPGRADE_ABORT_CFM) {
        handleVMUPacket(packet);
      } else {
        // isUpgrading.value = true;
        // stopUpgrade();
        // handleVMUPacket(packet);
        addLog(
            "receiveVMUPacket Received VMU packet while application is not upgrading anymore, opcode received");
      }
    } catch (e) {
      addLog("receiveVMUPacket $e");
    }
  }

  void handleVMUPacket(VMUPacket? packet) {
    switch (packet?.mOpCode) {
      case OpCodes.UPGRADE_SYNC_CFM:
        receiveSyncCFM(packet);
        break;
      case OpCodes.UPGRADE_START_CFM:
        receiveStartCFM(packet);
        break;
      case OpCodes.UPGRADE_DATA_BYTES_REQ:
        receiveDataBytesREQ(packet);
        break;
      case OpCodes.UPGRADE_ABORT_CFM:
        receiveAbortCFM();
        break;
      case OpCodes.UPGRADE_ERROR_WARN_IND:
        receiveErrorWarnIND(packet);
        break;
      case OpCodes.UPGRADE_IS_VALIDATION_DONE_CFM:
        receiveValidationDoneCFM(packet);
        break;
      case OpCodes.UPGRADE_TRANSFER_COMPLETE_IND:
        receiveTransferCompleteIND();
        break;
      case OpCodes.UPGRADE_COMMIT_REQ:
        receiveCommitREQ();
        break;
      case OpCodes.UPGRADE_COMPLETE_IND:
        receiveCompleteIND();
        break;
    }
  }

  void sendUpgradeConnect() async {
    GaiaPacketBLE packet = GaiaPacketBLE(GAIA.COMMAND_VM_UPGRADE_CONNECT);
    writeMsg(packet.getBytes());
  }

  void cancelNotification() async {
    GaiaPacketBLE packet = GaiaPacketBLE.buildGaiaNotificationPacket(
        GAIA.COMMAND_CANCEL_NOTIFICATION, GAIA.VMU_PACKET, null, GAIA.BLE);
    writeMsg(packet.getBytes());
  }

  // bool _haveSendUpgradeDisconnected = false;
  void sendUpgradeDisconnect() {
    // if (_haveSendUpgradeDisconnected) {
    //   return;
    // }
    // _haveSendUpgradeDisconnected = true;
    GaiaPacketBLE packet = GaiaPacketBLE(GAIA.COMMAND_VM_UPGRADE_DISCONNECT);
    writeMsg(packet.getBytes());
  }

  void receiveSyncCFM(VMUPacket? packet) {
    List<int> data = packet?.mData ?? [];
    if (data.length >= 6) {
      int step = data[0];
      addLog("Last transmission step $step");
      _rwcpStartTimer = Timer(const Duration(seconds: 5), () {
        hasToRestartUpgrade = true;
        // sendUpgradeConnect();
        sendAbortReq();
      });

      if (step == ResumePoints.IN_PROGRESS) {
        setResumePoint(step);
      } else {
        mResumePoint = step;
      }
    } else {
      mResumePoint = ResumePoints.DATA_TRANSFER;
    }
    sendStartReq();
  }

  /**
   * To send an UPGRADE_START_REQ message.
   */
  void sendStartReq() {
    VMUPacket packet = VMUPacket.get(OpCodes.UPGRADE_START_REQ);
    sendVMUPacket(packet, false);
  }

  void receiveStartCFM(VMUPacket? packet) {
    List<int> data = packet?.mData ?? [];
    if (data.length >= 3) {
      if (data[0] == UpgradeStartCFMStatus.SUCCESS) {
        mStartAttempts = 0;
        // the device is ready for the upgrade, we can go to the resume point or to the upgrade beginning.
        switch (mResumePoint) {
          case ResumePoints.COMMIT:
            askForConfirmation(ConfirmationType.COMMIT);
            break;
          case ResumePoints.TRANSFER_COMPLETE:
            askForConfirmation(ConfirmationType.TRANSFER_COMPLETE);
            break;
          case ResumePoints.IN_PROGRESS:
            askForConfirmation(ConfirmationType.IN_PROGRESS);
            break;
          case ResumePoints.VALIDATION:
            sendValidationDoneReq();
            break;
          case ResumePoints.DATA_TRANSFER:
          default:
            sendStartDataReq();
            break;
        }
      }
    }
  }

  void receiveAbortCFM() {
    addLog("receiveAbortCFM");
    if (_isReceiveCommit) {
      // sendUpgradeConnect();
      connectDevice(connectDeviceId);
      return;
    }

    stopUpgrade();
  }

  void receiveErrorWarnIND(VMUPacket? packet) async {
    List<int> data = packet?.mData ?? [];
    sendErrorConfirmation(data); //
    int returnCode = StringUtils.extractIntFromByteArray(data, 0, 2, false);
    // A2305C3A9059C15171BD33F3BB08ADE4
    addLog(
        "receiveErrorWarnIND upgrade failed error code 0x${returnCode.toRadixString(16)} fileMd5:$fileMd5");
    //noinspection IfCanBeSwitch
    if (returnCode == 0x81) {
      addLog("Package not approved");
      Fluttertoast.showToast(
        msg: "Package not approved",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      askForConfirmation(ConfirmationType.WARNING_FILE_IS_DIFFERENT);
    } else if (returnCode == 0x21) {
      addLog("Battery too low");
      Fluttertoast.showToast(
        msg: "Battery too low",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      askForConfirmation(ConfirmationType.BATTERY_LOW_ON_DEVICE);
    } else {
      Fluttertoast.showToast(
        msg: "Failed to upgrade. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      stopUpgrade();
    }
  }

  void receiveValidationDoneCFM(VMUPacket? packet) {
    addLog("receiveValidationDoneCFM");
    List<int> data = packet?.getBytes() ?? [];
    if (data.length == 2) {
      final time = StringUtils.extractIntFromByteArray(data, 0, 2, false);
      Future.delayed(Duration(milliseconds: time))
          .then((value) => sendValidationDoneReq());
    } else {
      sendValidationDoneReq();
    }
  }

  void receiveTransferCompleteIND() {
    addLog("receiveTransferCompleteIND");
    transferComplete = true;
    setResumePoint(ResumePoints.TRANSFER_COMPLETE);
    askForConfirmation(ConfirmationType.TRANSFER_COMPLETE);
  }

  bool _isReceiveCommit = false;

  void receiveCommitREQ() {
    _isReceiveCommit = true;
    addLog("receiveCommitREQ");
    setResumePoint(ResumePoints.COMMIT);
    askForConfirmation(ConfirmationType.COMMIT);
  }

  void receiveCompleteIND() {
    addLog("receiveCompleteIND upgrade complete");
    Fluttertoast.showToast(
      msg: "Upgrade successful",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );

    updatePer.value = 0;
    isUpgrading.value = false;
    upgradeComplete.value = true;
    _isReceiveCommit = false;
    disconnectUpgrade();
  }

  void sendValidationDoneReq() {
    VMUPacket packet = VMUPacket.get(OpCodes.UPGRADE_IS_VALIDATION_DONE_REQ);
    sendVMUPacket(packet, false);
  }

  void sendStartDataReq() {
    setResumePoint(ResumePoints.DATA_TRANSFER);
    VMUPacket packet = VMUPacket.get(OpCodes.UPGRADE_START_DATA_REQ);
    sendVMUPacket(packet, false);
  }

  void setResumePoint(int point) {
    mResumePoint = point;
  }

  void receiveDataBytesREQ(VMUPacket? packet) {
    List<int> data = packet?.mData ?? [];

    // Checking the data has the correct length
    if (data.length == OpCodes.DATA_LENGTH) {
      // Retrieving information from the received packet
      // REC 120300080000002400000000
      // SEND 000A064204000D0000030000FFFF0001FFFF0002
      final lengthByte = [data[0], data[1], data[2], data[3]];
      final fileByte = [data[4], data[5], data[6], data[7]];
      mBytesToSend =
          int.parse(StringUtils.byteToHexString(lengthByte), radix: 16);
      int fileOffset =
          int.parse(StringUtils.byteToHexString(fileByte), radix: 16);

      addLog(
          "${StringUtils.byteToHexString(data)}This packet: $fileOffset $mBytesToSend");
      // We check the value for the offset
      mStartOffset += (fileOffset > 0 &&
              fileOffset + mStartOffset < (mBytesFile?.length ?? 0))
          ? fileOffset
          : 0;

      // If the requested length doesn't fit with possibilities, we use the maximum length we can use.
      mBytesToSend = (mBytesToSend > 0) ? mBytesToSend : 0;
      // If the requested length will look for bytes out of the array, we reduce it to the remaining length.
      int remainingLength = mBytesFile?.length ?? 0 - mStartOffset;
      mBytesToSend =
          (mBytesToSend < remainingLength) ? mBytesToSend : remainingLength;

      if (mIsRWCPEnabled.value) {
        while (mBytesToSend > 0) {
          sendNextDataPacket();
        }
      } else {
        addLog("P: sendNextDataPacket");
        sendNextDataPacket();
      }
      // addLog("P: sendNextDataPacket");
      // sendNextDataPacket();
    } else {
      Fluttertoast.showToast(
        msg: "UpgradeError Data transfer failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      addLog("UpgradeError Data transfer failed");
      abortUpgrade();
    }
  }

  void abortUpgrade() {
    isUpgrading.value = false;
    if (mRWCPClient.isRunningASession()) {
      mRWCPClient.cancelTransfer();
    }
    _progressQueue.clear();
    sendAbortReq();
  }

  void sendAbortReq() {
    if (!isUpgrading.value) {
      return;
    }
    VMUPacket packet = VMUPacket.get(OpCodes.UPGRADE_ABORT_REQ);
    sendVMUPacket(packet, false);
  }

  // Main packet sending logic
  void sendNextDataPacket() {
    if (!isUpgrading.value) {
      stopUpgrade();
      return;
    }
    // Inform listeners about progress
    onFileUploadProgress();
    int bytesToSend = mBytesToSend < mMaxLengthForDataTransfer - 1
        ? mBytesToSend
        : mMaxLengthForDataTransfer - 1;
    // To know if we are sending the last data packet.
    bool lastPacket = (mBytesFile ?? []).length - mStartOffset <= bytesToSend;
    if (lastPacket) {
      addLog(
          "mMaxLengthForDataTransfer$mMaxLengthForDataTransfer bytesToSend$bytesToSend lastPacket$lastPacket");
    }
    List<int> dataToSend = [];
    for (int i = 0; i < bytesToSend; i++) {
      dataToSend.add((mBytesFile ?? [])[mStartOffset + i]);
    }

    if (lastPacket) {
      wasLastPacket = true;
      mBytesToSend = 0;
    } else {
      mStartOffset += bytesToSend;
      mBytesToSend -= bytesToSend;
    }

    sendData(lastPacket, dataToSend);
  }

  final int NUMBER_OF_PRESETS = 7;

  void setPreset(int preset) {
    if (preset >= 0 && preset < NUMBER_OF_PRESETS) {
      const int PAYLOAD_LENGTH = 1;
      const int PRESET_OFFSET = 0;
      Uint8List payload = Uint8List(PAYLOAD_LENGTH);
      payload[PRESET_OFFSET] = preset;
      // createRequest(createPacket(GAIA_COMMAND_SET_EQ_CONTROL, payload));

      final pkg = GaiaPacketBLE(GAIA.COMMAND_SET_EQ_CONTROL, mPayload: payload);
      const controlType = GAIA.COMMAND_SET_EQ_CONTROL;

      writeMsg(pkg.getBytes());

      mapCompleterRequest[controlType] = Completer();

      if (!mapSendingRequest.containsKey(controlType)) {
        mapSendingRequest[controlType] = true.obs;
      } else {
        mapSendingRequest[controlType]?.value = true;
      }

      mapTimeOutRequest[controlType]?.cancel();

      mapTimeOutRequest[controlType] = Timer(const Duration(seconds: 5), () {
        mapSendingRequest[controlType]?.value = false;
        mapCompleterRequest[controlType]?.complete();
      });

      registerSendingRequest();
    } else {
      print(
          '$TAG: setPreset used with parameter not between 0 and ${NUMBER_OF_PRESETS - 1}, value: $preset');
    }
  }

  void getPreset() {
    final pkg = GaiaPacketBLE(GAIA.COMMAND_GET_EQ_CONTROL);
    writeMsg(pkg.getBytes());
  }

  // void getActivationState(Controls control) {}
  void getActivationState(EqualizerControls control) async {
    int controlType = -1;
    late GaiaPacketBLE packetBLE;
    switch (control) {
      case EqualizerControls.BASS_BOOST:
        controlType = GAIA.COMMAND_GET_BASS_BOOST_CONTROL;
        // packetBLE = GaiaPacketBLE(GAIA.COMMAND_GET_BASS_BOOST_CONTROL);

        break;
      case EqualizerControls.ENHANCEMENT_3D:
        controlType = GAIA.COMMAND_GET_3D_ENHANCEMENT_CONTROL;
        // packetBLE = GaiaPacketBLE(GAIA.COMMAND_GET_3D_ENHANCEMENT_CONTROL);

        break;
      case EqualizerControls.PRESETS:
        controlType = GAIA.COMMAND_GET_USER_EQ_CONTROL;
        // packetBLE = GaiaPacketBLE(GAIA.COMMAND_GET_USER_EQ_CONTROL);

        break;
    }

    isSendingRequest.value = true;

    if (mapCompleterRequest[controlType]?.isCompleted == false) {
      await mapCompleterRequest[controlType]?.future;
    }

    mapCompleterRequest[controlType] = Completer();

    packetBLE = GaiaPacketBLE(controlType);

    if (!mapSendingRequest.containsKey(controlType)) {
      mapSendingRequest[controlType] = true.obs;
    } else {
      mapSendingRequest[controlType]?.value = true;
    }

    mapTimeOutRequest[controlType]?.cancel();

    mapTimeOutRequest[controlType] = Timer(const Duration(seconds: 5), () {
      mapSendingRequest[controlType]?.value = false;
      mapCompleterRequest[controlType]?.complete();
    });

    registerSendingRequest();

    writeMsg(packetBLE.getBytes());
  }

  /// To represent the boolean value `true` as a payload of one parameter for GAIA commands.
  final Uint8List PAYLOAD_BOOLEAN_TRUE = Uint8List.fromList([0x01]);

  /// To represent the boolean value `false` as a payload of one parameter for GAIA commands.
  final Uint8List PAYLOAD_BOOLEAN_FALSE = Uint8List.fromList([0x00]);

  void getVolume(Speaker speaker) {
    const int PAYLOAD_LENGTH = 1;
    const int SPEAKER_OFFSET = 0;
    Uint8List payload = Uint8List(PAYLOAD_LENGTH);
    payload[SPEAKER_OFFSET] = speaker.value;
    final packetBLE =
        GaiaPacketBLE(GAIA.COMMAND_GET_TWS_VOLUME, mPayload: payload);

    writeMsg(packetBLE.getBytes());
  }

  void getChannel(Speaker speaker) {
    const int PAYLOAD_LENGTH = 1;
    const int SPEAKER_OFFSET = 0;
    Uint8List payload = Uint8List(PAYLOAD_LENGTH);
    payload[SPEAKER_OFFSET] = speaker.value;
    final packetBLE =
        GaiaPacketBLE(GAIA.COMMAND_GET_TWS_AUDIO_ROUTING, mPayload: payload);

    writeMsg(packetBLE.getBytes());
  }

  void setVolume(Speaker speaker, int volume) {
    volume = volume < 0 ? 0 : (volume > MAX_VOLUME ? MAX_VOLUME : volume);
    const int PAYLOAD_LENGTH = 2;
    const int SPEAKER_OFFSET = 0;
    const int VOLUME_OFFSET = 1;
    Uint8List payload = Uint8List(PAYLOAD_LENGTH);
    payload[SPEAKER_OFFSET] = speaker.value;
    payload[VOLUME_OFFSET] = volume;
    final packetBLE =
        GaiaPacketBLE(GAIA.COMMAND_SET_TWS_VOLUME, mPayload: payload);

    writeMsg(packetBLE.getBytes());
  }

  void setActivationState(EqualizerControls control, bool activate) async {
    // We build the payload
    Uint8List payload = activate ? PAYLOAD_BOOLEAN_TRUE : PAYLOAD_BOOLEAN_FALSE;
    late GaiaPacketBLE packetBLE;
    int controlType = -1;

    // We do the request
    switch (control) {
      case EqualizerControls.BASS_BOOST:
        controlType = GAIA.COMMAND_SET_BASS_BOOST_CONTROL;

        break;
      case EqualizerControls.ENHANCEMENT_3D:
        controlType = GAIA.COMMAND_SET_3D_ENHANCEMENT_CONTROL;
        // packetBLE = GaiaPacketBLE(GAIA.COMMAND_SET_3D_ENHANCEMENT_CONTROL,
        //     mPayload: payload);

        break;
      case EqualizerControls.PRESETS:
        controlType = GAIA.COMMAND_SET_USER_EQ_CONTROL;
        // packetBLE =
        //     GaiaPacketBLE(GAIA.COMMAND_SET_USER_EQ_CONTROL, mPayload: payload);
        break;
    }

    isSendingRequest.value = true;

    if (mapCompleterRequest[controlType]?.isCompleted == false) {
      await mapCompleterRequest[controlType]?.future;
    }

    packetBLE = GaiaPacketBLE(controlType, mPayload: payload);
    mapCompleterRequest[controlType] = Completer();

    if (!mapSendingRequest.containsKey(controlType)) {
      mapSendingRequest[controlType] = true.obs;
    } else {
      mapSendingRequest[controlType]?.value = true;
    }

    mapTimeOutRequest[controlType]?.cancel();

    mapTimeOutRequest[controlType] = Timer(const Duration(seconds: 5), () {
      mapSendingRequest[controlType]?.value = false;
      mapCompleterRequest[controlType]?.complete();
    });

    registerSendingRequest();

    writeMsg(packetBLE.getBytes());
  }

  final isSendingRequest = false.obs;

  StreamSubscription<bool>? _subscribeSendingRequest;

  void registerSendingRequest() {
    final sendingRequestStreamList =
        mapSendingRequest.values.map((e) => e.subject.stream).toList();

    // Combine the streams
    Stream<bool> mergedStream =
        Rx.combineLatest(sendingRequestStreamList, (List<bool> values) {
      final isSending = values.any((element) => element);
      // if (isSending) {}
      if (isSending) {
        isSendingRequest.value = true;
      } else {
        isSendingRequest.value = false;
      }
      return isSending;
    });

    bool isAnyTrue = false;

    /// Loop through the map and check if any of the value is true
    for (final entry in mapSendingRequest.entries) {
      if (entry.value.value == false) {
        continue;
      }
      isAnyTrue = true;
      break;
    }

    if (isAnyTrue) {
      isSendingRequest.value = true;
    } else {
      isSendingRequest.value = false;
    }

    _subscribeSendingRequest?.cancel();

    _subscribeSendingRequest = mergedStream.listen((value) {
      isSendingRequest.value = value;
    });
  }

  // Calculate progress
  void onFileUploadProgress() {
    double percentage = (mStartOffset * 100.0 / (mBytesFile ?? []).length);
    percentage = (percentage < 0)
        ? 0
        : (percentage > 100)
            ? 100
            : percentage;
    if (mIsRWCPEnabled.value) {
      _progressQueue.add(percentage);
    } else {
      updatePer.value = percentage;
    }
  }

  void sendData(bool lastPacket, List<int> data) {
    List<int> dataToSend = [];
    dataToSend.add(lastPacket ? 0x01 : 0x00);
    dataToSend.addAll(data);
    sendPkgCount++;
    VMUPacket packet = VMUPacket.get(OpCodes.UPGRADE_DATA, data: dataToSend);
    sendVMUPacket(packet, true);
  }

  void onSuccessfulTransmission() {
    if (wasLastPacket) {
      if (mResumePoint == ResumePoints.DATA_TRANSFER) {
        wasLastPacket = false;
        setResumePoint(ResumePoints.VALIDATION);
        sendValidationDoneReq();
      }
    } else if (hasToAbort) {
      hasToAbort = false;
      abortUpgrade();
    } else {
      if (mBytesToSend > 0 &&
          mResumePoint == ResumePoints.DATA_TRANSFER &&
          !mIsRWCPEnabled.value) {
        // _isUpgradeStart = true;
        sendNextDataPacket();
      }
    }
  }

  void onRWCPNotSupported() {
    addLog("RWCP onRWCPNotSupported");
  }

  Future<void> askForConfirmation(int type) async {
    int code = -1;
    switch (type) {
      case ConfirmationType.COMMIT:
        {
          code = OpCodes.UPGRADE_COMMIT_CFM;

          // Future.delayed(
          //   const Duration(seconds: 5),
          // ).then((value) => stopUpgrade());
        }
        break;
      case ConfirmationType.IN_PROGRESS:
        {
          code = OpCodes.UPGRADE_IN_PROGRESS_RES;
        }
        break;
      case ConfirmationType.TRANSFER_COMPLETE:
        {
          code = OpCodes.UPGRADE_TRANSFER_COMPLETE_RES;
        }
        break;
      case ConfirmationType.BATTERY_LOW_ON_DEVICE:
        {
          sendSyncReq();
        }
        return;
      case ConfirmationType.WARNING_FILE_IS_DIFFERENT:
        {
          hasToRestartUpgrade = true;
          ();
          // stopUpgrade();
        }
        return;
    }

    await Future.delayed(const Duration(seconds: 1));
    addLog("askForConfirmation ConfirmationType type $type $code");
    VMUPacket packet = VMUPacket.get(code, data: [0]);
    sendVMUPacket(packet, false);
  }

  void sendErrorConfirmation(List<int> data) {
    VMUPacket packet =
        VMUPacket.get(OpCodes.UPGRADE_ERROR_WARN_RES, data: data);
    sendVMUPacket(packet, false);
  }

  void disconnectUpgrade() {
    cancelNotification();
    sendUpgradeDisconnect();
  }

  @override
  void onTransferFailed() {
    abortUpgrade();
  }

  @override
  void onTransferFinished() {
    onSuccessfulTransmission();
    _progressQueue.clear();
  }

  @override
  void onTransferProgress(int acknowledged) {
    if (acknowledged > 0) {
      double percentage = 0;
      while (acknowledged > 0 && _progressQueue.isNotEmpty) {
        percentage = _progressQueue.removeFirst();
        acknowledged--;
      }
      if (mIsRWCPEnabled.value) {
        updatePer.value = percentage;
      }
      // addLog("$mIsRWCPEnabled upgrade progress $percentage");
    }
  }

  @override
  bool sendRWCPSegment(List<int> bytes) {
    writeMsgRWCP(bytes);
    return true;
  }

  // General command write channel
  Future<void> writeData(List<int> data) async {
    addLog(
        "${DateTime.now()} wenDataWrite start>${StringUtils.byteToHexString(data)}");
    await Future.delayed(const Duration(milliseconds: 200));
    final characteristic = QualifiedCharacteristic(
        serviceId: otaUUID,
        characteristicId: writeUUID,
        deviceId: connectDeviceId);
    try {
      await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
          value: data);
    } catch (e) {
      addLog("writeData error $e");

      Fluttertoast.showToast(
        msg: "writeData error $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // if (isUpgrading.value) {
      //   stopUpgrade();
      // }
    }

    addLog(
        "${DateTime.now()} wenDataWrite end>${StringUtils.byteToHexString(data)}");
  }

  // RWCP write channel
  void writeMsgRWCP(List<int> data) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final characteristic = QualifiedCharacteristic(
        serviceId: otaUUID,
        characteristicId: writeNoResUUID,
        deviceId: connectDeviceId);
    await flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic,
        value: data);
  }

  Future<void> disconnect() async {
    await _connection?.cancel();
    await _subscribeConnection?.cancel();
    await _subscribeConnectionRWCP?.cancel();
  }

  Future<void> restPayloadSize() async {
    int mtu = await flutterReactiveBle.requestMtu(
        deviceId: connectDeviceId, mtu: 512);
    if (!mIsRWCPEnabled.value) {
      mtu = 23;
    }

    // mtu = 256;
    int dataSize = mtu - 3;
    mPayloadSizeMax = dataSize - 4;
    addLog("Negotiated mtu $mtu mPayloadSizeMax $mPayloadSizeMax");
  }

  void addLog(String s) {
    debugPrint("wenTest $s");
    logText.value += "$s\n";
    if (logText.value.length > 10000) {
      logText.value = logText.value.substring(10000);
    }
  }

  void startScan() async {
    await disconnect();
    devices.clear();
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      var location = await Permission.location.status;
      var bluetooth = await Permission.bluetooth.status;
      var bluetoothScan = await Permission.bluetoothScan.status;
      var bluetoothConnect = await Permission.bluetoothConnect.status;
      if (location.isDenied) {
        addLog("location deny");
        return;
      }
      if (bluetoothScan.isDenied) {
        return;
      }
      if (bluetoothConnect.isDenied) {
        addLog("bluetoothConnect deny");
        return;
      }
    } else {
      await Permission.bluetoothConnect.request();
      await Permission.bluetoothScan.request();

      var bluetooth = await Permission.bluetooth.status;
      if (bluetooth.isDenied) {
        // await Permission.bluetooth.request();
        addLog("bluetooth deny");
        return;
      }
    }
    try {
      await _scanConnection?.cancel();
      await _connection?.cancel();
    } catch (e) {}
    // Start scannin
    _scanConnection = flutterReactiveBle.scanForDevices(
        withServices: [],
        // scanMode: ScanMode.lowLatency,
        requireLocationServicesEnabled: true).listen((device) {
      if (connectDeviceId == device.id &&
          isUpgrading.value &&
          _disconnectWhenUpgrading) {
        _disconnectWhenUpgrading = false;
        connectDevice(device.id);
      }

      if (device.name.isNotEmpty) {
        final knownDeviceIndex = devices.indexWhere((d) => d.id == device.id);
        if (knownDeviceIndex >= 0) {
          devices[knownDeviceIndex] = device;
        } else {
          devices.add(device);
        }
      }
      //code for handling results
    });
  }
}
