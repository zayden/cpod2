import 'dart:async';
import 'dart:io';
import 'utils.dart';
import 'widget/chart_widget.dart';
import 'widget/temp_widget.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'ble_view_model.dart';
import 'dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:filesaverz/filesaverz.dart';
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Uuid uartUuid = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  final Uuid uartRxUuid = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
  final Uuid uartTxUuid = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
  final _temp1Controller = TextEditingController();
  final _temp2Controller = TextEditingController();
  final _time1Controller = TextEditingController();
  final _time2Controller = TextEditingController();
  var selectedDeviceIndex = -1;
  final focusNodeCutoff = FocusNode();

  // FileSaver fileSaver = FileSaver(
  //   initialFileName: 'Save File',
  //   fileTypes: const ['csv'],
  // );
  final _famCutoffController = TextEditingController();
  final _roxCutoffController = TextEditingController();
  List<int> famList = [];
  List<int> roxList = [];
  List<int> famList1 = [];
  List<int> roxList1 = [];
  List<FlSpot> famLineList = [const FlSpot(0, 0)];
  List<FlSpot> roxLineList = [const FlSpot(0, 0)];
  int famResult = 3;
  int roxResult = 3;
  int maxX = 0;
  int maxY = 60000;
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late StreamSubscription<ConnectionStateUpdate> _connection;
  late QualifiedCharacteristic _txCharacteristic;
  late QualifiedCharacteristic _rxCharacteristic;
  late BleViewModel bleProvider;
  int temp1 = 0;
  int temp2 = 0;
  int time1 = 0;
  int time2 = 0;
  int cutoffFam = 100;
  int cutoffRox = 100;
  var remainingTime1 = 2;
  var remainingTime2 = 5;
  int state = 0;
  var temp = 0.0;
  Timer? timer;
  bool famShow = true;
  bool roxShow = true;
  bool isDRnShow = false;
  bool enDRnShow = false;

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    bleProvider = Provider.of<BleViewModel>(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 0, 8),
          child: Image(
            image: AssetImage('images/logo.png'),
          ),
        ),
        title: const Text(
          "CPod Software",
          style: TextStyle(
            fontSize: 21,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: IconButton(
                icon: Icon(bleProvider.connectionStatus ==
                        MyConnectionState.disconnected
                    ? Icons.bluetooth_disabled
                    : bleProvider.connectionStatus ==
                            MyConnectionState.connected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_searching),
                onPressed: () {
                  if (bleProvider.connectionStatus ==
                      MyConnectionState.disconnected) {
                    scanBle();
                    bleConnectDialog(context);
                  } else {
                    disconnectDialog();
                  }
                },
              )),
          Center(
              child:
                  bleProvider.connectionStatus == MyConnectionState.connected &&
                          (state == 0 || state == 3)
                      ? Text(
                          '${(temp / 100.0).toStringAsFixed(2)}℃',
                          style: const TextStyle(
                            fontFamily: 'CourierPrime',
                          ),
                        )
                      : const Text('')),
          _popupMenuButton(context),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                TempWidget(
                  title: 'LYSIS',
                  disabled: bleProvider.connectionStatus ==
                          MyConnectionState.connected
                      ? false
                      : true,
                  realTimeTemp: temp,
                  remainingTime: remainingTime1,
                  temp: temp1,
                  time: time1,
                  onOff: state == 1 ? true : false,
                  onToggle: (bool value) async {
                    if (value == true) {
                      await sendString('{"cmd":"start1"}');
                    } else {
                      stopTempDialog(1);
                    }
                  },
                ),
                const Padding(padding: EdgeInsets.only(left: 30)),
                TempWidget(
                  title: 'CRISPR',
                  disabled: bleProvider.connectionStatus ==
                          MyConnectionState.connected
                      ? false
                      : true,
                  realTimeTemp: temp,
                  remainingTime: remainingTime2,
                  temp: temp2,
                  time: time2,
                  onOff: state == 2 ? true : false,
                  onToggle: (bool value) async {
                    if (value == true) {
                      famList.clear();
                      roxList.clear();
                      famList1.clear();
                      roxList1.clear();
                      famLineList.clear();
                      famLineList.add(const FlSpot(0, 0));
                      roxLineList.clear();
                      roxLineList.add(const FlSpot(0, 0));
                      enDRnShow = false;
                      isDRnShow = false;
                      maxX = 0;
                      maxY = 60000;
                      famResult = 3;
                      roxResult = 3;
                      setState(() {});
                      await sendString('{"cmd":"start2"}');
                    } else {
                      stopTempDialog(2);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0x00808080),
                      width: 2,
                    ),
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.grey,
                          offset: Offset(0, 0),
                          blurRadius: 8)
                    ]),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(5, 5, 5, 5),
                      child: Text("Real-time Fluorescence Curve",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 5, 20, 0),
                      child: SizedBox(
                        width: 340,
                        height: MediaQuery.of(context).size.height/3-30,
                        child: ChartWidget(
                          famLineList: famLineList,
                          famCutoff: cutoffFam,
                          roxCutoff: cutoffRox,
                          roxLineList: roxLineList,
                          isShowFam: famShow,
                          isShowRox: roxShow,
                          isShowCutoff: isDRnShow,
                          maxX: maxX,
                          maxY: maxY,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 5, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                  width: 100,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'DRn/Rn',
                                        style: TextStyle(
                                            color: enDRnShow
                                                ? Colors.black
                                                : Colors.grey),
                                      ),
                                      IconButton(
                                          onPressed: enDRnShow
                                              ? () {
                                                  isDRnShow = !isDRnShow;
                                                  famLineList.clear();
                                                  roxLineList.clear();
                                                  if (isDRnShow) {
                                                    for (int i = 0;
                                                        i < famList1.length;
                                                        i++) {
                                                      famLineList.add(FlSpot(
                                                          i + 1.0,
                                                          famList1[i]
                                                              .toDouble()));
                                                      roxLineList.add(FlSpot(
                                                          i + 1.0,
                                                          roxList1[i]
                                                              .toDouble()));
                                                    }
                                                  } else {
                                                    for (int i = 0;
                                                        i < famList.length;
                                                        i++) {
                                                      famLineList.add(FlSpot(
                                                          i + 1.0,
                                                          famList[i]
                                                              .toDouble()));
                                                      roxLineList.add(FlSpot(
                                                          i + 1.0,
                                                          roxList[i]
                                                              .toDouble()));
                                                    }
                                                  }
                                                  setCoordinate();
                                                }
                                              : null,
                                          icon: Icon(isDRnShow
                                              ? Icons.check_circle_outline
                                              : Icons.circle_outlined)),
                                    ],
                                  )),
                              const SizedBox(
                                  width: 100,
                                  child: Center(child: Text('Fam'))),
                              const SizedBox(
                                  width: 100,
                                  child: Center(child: Text('Rox'))),
                            ],
                          ),
                          // const Padding(padding: EdgeInsets.all(5)),
                          Row(
                            children: [
                              const SizedBox(
                                  width: 100,
                                  child: Center(child: Text('Curve Show'))),
                              SizedBox(
                                width: 100,
                                child: FlutterSwitch(
                                  width: 70,
                                  height: 30,
                                  padding:1,
                                  value: famShow,
                                  showOnOff: true,
                                  onToggle: (bool value) {
                                    setState(() {
                                      famShow = value;
                                      setCoordinate();
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                  width: 100,
                                  child: FlutterSwitch(
                                    width: 70,
                                    height: 30,
                                    padding:1,
                                    value: roxShow,
                                    showOnOff: true,
                                    onToggle: (bool value) {
                                      setState(() {
                                        roxShow = value;
                                        setCoordinate();
                                      });
                                    },
                                  )),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.all(5)),
                          Row(
                            children: [
                              const SizedBox(
                                  width: 100,
                                  child: Center(child: Text('CutOff'))),
                              SizedBox(
                                  width: 100,
                                  child: Center(child: Text('$cutoffFam'))),
                              SizedBox(
                                  width: 100,
                                  child: Center(child: Text('$cutoffRox'))),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: const Color(0x00808080),
                    width: 2,
                  ),
                  color: Colors.white,
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.grey, offset: Offset(0, 0), blurRadius: 8)
                  ]),
              child: Column(
                children: [
                  SizedBox(

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(30, 10, 0, 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Text('Fam: ',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: famResult == 0
                                          ? Colors.green
                                          : famResult == 1
                                              ? Colors.red
                                              : Colors.grey,
                                    ),
                                    child: const SizedBox(
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(padding: EdgeInsets.all(5)),
                              Row(
                                children: [
                                  const Text('Rox:  ',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: roxResult == 0
                                          ? Colors.green
                                          : roxResult == 1
                                              ? Colors.red
                                              : Colors.grey,
                                    ),
                                    child: const SizedBox(
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(100, 10, 0, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                    ),
                                    child: const SizedBox(
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                  const Text('  Positive',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Padding(padding: EdgeInsets.all(5)),
                              Row(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                    ),
                                    child: const SizedBox(
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                  const Text('  Negative',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Padding(padding: EdgeInsets.all(5)),
                              Row(
                                children: [
                                  Container(
                                    decoration:
                                        const BoxDecoration(color: Colors.grey),
                                    child: const SizedBox(
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                  const Text('  Unknown',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuButton _popupMenuButton(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(
        Icons.more_vert,
        size: 45,
      ),
      itemBuilder: (BuildContext context) {
        if (bleProvider.connectionStatus == MyConnectionState.connected) {
          return [
            const PopupMenuItem(
              value: 'export',
              child: Text('export'),
            ),
            const PopupMenuItem(
              value: 'config',
              child: Text('config'),
            ),
            const PopupMenuItem(
              value: 'adc',
              child: Text('adc'),
            ),
          ];
        } else {
          return [
            const PopupMenuItem(
              value: 'export',
              child: Text('export'),
            ),
            const PopupMenuItem(
              value: "import",
              child: Text('import'),
            ),
            const PopupMenuItem(
              value: 'clean',
              child: Text('clean'),
            ),
          ];
        }
      },
      onSelected: (object) async {
        if (object == 'export') {
          print(famList);
          if (famList.isNotEmpty) {
            String csv = const ListToCsvConverter().convert([
              [...famList],
              [...roxList],
              [...famList1],
              [...roxList1],
            ]);
            final dir = await getExternalStorageDirectory();
            List<FileSystemEntity> filesSystemEntity = [];
            final fileList = Directory(dir!.path).list();
            await for (FileSystemEntity fileSystemEntity in fileList) {
              filesSystemEntity.add(fileSystemEntity);
            }
            if (context.mounted) {
              await saveDialog(context, dir, filesSystemEntity, csv);
            }
          }
        } else if (object == 'import') {
          final dir = await getExternalStorageDirectory();
          List<FileSystemEntity> filesSystemEntity = [];
          final fileList = Directory(dir!.path).list();
          await for (FileSystemEntity fileSystemEntity in fileList) {
            filesSystemEntity.add(fileSystemEntity);
          }
          if (context.mounted) {
            final str = await openDialog(context, dir, filesSystemEntity);
            List<String> listStr = str.split('\r\n');
            famList = listStr[0].split(',').map((e) => int.parse(e)).toList();
            roxList = listStr[1].split(',').map((e) => int.parse(e)).toList();
            famList1 = listStr[2].split(',').map((e) => int.parse(e)).toList();
            roxList1 = listStr[3].split(',').map((e) => int.parse(e)).toList();
            famLineList.clear();
            roxLineList.clear();
            for (int i = 0; i < famList.length; i++) {
              famLineList.add(FlSpot(i + 1.0, famList1[i].toDouble()));
              roxLineList.add(FlSpot(i + 1.0, roxList1[i].toDouble()));
            }
            dataAnalysis();
            enDRnShow = true;
            isDRnShow = true;
            setCoordinate();
          }
        } else if (object == 'config') {
          configDialog(context);
        } else if (object == 'adc') {
          await sendString('{"cmd":"getAdc"}');
          var response =
              await flutterReactiveBle.readCharacteristic(_txCharacteristic);
          var json = String.fromCharCodes(response);
          var data = jsonDecode(json);
          if (context.mounted) {
            adcDialog(
                context,
                data['famAGain'],
                data['roxAGain'],
                data['famATime'],
                data['roxATime'],
                data['famAStep'],
                data['roxAStep']);
          }
        } else if (object == 'clean') {
          famList.clear();
          roxList.clear();
          famList1.clear();
          roxList1.clear();
          famLineList.clear();
          famLineList.add(const FlSpot(0, 0));
          roxLineList.clear();
          roxLineList.add(const FlSpot(0, 0));
          enDRnShow = false;
          isDRnShow = false;
          maxX = 0;
          maxY = 60000;
          famResult = 3;
          roxResult = 3;
          setState(() {});
        }
      },
    );
  }

  Future<dynamic> bleConnectDialog(BuildContext context) {
    late BleViewModel bleProvider;
    return showDialog(
        context: context,
        builder: (context) {
          bleProvider = Provider.of<BleViewModel>(context);
          return StatefulBuilder(builder: (context, setState) {
            return SimpleDialog(
              title: const Text('connection device'),
              children: <Widget>[
                Column(
                  children: [
                    SizedBox(
                      height: 300,
                      width: 300,
                      child: ListView(
                        children: [
                          ...bleProvider.devices.asMap().entries.map((entry) =>
                              Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0x00808080),
                                        width: 2,
                                      ),
                                      color: Colors.white,
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.grey,
                                            offset: Offset(0, 0),
                                            blurRadius: 4)
                                      ]),
                                  child: ListTile(
                                    title: Text(entry.value.name),
                                    subtitle: Text(entry.value.id),
                                    trailing: Radio(
                                      value: entry.key,
                                      groupValue: selectedDeviceIndex,
                                      onChanged: (value) {},
                                    ),
                                    onTap: () {
                                      setState(() {
                                        selectedDeviceIndex = entry.key;
                                      });
                                    },
                                  )))
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              _scanStream.cancel();
                              if (selectedDeviceIndex >= 0 &&
                                  selectedDeviceIndex <
                                      bleProvider.devices.length) {
                                flutterReactiveBle
                                    .requestMtu(
                                        deviceId: bleProvider
                                            .devices[selectedDeviceIndex].id,
                                        mtu: 512)
                                    .then((value) {
                                });
                                bleProvider.updateConnectionStatus(
                                    MyConnectionState.connecting);
                                _connection = flutterReactiveBle
                                    .connectToDevice(
                                        id: bleProvider
                                            .devices[selectedDeviceIndex].id)
                                    .listen((event) async {
                                  if (event.connectionState ==
                                      DeviceConnectionState.connected) {
                                    _rxCharacteristic = QualifiedCharacteristic(
                                        serviceId: uartUuid,
                                        characteristicId: uartRxUuid,
                                        deviceId: event.deviceId);
                                    bleProvider.updateConnectionStatus(
                                        MyConnectionState.connected);
                                    _txCharacteristic = QualifiedCharacteristic(
                                        serviceId: uartUuid,
                                        characteristicId: uartTxUuid,
                                        deviceId: event.deviceId);
                                    getDeviceState();
                                  } else if (event.connectionState ==
                                          DeviceConnectionState.disconnecting ||
                                      event.connectionState ==
                                          DeviceConnectionState.disconnected) {
                                    state = 0;
                                    bleProvider.updateConnectionStatus(
                                        MyConnectionState.disconnected);
                                    timer?.cancel();
                                  }
                                });
                              }
                              Navigator.of(context).pop(true);
                            },
                            child: const Text('Yes')),
                        ElevatedButton(
                            onPressed: () {
                              _scanStream.cancel();
                              Navigator.of(context).pop();
                            },
                            child: const Text('No')),
                      ],
                    ),
                  ],
                ),
              ],
            );
          });
        });
  }

  getDeviceState() async {
    await sendString('{"cmd":"state"}');
    famResult = 3;
    roxResult = 3;
    var response =
        await flutterReactiveBle.readCharacteristic(_txCharacteristic);
    var json = String.fromCharCodes(response);
    print('response=$json');
    var data = jsonDecode(json);
    getState(data);
    famLineList.clear();
    roxLineList.clear();
    famLineList.add(const FlSpot(0, 0));
    roxLineList.add(const FlSpot(0, 0));
    enDRnShow = false;
    isDRnShow = false;
    if (data['state'] == 2) {
      if (data['lIndex'] != 0) {
        await getAllLightData(data['lIndex']);
      }
    } else if (data['state'] == 3) {
      await getAllLightData(data['lIndex']);
      enDRnShow = true;
    }
    setState(() {});
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await sendString('{"cmd":"state"}');
      var response =
          await flutterReactiveBle.readCharacteristic(_txCharacteristic);
      var json = String.fromCharCodes(response);
      var data = jsonDecode(json);
      getState(data);
      int index = data['lIndex'];
      enDRnShow = false;
      isDRnShow = false;
      if (state == 2) {
        if (data['fam'] != null) {
          if (index != 1) {
            for (int i = 0; i < famLineList.length; i++) {
              if (famLineList[i].x.toInt() == index) {
                setState(() {});
                return;
              }
            }
            famLineList.add(FlSpot(index.toDouble(), data['fam'].toDouble()));
            roxLineList.add(FlSpot(index.toDouble(), data['rox'].toDouble()));
          } else {
            famLineList.clear();
            roxLineList.clear();
            famLineList.add(FlSpot(index.toDouble(), data['fam'].toDouble()));
            roxLineList.add(FlSpot(index.toDouble(), data['rox'].toDouble()));
          }
          setCoordinate();
        }
      } else if (state == 3) {
        if (famLineList.length < index) {
          await getAllLightData(index);
        }
        enDRnShow = true;
      }
      setState(() {});
    });
  }

  void getState(data) {
    temp = data['temp'] * 1.0;
    temp1 = data['temp1'];
    time1 = data['time1'];
    temp2 = data['temp2'];
    time2 = data['time2'];
    cutoffFam = data['cFam'];
    cutoffRox = data['cRox'];
    state = data['state'];
    remainingTime1 = data['rTime1'];
    remainingTime2 = data['rTime2'];
  }

  getAllLightData(int index) async {
    EasyLoading.show(status: 'loading...');
    await getLightData('famRow', famList, index);
    await getLightData('roxRow', roxList, index);
    await getLightData('famFilter', famList1, index);
    await getLightData('roxFilter', roxList1, index);
    famLineList.clear();
    roxLineList.clear();
    if (state == 3) {
      for (int i = 0; i < index; i++) {
        famLineList.add(FlSpot(i + 1.0, famList1[i].toDouble()));
        roxLineList.add(FlSpot(i + 1.0, roxList1[i].toDouble()));
      }
      dataAnalysis();
      enDRnShow = true;
      isDRnShow = true;
    } else if (state == 2) {
      for (int i = 0; i < index; i++) {
        enDRnShow = false;
        isDRnShow = false;
        famLineList.add(FlSpot(i + 1.0, famList[i].toDouble()));
        roxLineList.add(FlSpot(i + 1.0, roxList[i].toDouble()));
      }
    }
    setCoordinate();
    EasyLoading.dismiss();
  }

  getLightData(String cmd, List<int> list, int index) async {
    list.clear();
    int loop = 0;
    while (true) {
      await sendString('{"cmd":"$cmd","index":$loop}');
      var response =
          await flutterReactiveBle.readCharacteristic(_txCharacteristic);
      var json = String.fromCharCodes(response);
      print('done response=$json');
      var data = jsonDecode(json);
      if (data['done'] == false) {
        for (int i = 0; i < 60; i++) {
          list.add(data['data'][i]);
        }
      } else {
        for (int i = 0; i < index - loop * 60; i++) {
          list.add(data['data'][i]);
        }
        break;
      }
      loop = loop + 1;
    }
    // print('-------------$list');
  }

  dataAnalysis() {
    famResult = 0;
    roxResult = 0;
    int maxFam = 0;
    int maxRox = 0;
    for (int i = 0; i < 6; i++) {
      if (famList1[famList1.length - 1 - i] > cutoffFam) {
        maxFam = maxFam + 1;
      }
      if (roxList1[roxList1.length - 1 - i] > cutoffRox) {
        maxRox = maxRox + 1;
      }
    }

    if (maxFam > 5) famResult = 1;
    if (maxRox > 5) roxResult = 1;
  }

  requestPermission() async {
    var permission = Permission.bluetoothConnect;
    var permissionStatus = await permission.status;

    while (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await permission.request();
    }
    permission = Permission.bluetoothScan;
    permissionStatus = await permission.status;
    while (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await permission.request();
    }
    permission = Permission.manageExternalStorage;
    permissionStatus = await permission.status;
    while (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await permission.request();
    }
    permission = Permission.location;
    permissionStatus = await permission.status;
    while (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await permission.request();
    }
  }

  sendString(String data) async {
    await flutterReactiveBle.writeCharacteristicWithResponse(_rxCharacteristic,
        value: data.codeUnits);
  }

  void scanBle() {
    bleProvider.cleanDevices();
    print('scanBle');
    _scanStream = flutterReactiveBle
        .scanForDevices(withServices: [uartUuid]).listen((device) {
      bleProvider.updateDevice(device);
    });
  }

  void setCoordinate() {
    if (famLineList.isNotEmpty && famLineList[0].x != 0) {
      maxY = 0;
      for (var i = 0; i < famLineList.length; i++) {
        if (famShow) {
          if (maxY < famLineList[i].y) maxY = famLineList[i].y.toInt();
        }
        if (roxShow) {
          if (maxY < roxLineList[i].y) maxY = roxLineList[i].y.toInt();
        }
      }
      if (maxY >= 10000) {
        maxY = (maxY.toDouble() / 10000).ceil() * 10000;
      } else if (maxY >= 1000) {
        maxY = (maxY.toDouble() / 1000).ceil() * 1000;
      } else {
        maxY = 1000;
      }
      maxX = famLineList.length;
    }
    setState(() {});
  }

  configDialog(BuildContext context) {
    _temp1Controller.text = temp1.toString();
    _temp2Controller.text = temp2.toString();
    _time1Controller.text = time1.toString();
    _time2Controller.text = time2.toString();
    _famCutoffController.text = cutoffFam.toString();
    _roxCutoffController.text = cutoffRox.toString();
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return SimpleDialog(
              title: const Text('Config device'),
              children: [
                Column(
                  children: [
                    const Row(
                      children: [
                        SizedBox(
                          width: 100,
                        ),
                        SizedBox(
                          width: 100,
                          child: Text('LYSIS',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text('CRISPR',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 100,
                            child: Text('Temp', textAlign: TextAlign.center)),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: _temp1Controller,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text('℃'),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: _temp2Controller,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text('℃'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 100,
                            child: Text('Time', textAlign: TextAlign.center)),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: _time1Controller,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text('min'),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: _time2Controller,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text('min'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Divider(
                        thickness: 1,
                        height: 1,
                      ),
                    ),
                    const Row(
                      children: [
                        SizedBox(
                          width: 100,
                        ),
                        SizedBox(
                          width: 100,
                          child: Text('Fam',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text('Rox',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 100,
                            child: Text('Cutoff', textAlign: TextAlign.center)),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: _famCutoffController,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text(''),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: _roxCutoffController,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text(''),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              sendString(
                                  '{"cmd":"setConfig","temp1":${_temp1Controller.text},"temp2":${_temp2Controller.text},"time1":${_time1Controller.text},"time2":${_time2Controller.text},"cutoffFam":${_famCutoffController.text},"cutoffRox":${_roxCutoffController.text}}');
                              Navigator.of(context).pop(true);
                            },
                            child: const Text('Yes')),
                        ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('No')),
                      ],
                    ),
                  ],
                ),
              ],
            );
          });
        });
  }

  adcDialog(BuildContext context, int famAGain, int roxAGain, int famATime,
      int roxATime, int famAStep, int roxAStep) {
    final famAGainController = TextEditingController();
    final roxAGainController = TextEditingController();
    final famTimeController = TextEditingController();
    final roxTimeController = TextEditingController();
    famAGainController.text = famAGain.toString();
    roxAGainController.text = roxAGain.toString();
    famTimeController.text =
        ((famATime + 1) * (famAStep + 1) * 2.78 * 0.001).toStringAsFixed(0);
    roxTimeController.text =
        ((roxATime + 1) * (roxAStep + 1) * 2.78 * 0.001).toStringAsFixed(0);
    return showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return SimpleDialog(
              title: const Text('Config adc'),
              children: [
                Column(
                  children: [
                    Row(
                      children: const [
                        SizedBox(
                          width: 100,
                        ),
                        SizedBox(
                          width: 100,
                          child: Text('Fam',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text('Rox',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 100,
                            child: Text('AGain', textAlign: TextAlign.center)),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: famAGainController,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text(''),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: roxAGainController,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text(''),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 100,
                            child:
                                Text('time(ms)', textAlign: TextAlign.center)),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: famTimeController,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text(''),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: TextField(
                                    controller: roxTimeController,
                                    keyboardType: TextInputType.number,
                                    decoration: inputDecoration,
                                    textAlign: TextAlign.center),
                              ),
                              const Text(''),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              int famAStep =
                                  (double.parse(famTimeController.text) *
                                              1000 /
                                              2.78 /
                                              256 -
                                          1)
                                      .round();
                              int roxAStep =
                                  (double.parse(roxTimeController.text) *
                                              1000 /
                                              2.78 /
                                              256 -
                                          1)
                                      .round();
                              sendString(
                                  '{"cmd":"setAdc","famAGain":${famAGainController.text},"roxAGain":${roxAGainController.text},"famATime":255,"roxATime":255,"famAStep":$famAStep,"roxAStep":$roxAStep}');
                              Navigator.of(context).pop(true);
                            },
                            child: const Text('Yes')),
                        ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('No')),
                      ],
                    ),
                  ],
                ),
              ],
            );
          });
        });
  }

  stopTempDialog(int tempNo) {
    return showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: const Text('Stop device'),
            children: [
              Column(
                children: [
                  const Text('Do you want to stop device?'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            sendString('{"cmd":"stop$tempNo"}');
                            Navigator.of(context).pop(true);
                          },
                          child: const Text('Yes')),
                      ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('No')),
                    ],
                  ),
                ],
              ),
            ],
          );
        });
  }

  disconnectDialog() {
    return showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: const Text('Disconnect device'),
            children: [
              Column(
                children: [
                  const Text('Do you want to disconnect device?'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            bleProvider.updateConnectionStatus(
                                MyConnectionState.disconnected);
                            _connection.cancel();
                            timer?.cancel();
                            selectedDeviceIndex = -1;
                            Navigator.of(context).pop(true);
                          },
                          child: const Text('Yes')),
                      ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('No')),
                    ],
                  ),
                ],
              ),
            ],
          );
        });
  }
}
