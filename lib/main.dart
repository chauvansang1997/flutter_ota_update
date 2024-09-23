import 'package:flutter/material.dart';
import 'package:flutter_gaia/TestOtaView.dart';
import 'package:flutter_gaia/pages/equalizer_page.dart';
import 'package:get/get.dart';

import 'controlller/OtaServer.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter GAIA Control Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    Get.put<OtaServer>(OtaServer());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              MaterialButton(
                color: Colors.blue,
                onPressed: () {
                  OtaServer.to.startScan();
                },
                child: const Text('Scan Bluetooth'),
              ),
              const SizedBox(height: 30),
              Expanded(child: Obx(() {
                return ListView.builder(
                  itemBuilder: (context, index) {
                    var device = OtaServer.to.devices[index];

                    final connectedDevices = OtaServer.to.connectedDevices;

                    final isConnected =
                        connectedDevices.any((element) => element == device.id);

                    return GestureDetector(
                      onTap: () {
                        OtaServer.to.connectDevice(device.id);
                        Get.to(() => const TestOtaView());
                      },
                      child: Container(
                        margin: const EdgeInsets.only(
                          left: 10,
                          right: 10,
                          bottom: 5,
                        ),
                        padding:
                            const EdgeInsets.only(top: 8, bottom: 8, left: 20),
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.white,
                          // color: Colors.white,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device.name,
                                      style: const TextStyle(
                                          color: Color(0xff373F50),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    device.id,
                                    style: const TextStyle(
                                      color: Color(0xff373F50),
                                      fontSize: 12,
                                    ),
                                  )
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (String result) {
                                switch (result) {
                                  case 'equalizer_device':
                                    OtaServer.to.requestEqualizer();
                                    OtaServer.to.connectDevice(device.id);
                                    Get.to(() => const EqualizerPage());
                                    break;
                                  case 'upgrade':
                                    OtaServer.to.connectDevice(device.id);
                                    Get.to(() => const TestOtaView());
                                    break;
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'equalizer_device',
                                  child: Text('Equalizer Device'),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'upgrade',
                                  child: Text('Upgrade Device'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  itemCount: OtaServer.to.devices.length,
                );
              }))
            ],
          ),
          Obx(() {
            return OtaServer.to.isConnecting.value
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
}
