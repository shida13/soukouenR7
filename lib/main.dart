import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyBadgeApp());
}

class MyBadgeApp extends StatelessWidget {
  const MyBadgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
    _initializeWebView();
  }

  void _initializeWebView() {
    final url = 'https://8card.net/p/${widget.userId}';
    debugPrint('Loading URL: $url');
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('✓ Page started: $url');
          },
          onPageFinished: (url) {
            debugPrint('✓ Page finished: $url');
          },
          onWebResourceError: (error) {
            debugPrint('✗ WebView error: ${error.description}');
            debugPrint('✗ Error code: ${error.errorCode}');
          },
          onHttpError: (error) {
            debugPrint('✗ HTTP error: ${error.response?.statusCode}');
          },
        ),
      );
    
    // ページを読み込む
    try {
      controller.loadRequest(Uri.parse(url));
      debugPrint('✓ URL loading initiated');
    } catch (e) {
      debugPrint('✗ Error loading URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('詳細: ${widget.userId}')),
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
  List<String> foundIds = [];
  bool isScanning = false;
  StreamSubscription<List<ScanResult>>? scanSubscription;

  void startScan() async {
    debugPrint('=== Scan Started ===');
    debugPrint('Platform: ${Platform.operatingSystem}');

    // Check if Bluetooth is supported
    if (!Platform.isAndroid) {
      debugPrint('This app only runs on Android');
      return;
    }

    BluetoothAdapterState state = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => BluetoothAdapterState.off,
        );

    debugPrint('Bluetooth adapter state: $state');

    if (state != BluetoothAdapterState.on) {
      debugPrint('Bluetooth is not enabled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetoothを有効にしてください')),
        );
      }
      return;
    }

    setState(() {
      foundIds.clear();
      isScanning = true;
    });

    await scanSubscription?.cancel();
    
    int resultCount = 0;
    final targetUuid = Guid("4FAF0D99-A0CB-41B0-802F-982463F8B3C3");
    
    scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        resultCount++;
        debugPrint('[Scan Results #$resultCount] Found ${results.length} devices');
        for (ScanResult r in results) {
          debugPrint(
            'Device: ${r.device.name ?? "Unknown"} '
            '(${r.device.remoteId}) '
            'RSSI: ${r.rssi}',
          );
          debugPrint('  Manufacturer Data: ${r.advertisementData.manufacturerData}');
          debugPrint('  Service Data: ${r.advertisementData.serviceData}');
          debugPrint('  Service UUIDs: ${r.advertisementData.serviceUuids}');
          
          // 特定のサービスUUIDを持つデバイスのみを検出
          final serviceData = r.advertisementData.serviceData;
          final serviceUuids = r.advertisementData.serviceUuids;

          bool hasTargetUuid = false;
          
          // Service Dataに含まれているか確認
          if (serviceData.containsKey(targetUuid)) {
            try {
              String id = utf8.decode(serviceData[targetUuid]!);
              debugPrint('✓ Found target UUID in Service Data with ID: $id');
              hasTargetUuid = true;
              
              if (!foundIds.contains(id)) {
                setState(() {
                  foundIds.add(id);
                });
                debugPrint('✓ Added ID: $id');
              }
            } catch (e) {
              debugPrint('✗ Error decoding service data: $e');
            }
          }
          
          // Service UUIDsにも含まれているか確認
          if (!hasTargetUuid && serviceUuids.contains(targetUuid)) {
            String deviceId = r.device.remoteId.toString();
            debugPrint('✓ Found target UUID in Service UUIDs');
            if (!foundIds.contains(deviceId)) {
              setState(() {
                foundIds.add(deviceId);
              });
              debugPrint('✓ Added device: $deviceId');
            }
          }
        }
      },
      onError: (e) {
        debugPrint('✗ Scan error: $e');
      },
    );

    try {
      debugPrint('Starting scan...');
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidLegacy: false,
      );
      debugPrint('✓ Scan started successfully');
    } catch (e) {
      debugPrint('✗ Error starting scan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('スキャンエラー: $e')),
        );
      }
      setState(() => isScanning = false);
      return;
    }

    await Future.delayed(const Duration(seconds: 10));
    
    try {
      await FlutterBluePlus.stopScan();
      debugPrint('✓ Scan stopped');
    } catch (e) {
      debugPrint('✗ Error stopping scan: $e');
    }
    
    if (mounted) setState(() => isScanning = false);
    debugPrint('=== Scan Complete ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M5 Badge Tracker'),
        backgroundColor: Colors.blue.shade100,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Icon(
            isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
            size: 100,
            color: isScanning ? Colors.blue : Colors.grey,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isScanning ? null : startScan,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              backgroundColor: Colors.blue.shade50,
            ),
            icon: const Icon(Icons.search),
            label: Text(
              isScanning ? 'スキャン中...' : 'スキャン開始',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const Divider(height: 50, thickness: 1),
          const Text(
            '【 検出結果 】',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: foundIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 50,
                          color: Colors.grey.shade300,
                        ),
                        const Text(
                          '近くにバッジが見つかりません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: foundIds.length,
                    itemBuilder: (context, index) {
                      final id = foundIds[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            'ID: $id',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('タップして詳細を見る'),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WebViewPage(userId: id),
                              ),
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
