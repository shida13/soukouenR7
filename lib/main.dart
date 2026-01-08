import 'dart:convert';
import 'dart:async';
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
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse('https://8card.net/p//${widget.userId}'));
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
    BluetoothAdapterState state = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => BluetoothAdapterState.off,
        );

    if (state != BluetoothAdapterState.on) return;

    setState(() {
      foundIds.clear();
      isScanning = true;
    });

    await scanSubscription?.cancel();
    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        final targetUuid = Guid("4FAF0D99-A0CB-41B0-802F-982463F8B3C3");
        final serviceData = r.advertisementData.serviceData;

        if (serviceData.containsKey(targetUuid)) {
          String id = utf8.decode(serviceData[targetUuid]!);
          if (!foundIds.contains(id)) {
            setState(() {
              foundIds.add(id);
            });
          }
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() => isScanning = false);
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
