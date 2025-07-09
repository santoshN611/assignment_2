import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path/path.dart' as Path;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMU Data Recording',
      theme: ThemeData(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _recording = false;

  UserAccelerometerEvent? _userAcc;
  AccelerometerEvent? _acc;
  GyroscopeEvent? _gyro;
  MagnetometerEvent? _mag;

  late final StreamSubscription<UserAccelerometerEvent> _userAccSub;
  late final StreamSubscription<AccelerometerEvent> _accSub;
  late final StreamSubscription<GyroscopeEvent> _gyroSub;
  late final StreamSubscription<MagnetometerEvent> _magSub;

  Timer? _ticker;
  IOSink? _sink;
  File? _csvFile;

  @override
  void initState() {
    super.initState();
    _userAccSub = userAccelerometerEvents.listen((e) => _userAcc = e);
    _accSub = accelerometerEvents.listen((e) => _acc = e);
    _gyroSub = gyroscopeEvents.listen((e) => _gyro = e);
    _magSub = magnetometerEvents.listen((e) => _mag = e);
  }

  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _csvFile = File(Path.join(dir.path, 'imu_data.csv'));
    final exists = await _csvFile!.exists();
    if (exists) {
      await _csvFile!.delete();
    }

    _sink = _csvFile!.openWrite(mode: FileMode.write);
    if (!exists) {
      _sink!.writeln(
        [
          'timestamp',
          'user_x',
          'user_y',
          'user_z',
          'acc_x',
          'acc_y',
          'acc_z',
          'gyro_x',
          'gyro_y',
          'gyro_z',
          'mag_x',
          'mag_y',
          'mag_z',
        ].join(','),
      );
    }

    setState(() => _recording = true);

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final row = [
        ts,
        _userAcc?.x.toStringAsFixed(3) ?? '',
        _userAcc?.y.toStringAsFixed(3) ?? '',
        _userAcc?.z.toStringAsFixed(3) ?? '',
        _acc?.x.toStringAsFixed(3) ?? '',
        _acc?.y.toStringAsFixed(3) ?? '',
        _acc?.z.toStringAsFixed(3) ?? '',
        _gyro?.x.toStringAsFixed(3) ?? '',
        _gyro?.y.toStringAsFixed(3) ?? '',
        _gyro?.z.toStringAsFixed(3) ?? '',
        _mag?.x.toStringAsFixed(3) ?? '',
        _mag?.y.toStringAsFixed(3) ?? '',
        _mag?.z.toStringAsFixed(3) ?? '',
      ].join(',');
      _sink!.writeln(row);
      setState(() {}); // update screen with new values
    });
  }

  Future<void> stopRecording() async {
    _ticker?.cancel();
    _ticker = null;

    if (_sink != null) {
      await _sink!.close();
      _sink = null;
    }

    setState(() => _recording = false);

    if (_csvFile != null && await _csvFile!.exists()) {
      await Share.shareXFiles([
        XFile(_csvFile!.path),
      ], text: 'Here is my IMU data log');
    }
  }

  @override
  void dispose() {
    _userAccSub.cancel();
    _accSub.cancel();
    _gyroSub.cancel();
    _magSub.cancel();
    _ticker?.cancel();
    _sink?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget buildRow(String label, double? x, double? y, double? z) {
      final text = (x == null)
          ? '…'
          : '${x.toStringAsFixed(3)}, '
                '${y!.toStringAsFixed(3)}, '
                '${z!.toStringAsFixed(3)}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('IMU Data Recording')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildRow('User Accelerometer', _userAcc?.x, _userAcc?.y, _userAcc?.z),
          buildRow('Accelerometer', _acc?.x, _acc?.y, _acc?.z),
          buildRow('Gyroscope', _gyro?.x, _gyro?.y, _gyro?.z),
          buildRow('Magnetometer', _mag?.x, _mag?.y, _mag?.z),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _recording ? stopRecording : startRecording,
            child: Text(_recording ? 'Stop & Share' : 'Start Recording'),
          ),
        ],
      ),
    );
  }
}

class ImuData {
  ImuData();
  Map<String, Object?> toMap() => {};
}

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Future<Database> get database async => throw UnimplementedError();
  Future _initDatabase() async => throw UnimplementedError();
  Future _onCreate(Database db, int version) async =>
      throw UnimplementedError();
  Future<void> insertImuData(ImuData imuData) async =>
      throw UnimplementedError();
  Future<void> exportDatabase() async => throw UnimplementedError();
}
