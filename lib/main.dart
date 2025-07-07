// lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path/path.dart' as Path;
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GT IMU Recorder',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF003057), // GT Navy
          secondary: Color(0xFFFFC72C), // GT Old Gold
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003057),
          foregroundColor: Color(0xFFFFC72C),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC72C),
            foregroundColor: Colors.black,
          ),
        ),
      ),
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
  bool recording = false;
  late DatabaseHelper _dbHelper;

  StreamSubscription<UserAccelerometerEvent>? _userAccSub;
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  UserAccelerometerEvent? _lastUserAcc;
  AccelerometerEvent? _lastAcc;
  GyroscopeEvent? _lastGyro;
  MagnetometerEvent? _lastMag;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper.instance;
  }

  @override
  void dispose() {
    _stopRecording();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMU Data Recording'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                await _dbHelper.exportDatabase();
              } catch (e) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(recording ? 'Recording…' : 'Not recording'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: recording ? _stopRecording : _startRecording,
              child: Text(recording ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }

  void _startRecording() {
    _stopRecording();
    _userAccSub = userAccelerometerEvents.listen((e) {
      _lastUserAcc = e;
      _maybeSave();
    });
    _accSub = accelerometerEvents.listen((e) {
      _lastAcc = e;
      _maybeSave();
    });
    _gyroSub = gyroscopeEvents.listen((e) {
      _lastGyro = e;
      _maybeSave();
    });
    _magSub = magnetometerEvents.listen((e) {
      _lastMag = e;
      _maybeSave();
    });
    setState(() => recording = true);
  }

  void _stopRecording() {
    for (var sub in [_userAccSub, _accSub, _gyroSub, _magSub]) {
      sub?.cancel();
    }
    _userAccSub = _accSub = _gyroSub = _magSub = null;
    setState(() => recording = false);
  }

  void _maybeSave() {
    if (_lastUserAcc == null ||
        _lastAcc == null ||
        _lastGyro == null ||
        _lastMag == null)
      return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final data = ImuData(
      timestamp: now,
      user_acc_x: _lastUserAcc!.x,
      user_acc_y: _lastUserAcc!.y,
      user_acc_z: _lastUserAcc!.z,
      acc_x: _lastAcc!.x,
      acc_y: _lastAcc!.y,
      acc_z: _lastAcc!.z,
      gyro_x: _lastGyro!.x,
      gyro_y: _lastGyro!.y,
      gyro_z: _lastGyro!.z,
      mag_x: _lastMag!.x,
      mag_y: _lastMag!.y,
      mag_z: _lastMag!.z,
    );
    _dbHelper.insertImu(data);
  }
}

class ImuData {
  final int timestamp;
  final double user_acc_x, user_acc_y, user_acc_z;
  final double acc_x, acc_y, acc_z;
  final double gyro_x, gyro_y, gyro_z;
  final double mag_x, mag_y, mag_z;

  ImuData({
    required this.timestamp,
    required this.user_acc_x,
    required this.user_acc_y,
    required this.user_acc_z,
    required this.acc_x,
    required this.acc_y,
    required this.acc_z,
    required this.gyro_x,
    required this.gyro_y,
    required this.gyro_z,
    required this.mag_x,
    required this.mag_y,
    required this.mag_z,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp,
    'user_acc_x': user_acc_x,
    'user_acc_y': user_acc_y,
    'user_acc_z': user_acc_z,
    'accelerometer_x': acc_x,
    'accelerometer_y': acc_y,
    'accelerometer_z': acc_z,
    'gyroscope_x': gyro_x,
    'gyroscope_y': gyro_y,
    'gyroscope_z': gyro_z,
    'magnetometer_x': mag_x,
    'magnetometer_y': mag_y,
    'magnetometer_z': mag_z,
  };
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _db;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final docs = await getApplicationDocumentsDirectory();
    final path = Path.join(docs.path, 'imu_data.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE imu_data (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp         INTEGER,
        user_acc_x        REAL,
        user_acc_y        REAL,
        user_acc_z        REAL,
        accelerometer_x   REAL,
        accelerometer_y   REAL,
        accelerometer_z   REAL,
        gyroscope_x       REAL,
        gyroscope_y       REAL,
        gyroscope_z       REAL,
        magnetometer_x    REAL,
        magnetometer_y    REAL,
        magnetometer_z    REAL
      )
    ''');
  }

  Future<void> insertImu(ImuData d) async {
    final db = await database;
    await db.insert(
      'imu_data',
      d.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> exportDatabase() async {
    final db = await database;
    final path = db.path;
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('DB not found at $path');
    }
    await Share.shareXFiles([XFile(path)], text: 'IMU Data (GT Recorder)');
  }
}
