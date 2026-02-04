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

class BadgeScannerScreen extends StatefulWidget {
  const BadgeScannerScreen({super.key});

  @override
  State<BadgeScannerScreen> createState() => _BadgeScannerScreenState();
}

class _BadgeScannerScreenState extends State<BadgeScannerScreen> {
  // --- 変数定義 ---
  // IDとRSSI（電波強度）をセットで保存
  final Map<String, int> deviceRssi = {}; 
  
  // 並び順を固定するための表示用リスト
  List<String> sortedKnownIds = [];
  List<String> sortedUnknownIds = [];
  
  // 並び替え用タイマー
  Timer? _sortTimer;

  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  final Map<String, DateTime> lastNotificationTimes = {};
  final Duration notificationInterval = const Duration(minutes: 1);

  Map<String, String> teacherNames = {};
  Map<String, String> userIcons = {};

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _sortTimer?.cancel();
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _openSettings() {
    openAppSettings();
  }

  // --- データ保存・読み込み ---
  Future<void> _loadSavedData() async {
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
        if (key.startsWith('custom_icon_')) {
          String id = key.replaceFirst('custom_icon_', '');
          String? savedIcon = prefs.getString(key);
          if (savedIcon != null) {
            userIcons[id] = savedIcon;
          }
        }
      }
    });
  }

  Future<void> _saveName(String id, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_name_$id', newName);
    setState(() {
      teacherNames[id] = newName;
    });
  }

  Future<void> _saveIcon(String id, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_icon_$id', url);
    setState(() {
      userIcons[id] = url;
    });
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    setState(() {
      teacherNames.clear();
      userIcons.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("全てのデータをリセットしました")),
      );
    }
  }

  // --- Eightプロフィールの取得（リトライ機能付き） ---
  Future<void> _fetchEightProfile(String id) async {
    if (teacherNames.containsKey(id)) {
      return;
    }

    final tempController = WebViewController();
    tempController.setJavaScriptMode(JavaScriptMode.unrestricted);

    tempController.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String url) async {
          int retryCount = 0;
          const int maxRetries = 3;

          while (retryCount < maxRetries) {
            await Future.delayed(const Duration(seconds: 2));

            try {
              final Object result = await tempController.runJavaScriptReturningResult("""
                (function() {
                  var title = document.title || "";
                  var imgUrl = "";
                  
                  // alt="person avatar" を最優先
                  var targetImg = document.querySelector('img[alt="person avatar"]');
                  if (targetImg) {
                      imgUrl = targetImg.src || "";
                  }
                  
                  // 予備1: URLに 'profiles' を含む画像
                  if (!imgUrl) {
                      var imgs = document.getElementsByTagName('img');
                      for (var i = 0; i < imgs.length; i++) {
                          if (imgs[i].src && imgs[i].src.includes('/profiles/')) {
                              imgUrl = imgs[i].src;
                              break;
                          }
                      }
                  }

                  // 予備2: metaタグ
                  if (!imgUrl) {
                      var metaImg = document.querySelector('meta[property="og:image"]');
                      if (metaImg) {
                          imgUrl = metaImg.content || "";
                      }
                  }

                  return title + "|||" + imgUrl;
                })();
              """);

              String resultStr = result.toString();
              if (resultStr.startsWith('"') && resultStr.endsWith('"')) {
                resultStr = resultStr.substring(1, resultStr.length - 1);
              }
              resultStr = resultStr.replaceAll(r'\"', '"').replaceAll(r'\/', '/');

              final parts = resultStr.split('|||');
              if (parts.length == 2) {
                String rawTitle = parts[0];
                String imageUrl = parts[1];
                String? name;

                if (rawTitle.isNotEmpty) {
                  String cleanedTitle = rawTitle.replaceAll(RegExp(r'名刺アプリ|Eight|プロフィール|｜'), '').trim();
                  
                  if (cleanedTitle.contains('|')) {
                    name = cleanedTitle.split('|').first.trim();
                  } else if (cleanedTitle.contains('-')) {
                    name = cleanedTitle.split('-').first.trim();
                  } else if (cleanedTitle.isNotEmpty) {
                    name = cleanedTitle;
                  }
                }

                if (name != null && name.isNotEmpty && !name.contains("ログイン") && name != "Eight") {
                  await _saveName(id, name);

                  if (imageUrl.isNotEmpty) {
                    bool isLikelyDefaultIcon = imageUrl.contains('assets') || imageUrl.contains('logo') || imageUrl.endsWith('svg');
                    if (imageUrl.contains('/profiles/')) {
                        isLikelyDefaultIcon = false;
                    }
                    if (!isLikelyDefaultIcon) {
                      await _saveIcon(id, imageUrl);
                    }
                  }
                  return; // 成功したら終了
                }
              }
            } catch (e) {
              debugPrint('JS Error: $e');
            }
            retryCount++;
          }
        },
      ),
    );

    try {
      final url = 'https://8card.net/p/$id';
      await tempController.loadRequest(Uri.parse(url));
    } catch (e) {
      debugPrint('WebView Load Error: $e');
    }
  }

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

  // --- 通知機能 ---
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

  // --- リストの並び替えロジック ---
  void _updateListOrder() {
    if (!mounted) return;

    setState(() {
      // 既知のIDリストを作成
      final known = deviceRssi.keys
          .where((id) => teacherNames.containsKey(id))
          .toList();

      // RSSIでソート（大きい順＝近い順 ※-40 > -90）
      known.sort((a, b) {
        int rssiA = deviceRssi[a] ?? -100;
        int rssiB = deviceRssi[b] ?? -100;
        return rssiB.compareTo(rssiA); 
      });

      sortedKnownIds = known;

      // 未知のIDリストを作成
      sortedUnknownIds = deviceRssi.keys
          .where((id) => !teacherNames.containsKey(id))
          .toList();
    });
  }

  // --- スキャン制御 ---
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
      deviceRssi.clear();
      sortedKnownIds.clear();
      sortedUnknownIds.clear();
      isScanning = true;
    });

    // 3秒ごとに並び替えを行うタイマーを開始
    _updateListOrder();
    _sortTimer?.cancel();
    _sortTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updateListOrder();
    });

    final targetUuid = Guid("0000feff-0000-1000-8000-00805f9b34fb");

    await scanSubscription?.cancel();

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        final serviceData = r.advertisementData.serviceData;
        if (serviceData.containsKey(targetUuid)) {
          try {
            String id = utf8.decode(serviceData[targetUuid]!);
            
            setState(() {
              // 初めて見つけた場合のみWeb取得処理を呼ぶ
              if (!deviceRssi.containsKey(id)) {
                 _fetchEightProfile(id);
              }
              // RSSIは常に最新値で更新
              deviceRssi[id] = r.rssi;
            });

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
    _sortTimer?.cancel();
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
            child: deviceRssi.isEmpty
                ? const Center(child: Text("スキャン中..."))
                : ListView.builder(
                    itemCount:
                        sortedKnownIds.length + (sortedUnknownIds.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      
                      // 不明なデバイスグループ
                      if (index == sortedKnownIds.length) {
                        return Card(
                          margin: const EdgeInsets.all(16),
                          color: Colors.grey.shade300,
                          child: ListTile(
                            leading: const Icon(Icons.help_outline),
                            title: const Text("不明なデバイス"),
                            subtitle: Text("${sortedUnknownIds.length} 件の未登録ID"),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UnknownDeviceListPage(
                                    unknownIds: sortedUnknownIds,
                                    onRegisterName: _saveName,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }

                      // 既知のデバイス
                      final id = sortedKnownIds[index];
                      final displayName = teacherNames[id]!;
                      final iconUrl = userIcons[id];
                      
                      // RSSIを絶対値（正の値）で表示
                      final rssi = deviceRssi[id]?.abs() ?? 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (iconUrl != null)
                                ? NetworkImage(iconUrl)
                                : null,
                            child: (iconUrl == null)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(displayName),
                          subtitle: Text("ID: $id\n距離目安: $rssi"),
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
                              displayName,
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

class UnknownDeviceListPage extends StatelessWidget {
  final List<String> unknownIds;
  final Function(String, String) onRegisterName;

  const UnknownDeviceListPage({
    super.key,
    required this.unknownIds,
    required this.onRegisterName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("不明なデバイス一覧")),
      body: ListView.builder(
        itemCount: unknownIds.length,
        itemBuilder: (context, index) {
          final id = unknownIds[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text("ID: $id"),
              subtitle: const Text("タップで確認 / 長押しで名前登録"),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showRegistrationDialog(context, id),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebViewPage(userId: id),
                  ),
                );
              },
              onLongPress: () {
                _showRegistrationDialog(context, id);
              },
            ),
          );
        },
      ),
    );
  }

  void _showRegistrationDialog(BuildContext context, String id) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("名前を登録"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: "名前を入力"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onRegisterName(id, controller.text);
                  Navigator.pop(ctx);
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
}