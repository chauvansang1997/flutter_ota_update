import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gaia/utils/file_utils.dart';
import 'package:get/get.dart';
import '../../../../utils/StringUtils.dart';
import 'controlller/OtaServer.dart';

class TestOtaView extends StatefulWidget {
  const TestOtaView({Key? key}) : super(key: key);

  @override
  State<TestOtaView> createState() => _TestOtaState();
}

class _TestOtaState extends State<TestOtaView> {
  var isDownloading = false;
  var progress = 0;
  var savePath = "";
  String _selectedFile = '';

  @override
  void initState() {
    OtaServer.to.upgradeComplete.listen((event) {
      if (event) {
        OtaServer.to.logText.value = "Upgrade complete\n";

        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GAIA Control Demo"),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              MaterialButton(
                color: Colors.blue,
                onPressed: () async {
                  // if (isEnabled) {
                  //   return;
                  // }
                  OtaServer.to.connectDevice(OtaServer.to.connectDeviceId);

                  // OtaServer.to.startUpdate(_selectedFile);
                },
                child: const Text('Reconnected'),
              ),

              Obx(() {
                final version = OtaServer.to.deviceVersion.value;
                return Text('Device api version: $version');
              }),
              // Obx(() {
              //   // final isEnabled = OtaServer.to.isRegisterNotification.value;
              //   return MaterialButton(
              //     color: Colors.blue,
              //     onPressed: () async {
              //       // if (isEnabled) {
              //       //   return;
              //       // }
              //       OtaServer.to.connectDevice(OtaServer.to.connectDeviceId);

              //       // OtaServer.to.startUpdate(_selectedFile);
              //     },
              //     child: const Text('Reconnected'),
              //   );
              // }),
              MaterialButton(
                color: Colors.blue,
                onPressed: () async {
                  final filePath = await _askedToLead(context);

                  if (filePath == null) {
                    return;
                  }

                  setState(() {
                    _selectedFile = filePath;
                  });
                },
                child: const Text('Select file'),
              ),
              if (_selectedFile.isNotEmpty)
                Text('Selected file: $_selectedFile'),
              // MaterialButton(
              //   color: Colors.blue,
              //   onPressed: () {
              //     _download();
              //   },
              //   child: Text(
              //       "Download bin\n${!isDownloading ? "Path: $savePath" : 'Downloading ($progress)\nPath: $savePath'}"),
              // ),
              Row(
                children: [
                  const Text('RWCP'),
                  Obx(() {
                    bool rwcp = OtaServer.to.mIsRWCPEnabled.value;
                    return Checkbox(
                        value: rwcp,
                        onChanged: (on) async {
                          OtaServer.to.mIsRWCPEnabled.value = on ?? false;
                          await OtaServer.to.restPayloadSize();
                          await Future.delayed(const Duration(seconds: 1));
                          if (OtaServer.to.mIsRWCPEnabled.value) {
                            OtaServer.to.registerRWCP();
                          } else {
                            OtaServer.to.writeMsg(
                                StringUtils.hexStringToBytes("000A022E00"));
                          }
                        });
                  }),
                  Expanded(
                    child: MaterialButton(
                        color: Colors.blue,
                        onPressed: () {
                          OtaServer.to.logText.value = "";
                        },
                        child: const Text('Clear LOG')),
                  ),
                ],
              ),
              Obx(() {
                final per = OtaServer.to.updatePer.value;
                return Row(
                  children: [
                    Expanded(
                        child: Slider(
                            value: per,
                            onChanged: (data) {},
                            max: 100,
                            min: 0)),
                    SizedBox(
                        width: 60, child: Text('${per.toStringAsFixed(2)}%'))
                  ],
                );
              }),
              Obx(() {
                final time = OtaServer.to.timeCount.value;

                final isEnabled = _selectedFile.isNotEmpty;
                // final isEnabled = OtaServer.to.isRegisterNotification.value &&
                //     _selectedFile.isNotEmpty;
                return MaterialButton(
                  color: isEnabled ? Colors.blue : Colors.grey,
                  onPressed: () async {
                    if (!isEnabled) {
                      return;
                    }
                    // if (OtaServer.to.mIsRWCPEnabled.value) {
                    //   await OtaServer.to.restPayloadSize();
                    //   await Future.delayed(const Duration(seconds: 1));
                    //   OtaServer.to
                    //       .writeMsg(StringUtils.hexStringToBytes("000A022E01"));
                    // } else {
                    //   // await OtaServer.to.restPayloadSize();
                    // }
                    OtaServer.to.startUpdate(_selectedFile);

                    // OtaServer.to.startUpdate(_selectedFile);
                  },
                  child: Text('Start upgrade $time'),
                );
              }),

              Obx(() {
                final isUpgrading = OtaServer.to.isUpgrading.value;
                // final isUpgrading = OtaServer.to.isUpgrading;
                if (!isUpgrading) return const SizedBox();
                return MaterialButton(
                  color: Colors.blue,
                  onPressed: () {
                    OtaServer.to.stopUpgrade();
                  },
                  child: const Text('Cancel upgrade'),
                );
              }),

              Expanded(child: Obx(() {
                final log = OtaServer.to.logText.value;
                return SingleChildScrollView(
                    child: Text(
                  log,
                  style: const TextStyle(fontSize: 10),
                ));
              }))
            ],
          ),
          Obx(() {
            return OtaServer.to.isConnecting.value ||
                    !OtaServer.to.isRegisterNotification.value ||
                    (!OtaServer.to.isRWCPRegisterNotification.value &&
                        OtaServer.to.mIsRWCPEnabled.value)
                ? const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox();
          })
        ],
      ),
    );
  }

  Future<String?> _askedToLead(BuildContext context) async {
    return await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Select assignment'),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () async {
                  final file = await FileUtils.getFileFromAsset(
                      "resources/ECW02_OTA.bin");

                  Navigator.pop(context, file.path);
                },
                child: const Text('ECW02_OTA.bin'),
              ),
              SimpleDialogOption(
                onPressed: () async {
                  final file = await FileUtils.getFileFromAsset(
                    "resources/MT500_OTA.bin",
                  );
                  Navigator.pop(context, file.path);
                  // AppNavigate.pop(result: file.path);
                },
                child: const Text('MT500_OTA.bin'),
              ),
              SimpleDialogOption(
                onPressed: () async {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles(
                    allowMultiple: false,
                    type: FileType.custom,
                    allowedExtensions: ['bin'],
                  );

                  if (result != null) {
                    List<String?> files =
                        result.paths.map((path) => path).toList();
                    if (files.isNotEmpty && files.first!.contains('.bin')) {
                      // AppNavigate.pop(result: files.first);
                      Navigator.pop(context, files.first);
                    } else {
                      // DialogHelper.showError(
                      //   title: LocaleKeys.error.tr(),
                      //   content:
                      //       'Firmware is not found. Please pick a different files.',
                      // );
                    }
                  }
                },
                child: const Text('Pick file'),
              ),
            ],
          );
        });
  }

  @override
  void dispose() {
    super.dispose();
    OtaServer.to.disconnect();
  }

  // Future<void> writeAssetToFile(String assetPath, String fileName) async {
  //   try {
  //     // Load the asset
  //     final byteData = await rootBundle.load(assetPath);

  //     // Get the application documents directory
  //     final directory = await getApplicationDocumentsDirectory();
  //     final filePath = '${directory.path}/$fileName';

  //     // Write the file
  //     final file = File(filePath);
  //     await file.writeAsBytes(byteData.buffer.asUint8List());

  //     print('File written to $filePath');
  //   } catch (e) {
  //     print('Error writing file: $e');
  //   }
  // }

  // void _download() async {
  //   // if (isDownloading) return;
  //   // var url = "https://file.mymei.tv/test/1.bin";
  //   //url = "https://file.mymei.tv/test/M2_20221230_DEMO.bin";

  //   final filePath = await getApplicationDocumentsDirectory();
  //   final saveBinPath = filePath.path + "/1.bin";

  //   writeAssetToFile("assets/resources/MT500_OTA.bin", "1.bin");
  //   setState(() {
  //     savePath = saveBinPath;
  //   });
  //   // await HttpUtil().download(url, savePath: saveBinPath,
  //   //     onReceiveProgress: (int count, int total) {
  //   //   setState(() {
  //   //     isDownloading = true;
  //   //     progress = count * 100.0 ~/ total;
  //   //   });
  //   // });
  //   setState(() {
  //     isDownloading = false;
  //   });
  // }
}
