#include <M5StickCPlus.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define SERVICE_UUID_16 0xFEFF

const char* ID_1 = "39965603398";
const char* ID_2 = "40395875448";
const char* ID_3 = "39721478464";

BLEAdvertising* pAdvertising;

void setup() {
  M5.begin();
  M5.Lcd.setRotation(3);
  M5.Lcd.fillScreen(BLACK);
  M5.Lcd.setTextSize(2);
  M5.Lcd.println("BLE Init...");

  // 1. 最初に一度だけBLEを初期化
  BLEDevice::init("M5_Badge");
  BLEServer* pServer = BLEDevice::createServer();
  pAdvertising = BLEDevice::getAdvertising();

  // --- 修正箇所 ---
  // 16bitのUUIDを追加するようにキャストします
  pAdvertising->addServiceUUID(BLEUUID((uint16_t)SERVICE_UUID_16));
  // ----------------

  // シリアルモニタでも確認できるようにする
  Serial.begin(115200);
}

void updateAdvertiseData(const char* idStr) {
  // 1. 発信を停止
  pAdvertising->stop();

  // 2. パケットの中身を作成
  BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
  oAdvertisementData.setFlags(0x04);  // BR_EDR_NOT_SUPPORTED

  // ★修正: 16bit UUID をセット
  oAdvertisementData.setCompleteServices(BLEUUID((uint16_t)SERVICE_UUID_16));

  // ★修正: IDデータをServiceDataとして埋め込む (16bit UUIDを使用)
  // これで容量が節約され、iOSのバックグラウンドでも読めるようになります
  oAdvertisementData.setServiceData(BLEUUID((uint16_t)SERVICE_UUID_16), String(idStr));

  // 3. データをセット
  pAdvertising->setAdvertisementData(oAdvertisementData);

  // 4. 発信再開
  pAdvertising->start();

  // ログ出力
  Serial.printf("Broadcasting ID: %s\n", idStr);

  // 画面更新
  M5.Lcd.fillScreen(BLACK);
  M5.Lcd.setCursor(0, 0);
  M5.Lcd.setTextColor(GREEN);
  M5.Lcd.println("Sending (16bit):");
  M5.Lcd.setTextColor(WHITE);
  M5.Lcd.printf("ID: %s", idStr);
}

void loop() {
  // ID_1 を発信
  updateAdvertiseData(ID_1);
  delay(5000);  // 5秒待機

  // ID_2 を発信
  updateAdvertiseData(ID_2);
  delay(5000);  // 5秒待機

  // ID_3 を発信
  updateAdvertiseData(ID_3);
  delay(5000);  // 5秒待機
}


// #include <M5StickCPlus.h>
// #include <BLEDevice.h>
// #include <BLEUtils.h>
// #include <BLEServer.h>

// // 共通のサービスUUID
// #define SERVICE_UUID "4FAF0D99-A0CB-41B0-802F-982463F8B3C3"

// const char* ID_1 = "39965603398";
// const char* ID_2 = "40395875448";

// BLEAdvertising *pAdvertising;

// void setup() {
//   M5.begin();
//   M5.Lcd.setRotation(3);
//   M5.Lcd.fillScreen(BLACK);
//   M5.Lcd.setTextSize(2);
//   M5.Lcd.println("BLE Init...");

//   // 1. 最初に一度だけBLEを初期化
//   BLEDevice::init("M5_Badge");
//   BLEServer *pServer = BLEDevice::createServer();
//   pAdvertising = BLEDevice::getAdvertising();

//   // --- 修正箇所 ---
//   // 正しいメソッド名: addServiceUUID
//   pAdvertising->addServiceUUID(BLEUUID(SERVICE_UUID));
//   // ----------------

//   // シリアルモニタでも確認できるようにする
//   Serial.begin(115200);
// }

// void updateAdvertiseData(const char* idStr) {
//   // 1. 発信を停止
//   pAdvertising->stop();

//   // 2. パケットの中身を作成
//   BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
//   oAdvertisementData.setFlags(0x04); // BR_EDR_NOT_SUPPORTED
//   oAdvertisementData.setCompleteServices(BLEUUID(SERVICE_UUID));

