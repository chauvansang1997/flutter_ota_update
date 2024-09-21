import 'package:flutter/material.dart';
import 'package:flutter_gaia/controlller/OtaServer.dart';
import 'package:flutter_gaia/pages/custom_equalizer_page.dart';
import 'package:flutter_gaia/utils/gaia/equalizer_controls.dart';
import 'package:flutter_gaia/utils/gaia/remote_controls.dart';
import 'package:get/get.dart';
import 'package:volume_controller/volume_controller.dart';

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  double _volume = 0;

  @override
  void initState() {
    VolumeController().listener((volume) {
      setState(() => _volume = volume);
    });

    VolumeController().getVolume().then((volume) => _volume = volume);

    super.initState();
  }

  @override
  void dispose() {
    VolumeController().removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Equalizer Control Demo"),
        ),
        body: Obx(() {
          return Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  MaterialButton(
                    color: Colors.blue,
                    onPressed: () async {
                      // if (isEnabled) {
                      //   return;
                      // }

                      OtaServer.to
                          .getActivationState(EqualizerControls.BASS_BOOST);
                      OtaServer.to
                          .getActivationState(EqualizerControls.ENHANCEMENT_3D);
                      OtaServer.to
                          .getActivationState(EqualizerControls.PRESETS);
                      // OtaServer.to.startUpdate(_selectedFile);
                    },
                    child: const Text('Request Equalizer'),
                  ),
                  // Text('Current volume: $_volume'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Set Volume:'),
                            Flexible(
                              child: Slider(
                                min: 0,
                                max: 1,
                                onChanged: (double value) {
                                  _volume = value;
                                  VolumeController().setVolume(_volume);
                                  setState(() {});
                                },
                                value: _volume,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to.sendControlCommand(
                                    RemoteControls.VOLUME_UP);
                              },
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                              ),
                            ),
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to.sendControlCommand(
                                    RemoteControls.VOLUME_DOWN);
                              },
                              child: const Icon(
                                Icons.remove,
                                color: Colors.white,
                              ),
                            ),
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to
                                    .sendControlCommand(RemoteControls.PLAY);
                              },
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to
                                    .sendControlCommand(RemoteControls.STOP);
                              },
                              child: const Icon(
                                Icons.stop,
                                color: Colors.white,
                              ),
                            ),
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to
                                    .sendControlCommand(RemoteControls.PAUSE);
                              },
                              child: const Icon(
                                Icons.pause,
                                color: Colors.white,
                              ),
                            ),
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to
                                    .sendControlCommand(RemoteControls.MUTE);
                              },
                              child: const Icon(
                                Icons.volume_off,
                                color: Colors.white,
                              ),
                            ),
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to
                                    .sendControlCommand(RemoteControls.FORWARD);
                              },
                              child: const Icon(
                                Icons.forward,
                                color: Colors.white,
                              ),
                            ),
                            MaterialButton(
                              shape: const CircleBorder(),
                              color: Colors.blue,
                              onPressed: () async {
                                OtaServer.to
                                    .sendControlCommand(RemoteControls.REWIND);
                              },
                              child: Transform.rotate(
                                angle:
                                    3.14, // Rotate by 180 degrees (in radians)
                                child: const Icon(
                                  Icons.forward,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _GeneralSettingsWidget(),
                  ),
                  // if (OtaServer.to.presets.value)
                  //   Obx(() {
                  //     return Expanded(
                  //       child: GridView.builder(
                  //         gridDelegate:
                  //             const SliverGridDelegateWithFixedCrossAxisCount(
                  //           crossAxisCount: 2, // Number of columns
                  //           crossAxisSpacing: 10.0, // Space between columns
                  //           mainAxisSpacing: 10.0, // Space between rows
                  //           childAspectRatio: 1.0, // Aspect ratio of the child
                  //         ),
                  //         itemCount: 7,
                  //         itemBuilder: (context, index) {
                  //           return _BankItem(
                  //             title: 'Bank $index',
                  //             isSelected:
                  //                 OtaServer.to.selectedPreset.value == index,
                  //             onSelect: () {
                  //               OtaServer.to.selectedPreset.value = index;
                  //               OtaServer.to.setPreset(index);
                  //               // OtaServer.to.setEqualizerBank(index);
                  //             },
                  //           );
                  //         },
                  //       ),
                  //     );
                  //   }),
                  if (OtaServer.to.presets.value)
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, // Number of columns
                          crossAxisSpacing: 10.0, // Space between columns
                          mainAxisSpacing: 10.0, // Space between rows
                          childAspectRatio: 1.0, // Aspect ratio of the child
                        ),
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          return Obx(() {
                            return _BankItem(
                              title: 'Bank $index',
                              isSelected:
                                  OtaServer.to.selectedPreset.value == index,
                              onSelect: () {
                                OtaServer.to.selectedPreset.value = index;
                                OtaServer.to.setPreset(index);
                                // OtaServer.to.setEqualizerBank(index);
                              },
                            );
                          });

                          // return _BankItem(
                          //   title: 'Bank $index',
                          //   isSelected: OtaServer.to.selectedPreset.value == index,
                          //   onSelect: () {
                          //     OtaServer.to.selectedPreset.value = index;
                          //     OtaServer.to.setPreset(index);
                          //     // OtaServer.to.setEqualizerBank(index);
                          //   },
                          // );
                        },
                      ),
                    ),
                  if (OtaServer.to.presets.value)
                    MaterialButton(
                      color: Colors.blue,
                      onPressed: () async {
                        OtaServer.to.startConfigure();

                        // Future.delayed(const Duration(seconds: 2), () {
                        //   Get.to(() => const CustomEqualizerPage());
                        // });
                        Get.to(() => const CustomEqualizerPage());
                      },
                      child: const Text('Configure Equalizer'),
                    )

                  // if (OtaServer.to.presets.value)
                ],
              ),
              Obx(() {
                return OtaServer.to.isConnecting.value ||
                        !OtaServer.to.isRegisterNotification.value ||
                        OtaServer.to.isSendingRequest.value
                    ? const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const SizedBox();
              }),
            ],
          );
        }));
  }
}

class _BankItem extends StatelessWidget {
  _BankItem({
    required this.title,
    this.isSelected = false,
    this.onSelect,
  });
  final String title;
  final bool isSelected;
  final Function()? onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.blue : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onSelect,
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralSettingsWidget extends StatelessWidget {
  const _GeneralSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('General Settings'),
          Row(
            children: [
              const Text('Bass boost'),
              Switch(
                value: OtaServer.to.bassBoost.value,
                onChanged: (value) {
                  OtaServer.to.bassBoost.value = value;

                  OtaServer.to
                      .setActivationState(EqualizerControls.BASS_BOOST, value);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text('Enhancement 3D'),
              Switch(
                value: OtaServer.to.enhancement3D.value,
                onChanged: (value) {
                  OtaServer.to.enhancement3D.value = value;
                  OtaServer.to.setActivationState(
                      EqualizerControls.ENHANCEMENT_3D, value);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text('Presets'),
              Switch(
                value: OtaServer.to.presets.value,
                onChanged: (value) {
                  OtaServer.to.presets.value = value;

                  OtaServer.to
                      .setActivationState(EqualizerControls.PRESETS, value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
