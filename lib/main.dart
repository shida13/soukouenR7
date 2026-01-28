import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 通知設定 ---
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final String userId = response.payload!;
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => WebViewPage(userId: userId)),
        );
      }
    },
  );

  runApp(const MyBadgeApp());
}

class MyBadgeApp extends StatelessWidget {
  const MyBadgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const BadgeScannerScreen(),
    );
  }
}

// --- Webview画面 ---
class WebViewPage extends StatefulWidget {
  final String userId;
  const WebViewPage({super.key, required this.userId});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadRequest(Uri.parse('https://8card.net/p/${widget.userId}'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ID: ${widget.userId}')),
      body: WebViewWidget(controller: controller),
    );
  }
}

// --- スキャナー画面 (メイン) ---
class BadgeScannerScreen extends StatefulWidget {
  const BadgeScannerScreen({super.key});

  @override
  State<BadgeScannerScreen> createState() => _BadgeScannerScreenState();
}

class _BadgeScannerScreenState extends State<BadgeScannerScreen> {
  final Set<String> foundIds = {};
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  final Map<String, DateTime> lastNotificationTimes = {};
  final Duration notificationInterval = const Duration(minutes: 1);

  Map<String, String> teacherNames = {"39965603398": "小村"};

  @override
  void initState() {
    super.initState();
    _loadSavedNames();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _openSettings() {
    openAppSettings();
  }

  // --- データ保存・読み込み・削除ロジック ---

  // 読み込み
  Future<void> _loadSavedNames() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    setState(() {
      for (String key in keys) {
        if (key.startsWith('custom_name_')) {
          String id = key.replaceFirst('custom_name_', '');
          String? savedName = prefs.getString(key);
          if (savedName != null) {
            teacherNames[id] = savedName;
          }
        }
      }
    });
  }

  // 保存
  Future<void> _saveName(String id, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_name_$id', newName);
    setState(() {
      teacherNames[id] = newName;
    });
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      teacherNames.clear();
      teacherNames = {"39965603398": "小村"};
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("全てのデータをリセットしました")));
    }
  }

  // 名前編集ダイアログ
  void _showEditNameDialog(String id, String currentName) {
    final TextEditingController _controller = TextEditingController(
      text: currentName,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("名前の編集"),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: "表示名を入力"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  _saveName(id, _controller.text);
                  Navigator.pop(context);
                }
              },
              child: const Text("保存"),
            ),
          ],
        );
      },
    );
  }

  // --- 通知ロジック ---
  Future<void> triggerNotification(String id) async {
    final now = DateTime.now();

    if (lastNotificationTimes.containsKey(id)) {
      final lastTime = lastNotificationTimes[id]!;
      if (now.difference(lastTime) < notificationInterval) {
        return;
      }
    }

    lastNotificationTimes[id] = now;
    String name = teacherNames[id] ?? "Guest";

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      ),
      android: AndroidNotificationDetails(
        'badge_channel',
        'Badge Detection',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      id.hashCode,
      'バッジ検知',
      '$name さんが近くにいます',
      platformChannelSpecifics,
      payload: id,
    );
  }

  // --- スキャンロジック ---
  void startScan() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.notification,
        Permission.location,
      ].request();
    } else {
      await FlutterBluePlus.adapterState.first;
    }

    try {
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('BluetoothがOFFか許可されていません。'),
            action: SnackBarAction(label: '設定', onPressed: _openSettings),
          ),
        );
      }
      return;
    }

    setState(() {
      foundIds.clear();
      isScanning = true;
    });

    final targetUuid = Guid("0000feff-0000-1000-8000-00805f9b34fb");

    await scanSubscription?.cancel();

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        final serviceData = r.advertisementData.serviceData;
        if (serviceData.containsKey(targetUuid)) {
          try {
            String id = utf8.decode(serviceData[targetUuid]!);
            if (!foundIds.contains(id)) {
              setState(() {
                foundIds.add(id);
              });
            }
            triggerNotification(id);
          } catch (e) {
            debugPrint("データ解析エラー: $e");
          }
        }
      }
    }, onError: (e) => debugPrint("Scan Error: $e"));

    try {
      await FlutterBluePlus.startScan(
        withServices: [targetUuid],
        continuousUpdates: true,
      );
    } catch (e) {
      debugPrint("StartScan Error: $e");
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M5 Badge Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "データをリセット",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("データのリセット"),
                  content: const Text("保存された名前を全て削除し、初期状態に戻しますか？"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("キャンセル"),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearAllData();
                        Navigator.pop(ctx);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text("削除"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isScanning
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
            child: Icon(
              isScanning ? Icons.radar : Icons.radar_outlined,
              size: 64,
              color: isScanning ? Colors.blue : Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: isScanning ? null : startScan,
                icon: const Icon(Icons.play_arrow),
                label: const Text("スキャン開始"),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: isScanning ? stopScan : null,
                icon: const Icon(Icons.stop),
                label: const Text("停止"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: foundIds.isEmpty
                ? const Center(child: Text("スキャン中..."))
                : ListView.builder(
                    itemCount: foundIds.length,
                    itemBuilder: (context, index) {
                      final id = foundIds.elementAt(index);
                      final displayName = teacherNames[id] ?? "Guest";

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(displayName),
                          subtitle: Text("ID: $id\n長押しで名前を編集"),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WebViewPage(userId: id),
                              ),
                            );
                          },
                          onLongPress: () {
                            _showEditNameDialog(
                              id,
                              displayName == "Guest" ? "" : displayName,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
