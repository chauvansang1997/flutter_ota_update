import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../utils/gaia/ConfirmationType.dart';
import '../../../utils/gaia/GAIA.dart';
import '../../../utils/gaia/GaiaPacketBLE.dart';
import '../../../utils/gaia/OpCodes.dart';
import '../../../utils/gaia/ResumePoints.dart';
import '../../../utils/gaia/UpgradeStartCFMStatus.dart';
import '../../../utils/gaia/VMUPacket.dart';
import '../../../utils/gaia/rwcp/RWCPClient.dart';
import '../TestOtaView.dart';
import '../utils/StringUtils.dart';
import '../utils/gaia/rwcp/RWCPListener.dart';

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

  String connectDeviceId = "";
  Uuid otaUUID = Uuid.parse("00001100-d102-11e1-9b23-00025b00a5a5");
  Uuid notifyUUID = Uuid.parse("00001102-d102-11e1-9b23-00025b00a5a5");
  Uuid writeUUID = Uuid.parse("00001101-d102-11e1-9b23-00025b00a5a5");
  Uuid writeNoResUUID = Uuid.parse("00001103-d102-11e1-9b23-00025b00a5a5");
  StreamSubscription<ConnectionStateUpdate>? _connection;
  String _selectedFile = '';
  /**
   * To know if the upgrade process is currently running.
   */
  final isUpgrading = false.obs;

  bool transFerComplete = false;

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

  bool _isUpgradeComplete = false;
  bool _isUpgradeStart = false;

  int mBytesToSend = 0;

  int mResumePoint = -1;
  bool _disconnectWhenUpgrading = false;
  var mIsRWCPEnabled = false.obs;
  int sendPkgCount = 0;

  RxDouble updatePer = RxDouble(0);

  /**
   * To know if we have to disconnect after any event which occurs as a fatal error from the board.
   */
  bool hasToAbort = false;

  final writeQueue = Queue<List<int>>();

  StreamSubscription<List<int>>? _subscribeConnection;

  StreamSubscription<List<int>>? _subscribeConnectionRWCP;

  String fileMd5 = "";

  var percentage = 0.0.obs;

  Timer? _timer;

  var timeCount = 0.obs;

  //RWCP
  ListQueue<double> mProgressQueue = ListQueue();

  late RWCPClient mRWCPClient;

  int mTransferStartTime = 0;

  int writeRTCPCount = 0;

  int maxRetry = 5;

  File? file;

  static OtaServer get to => Get.find();

  @override
  void onInit() {
    super.onInit();
    mRWCPClient = RWCPClient(this);
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
      if (isRetry && connectingDeviceId == id) {
        _retryCount++;
      }

      if (isRetry && connectingDeviceId == id && _retryCount > maxRetry) {
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

            if (!isUpgrading.value) {
              Get.to(() => const TestOtaView());
            }

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
              _disconnectWhenUpgrading = true;
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
    scheduleMicrotask(() async {
      await writeData(data);
    });
  }

  void registerRWCP() async {
    await _subscribeConnectionRWCP?.cancel();
    //IOS BUG
    await flutterReactiveBle.discoverAllServices(connectDeviceId);
    await Future.delayed(const Duration(seconds: 1));
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
      // code to handle incoming data
    }, onError: (dynamic error) {
      // code to handle errors

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

    addLog("isUpgrading: $isUpgrading transFerComplete: $transFerComplete");
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
      print(error);
      // code to handle errors
    });

    await Future.delayed(const Duration(seconds: 1));
    GaiaPacketBLE packet = GaiaPacketBLE.buildGaiaNotificationPacket(
        GAIA.COMMAND_REGISTER_NOTIFICATION, GAIA.VMU_PACKET, null, GAIA.BLE);
    writeMsg(packet.getBytes());
    // If RWCP is enabled, re-enable it after reconnecting
    // if (isUpgrading.value && transFerComplete && mIsRWCPEnabled.value) {
    //   // Enable RWCP
    //   await Future.delayed(const Duration(seconds: 1));
    //   writeMsg(StringUtils.hexStringToBytes("000A022E01"));
    // }

    if (mIsRWCPEnabled.value) {
      // Enable RWCP
      await Future.delayed(const Duration(seconds: 1));
      writeMsg(StringUtils.hexStringToBytes("000A022E01"));
    }
  }

  // bool _cancelPreviousUpgrade = false;

  void startUpdate(String filePath) async {
    await stopUpgrade();
    _isUpgradeStart = false;
    _selectedFile = filePath;
    logText.value = "";
    // writeBytes.clear();
    writeRTCPCount = 0;
    mProgressQueue.clear();
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
          // not supported
          return;
        }
      } else {
        createAcknowledgmentRequest(packet, 5);
        await Future.delayed(const Duration(milliseconds: 1000));
        return;
      }
    }
  }

  void receiveSuccessfulAcknowledgement(GaiaPacketBLE packet) {
    // addLog(
    //     "receiveSuccessfulAcknowledgement ${StringUtils.intTo2HexString(packet.getCommand())}");
    // print(GAIA.COMMAND_VM_UPGRADE_CONNECT.toString() +
    //     " " +
    // packet.getCommand().toString());
    switch (packet.getCommand()) {
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

          isRegisterNotification.value = true;
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
        // if (!_isUpgradeComplete) {
        //   connectDevice(connectDeviceId);
        //   return;
        // }

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
        break;
      case GAIA.COMMAND_VM_UPGRADE_CONTROL:
        onSuccessfulTransmission();
        break;
      case GAIA.COMMAND_SET_DATA_ENDPOINT_MODE:
        if (mIsRWCPEnabled.value) {
          registerRWCP();
        } else {
          _subscribeConnectionRWCP?.cancel();
        }
        break;
      case GAIA.COMMAND_GET_DATA_ENDPOINT_MODE:
        print(packet.getCommand());
        break;
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
    final command = packet.getCommand();
    if (packet.getStatus() == GAIA.NOT_SUPPORTED) {
      print(packet.getStatus());
      switch (command) {
        case GAIA.COMMAND_VM_UPGRADE_DISCONNECT:
          break;
      }
    }

    addLog(
        "Command sending failed ${StringUtils.intTo2HexString(packet.getCommand())}");
    if (packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_CONTROL) {
      print('GAIA.COMMAND_VM_UPGRADE_CONTROL');
    }

    if (packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_CONNECT) {
      print('GAIA.COMMAND_VM_UPGRADE_CONTROL');
      sendUpgradeDisconnect();
    }

    // sendUpgradeDisconnect();
    if (packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_CONNECT ||
        packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_CONTROL) {
      // sendUpgradeDisconnect();
    } else if (packet.getCommand() == GAIA.COMMAND_VM_UPGRADE_DISCONNECT) {
    } else if (packet.getCommand() == GAIA.COMMAND_SET_DATA_ENDPOINT_MODE ||
        packet.getCommand() == GAIA.COMMAND_GET_DATA_ENDPOINT_MODE) {
      mIsRWCPEnabled.value = false;
      onRWCPNotSupported();
    }
  }

  void startUpgradeProcess() {
    if (!isUpgrading.value) {
      isUpgrading.value = true;
      resetUpload();
      sendSyncReq();
    } else if (isUpgrading.value) {
      stopUpgrade();
      addLog("Upgrading");
    } else {
      stopUpgrade();
      // mBytesFile == null
      addLog("Upgrade file does not exist");
    }
  }

  /**
   * <p>To reset the file transfer.</p>
   */
  void resetUpload() {
    transFerComplete = false;
    mStartAttempts = 0;
    mBytesToSend = 0;
    mStartOffset = 0;
  }

  Future<void> stopUpgrade() async {
    _timer?.cancel();
    _isUpgradeStart = false;
    _isUpgradeComplete = false;
    timeCount.value = 0;
    // hasToAbort = true;
    abortUpgrade();
    resetUpload();
    writeRTCPCount = 0;
    updatePer.value = 0;
    isUpgrading.value = false;
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
      if (isUpgrading.value || packet!.mOpCode == OpCodes.UPGRADE_ABORT_CFM) {
        handleVMUPacket(packet);
      } else {
        addLog(
            "receiveVMUPacket Received VMU packet while application is not upgrading anymore, opcode received");
      }
    } catch (e) {
      addLog("receiveVMUPacket $e");
    }
  }

  ///Create response packet.
  void createAcknowledgmentRequest(GaiaPacketBLE packet, int status) {
    // writeMsg(StringUtils.hexStringToBytes("000AC00300"));
    final bytes = packet.getAcknowledgementPacketBytes(status, null);
    // writeMsg(StringUtils.hexStringToBytes("000AC00300"));
    writeMsg(bytes);
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

  void sendUpgradeDisconnect() {
    GaiaPacketBLE packet = GaiaPacketBLE(GAIA.COMMAND_VM_UPGRADE_DISCONNECT);
    writeMsg(packet.getBytes());
  }

  void receiveSyncCFM(VMUPacket? packet) {
    List<int> data = packet?.mData ?? [];
    if (data.length >= 6) {
      int step = data[0];
      addLog("Last transmission step $step");
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
    stopUpgrade();
  }

  void receiveErrorWarnIND(VMUPacket? packet) async {
    List<int> data = packet?.mData ?? [];
    sendErrorConfirmation(data); //
    int returnCode = StringUtils.extractIntFromByteArray(data, 0, 2, false);
    // A2305C3A9059C15171BD33F3BB08ADE4
    addLog(
        "receiveErrorWarnIND upgrade failed error code 0x${returnCode.toRadixString(16)} fileMd5$fileMd5");
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
    transFerComplete = true;
    setResumePoint(ResumePoints.TRANSFER_COMPLETE);
    askForConfirmation(ConfirmationType.TRANSFER_COMPLETE);
  }

  void receiveCommitREQ() {
    addLog("receiveCommitREQ");
    setResumePoint(ResumePoints.COMMIT);
    askForConfirmation(ConfirmationType.COMMIT);
  }

  void receiveCompleteIND() {
    isUpgrading.value = false;
    addLog("receiveCompleteIND upgrade complete");
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
    if (mRWCPClient.isRunningASession()) {
      mRWCPClient.cancelTransfer();
    }
    mProgressQueue.clear();
    sendAbortReq();
    isUpgrading.value = false;
  }

  void sendAbortReq() {
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

  // Calculate progress
  void onFileUploadProgress() {
    double percentage = (mStartOffset * 100.0 / (mBytesFile ?? []).length);
    percentage = (percentage < 0)
        ? 0
        : (percentage > 100)
            ? 100
            : percentage;
    if (mIsRWCPEnabled.value) {
      mProgressQueue.add(percentage);
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
        _isUpgradeStart = true;
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

          Fluttertoast.showToast(
            msg: "Upgrade successful",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );

          Future.delayed(
            const Duration(seconds: 5),
          ).then((value) => stopUpgrade());
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
          stopUpgrade();
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
    mProgressQueue.clear();
  }

  @override
  void onTransferProgress(int acknowledged) {
    if (acknowledged > 0) {
      double percentage = 0;
      while (acknowledged > 0 && mProgressQueue.isNotEmpty) {
        percentage = mProgressQueue.removeFirst();
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
    await Future.delayed(const Duration(milliseconds: 100));
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