//   // IDデータをServiceDataとして埋め込む
//   oAdvertisementData.setServiceData(BLEUUID(SERVICE_UUID), String(idStr));

//   // 3. データをセット
//   pAdvertising->setAdvertisementData(oAdvertisementData);

//   // 4. 発信再開
//   pAdvertising->start();

//   // ログ出力
//   Serial.printf("Broadcasting ID: %s\n", idStr);

//   // 画面更新
//   M5.Lcd.fillScreen(BLACK);
//   M5.Lcd.setCursor(0, 0);
//   M5.Lcd.setTextColor(GREEN);
//   M5.Lcd.println("Sending:");
//   M5.Lcd.setTextColor(WHITE);
//   M5.Lcd.printf("ID: %s", idStr);
// }

// void loop() {
//   // ID_1 を発信
//   updateAdvertiseData(ID_1);
//   delay(5000); // 5秒待機

//   // ID_2 を発信
//   updateAdvertiseData(ID_2);
//   delay(5000); // 5秒待機
// }


// // #include <M5StickCPlus.h>
// // #include <BLEDevice.h>
// // #include <BLEUtils.h>
// // #include <BLEServer.h>
// // // ブラウンアウト対策用のヘッダ
// // #include "soc/soc.h"
// // #include "soc/rtc_cntl_reg.h"

// // // 16bit UUID (0xFEFF)
// // #define SERVICE_UUID_16 0xFEFF

// // const char* ID_1 = "39965603398";
// // const char* ID_2 = "40395875448";

// // BLEAdvertising *pAdvertising;
// // bool isAdvertising = false;

// // void setup() {
// //   // 【最重要】ブラウンアウト検出器を無効化 (起動直後のクラッシュ防止)
// //   WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

// //   M5.begin();
// //   M5.Lcd.setRotation(3);
// //   M5.Lcd.fillScreen(BLACK);

// //   // バッテリー動作時の安定化のため少し待つ
// //   delay(500);

// //   M5.Lcd.setTextSize(2);
// //   M5.Lcd.println("BLE Init...");

// //   Serial.begin(115200);

// //   // BLE初期化
// //   BLEDevice::init("M5_Badge");
// //   BLEServer *pServer = BLEDevice::createServer();
// //   pAdvertising = BLEDevice::getAdvertising();

// //   // 最初の発信
// //   startAdvertising(ID_1);
// // }

// // void startAdvertising(const char* idStr) {
// //   if (isAdvertising) {
// //     pAdvertising->stop();
// //     isAdvertising = false;
// //     delay(100); // 停止時間を少し長めに確保
// //   }

// //   BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
// //   oAdvertisementData.setFlags(0x04);
// //   oAdvertisementData.setCompleteServices(BLEUUID((uint16_t)SERVICE_UUID_16));
// //   oAdvertisementData.setServiceData(BLEUUID((uint16_t)SERVICE_UUID_16), String(idStr));

// //   pAdvertising->setAdvertisementData(oAdvertisementData);

// //   // 空のスキャンレスポンス
// //   BLEAdvertisementData oScanResponseData = BLEAdvertisementData();
// //   pAdvertising->setScanResponseData(oScanResponseData);

// //   pAdvertising->start();
// //   isAdvertising = true;

// //   // 画面更新
// //   Serial.printf("Broadcasting ID: %s\n", idStr);
// //   M5.Lcd.fillScreen(BLACK);
// //   M5.Lcd.setCursor(0, 0);
// //   M5.Lcd.setTextColor(GREEN);
// //   M5.Lcd.println("Active:");
// //   M5.Lcd.setTextColor(WHITE);
// //   M5.Lcd.printf("ID: %s", idStr);
// // }

// // void loop() {
// //   // 1. M5StickCのボタン状態などを更新 (これを入れないと死ぬことがある)
// //   M5.update();

// //   delay(5000);
// //   startAdvertising(ID_2);

// //   M5.update();
// //   delay(5000);
// //   startAdvertising(ID_1);
// // }