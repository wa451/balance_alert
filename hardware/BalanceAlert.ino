//==============================================================================
//
//  リーフォニーのためのサンプルスケッチ
//
//     用途  : ビーコン・アドバタイザー（発信側）
//		 　　　　なるべく簡単に！
//     MCU   : ATmega328P (3.3V /8MHz)
//     Arduino IDEのバージョン  : 1.8.13
//
//     リーフの構成
//       (1) AI01 4-Sensors 加速度センサを使用
//       (2) AC02 BLE Sugar BLE ビーコンで発信
//       (3) AP01 AVR MCU   MCU
//       (4) AZ01 USB       デバッグ（プログラム書き込み）用
//       (5) AV01 CR2032    コイン電池
//
//    元のプログラム :
//    https://github.com/Leafony/leafony-beacon/tree/master/simple-scanner/Arduino/leafony_beacon
//    Copyright (c) 2019  Trillion-Node Engine Project
//
//    Released under the MIT license（ライセンス：MITライセンス）
//    https://opensource.org/licenses/mit-license.php//
//
//    Rev.1 2021/10/01 	modified by Yamagishi
//
//==============================================================================


//==============================================================================
// 定義
//==============================================================================

#include <MsTimer2.h>  // タイマ割り込みライブラリ
#include <Wire.h>      // I2C通信ライブラリ（センサとの通信）

#include "TBGLib.h"          // BLEライブラリ
#include <SoftwareSerial.h>  // ソフトウエア・シリアル通信ライブラリ

#include <FastLED.h>  // FastLRDライブラリ

#include <avr/pgmspace.h>


//------------------------------------------------------------------------------
// ビーコン送出時に埋め込むデバイス名
// 長さは16文字まで
//------------------------------------------------------------------------------
//                     |1234567890123456|
String strDeviceName = "Leafony_AC02";


//------------------------------------------------------------------------------
// シリアルコンソールへのデバック出力
//    #define DEBUG = 出力あり
//　　// #define DEBUG = 出力なし（コメントアウトする）
//------------------------------------------------------------------------------
#define DEBUG


//------------------------------------------------------------------------------
// IOピンの名前定義
// ＊：今回使用したピン
//------------------------------------------------------------------------------
// PD port
//   ＊digital 0: PD0 = PCRX    (HW UART) デバッグ用 USB
//   ＊digital 1: PD1 = PCTX    (HW UART) デバッグ用 USB
//     digital 2: PD2 = INT0#
//     digital 3: PD3 = INT1#
//     digital 4: PD4 = RSV
//     digital 5: PD5 = CN3_D5
//   ＊digital 6: PD6 = DISCN
//   ＊digital 7: PD7 = BLSLP#
// PB port
//     digital 8: PB0 = UART2_RX (software UART)
//     digital 9: PB1 = UART2_TX (software UART)
//     digital 10:PB2 = SS#
//     digital 11:PB3 = MOSI
//     digital 12:PB4 = MISO
//   ＊digital 13:PB5 = SCK (LED)
//                PB6 = XTAL1
//                PB7 = XTAL2
// PC port
//     digital 14/ Analog0: PC0 = PIN24_D14
//   ＊digital 15/ Analog1: PC1 = BLETX (software UART)
//   ＊digital 16/ Analog2: PC2 = BLERX (software UART)
//     digital 17/ Analog3: PC3 = PIN27_D17
//   ＊digital 18/ SDA    : PC4 = SDA   (I2C)
//   ＊digital 19/ SCL    : PC5 = SCL   (I2C)
//     RESET              : PC6 = RESET#
//------------------------------------------------------------------------------
#define SWITCH 2
#define SPEAKER 5
#define BLE_RESET_PIN 6
#define BLE_WAKEUP_PIN 7
#define LED_PIN 13
#define BLETX 15
#define BLERX 16
#define DATA_PIN SCL

#define LED_R 11
#define LED_G 10
#define LED_B 9

#define LIS3DH_ADDRESS 0x19

//------------------------------
// BLE
//------------------------------
#define BLE_STATE_STANDBY (0)
#define BLE_STATE_SCANNING (1)
#define BLE_STATE_ADVERTISING (2)
#define BLE_STATE_CONNECTING (3)
#define BLE_STATE_CONNECTED_MASTER (4)
#define BLE_STATE_CONNECTED_SLAVE (5)


//------------------------------------------------------------------------------
// プログラム内で使用する定数定義
//------------------------------------------------------------------------------

//-----------------------------------------------
// MsTimer2のタイマー割り込み発生間隔(ms)
// loop()内でタイマ割り込みと連携
//-----------------------------------------------
#define LOOP_INTERVAL 10000  // 10s interval

//-----------------------------------------------
// 残高段階
//-----------------------------------------------
#define BALANCE_BOOT 0x00
#define BALANCE_RED 0x01
#define BALANCE_ORANGE 0x02
#define BALANCE_YELLOW 0x03
#define BALANCE_GREEN 0x04


//==============================================================================
// オブジェクト
//==============================================================================

//-----------------------------------------------
// BLE
//-----------------------------------------------
SoftwareSerial Serialble(BLERX, BLETX);
BGLib ble112((HardwareSerial *)&Serialble, 0, 0);

//==============================================================================
// プログラムで使用する変数定義
//==============================================================================

volatile uint8_t Balance = BALANCE_BOOT;  // 残高段階
volatile bool bInterval = false;
volatile bool Sval = false;
volatile bool Scmped = true;


//------------------------------
// BLE
//------------------------------
bool bBLEconnect = false;
bool bBLEsendData = false;

volatile uint8_t ble_state = BLE_STATE_STANDBY;
volatile uint8_t ble_encrypted = 0;   // 0 = not encrypted, otherwise = encrypted
volatile uint8_t ble_bonding = 0xFF;  // 0xFF = no bonding, otherwise = bonding handle

volatile bool ble_written = false;

//==============================================================================
// プログラム
//==============================================================================

//------------------------------------------------------------------------------
// setup / 初期化
//------------------------------------------------------------------------------

//---------------------------------------------------------------------
// 各デバイスの初期設定
//---------------------------------------------------------------------

//-----------------------------------------------
// BLEの初期化
//-----------------------------------------------
void setupBLE() {

  uint8 stLen;
  uint8 adv_data[31];

  pinMode(BLE_RESET_PIN, OUTPUT);
  digitalWrite(BLE_RESET_PIN, LOW);

  pinMode(BLE_WAKEUP_PIN, OUTPUT);
  digitalWrite(BLE_WAKEUP_PIN, HIGH);

  ble112.onBusy = onBusy;
  ble112.onIdle = onIdle;
  ble112.onTimeout = onTimeout;

  ble112.ble_evt_gatt_server_attribute_value = my_evt_gatt_server_attribute_value;
  ble112.ble_evt_le_connection_opend = my_evt_le_connection_opend;
  ble112.ble_evt_le_connection_closed = my_evt_le_connection_closed;
  ble112.ble_evt_system_boot = my_evt_system_boot;

  ble112.ble_evt_system_awake = my_evt_system_awake;

  // BGLib イベントハンドラの登録
  ble112.ble_rsp_system_get_bt_address = my_rsp_system_get_bt_address;

  // BLE用のUART設定
  Serialble.begin(9600);
  /* setting */
  /* [set Advertising Data] */
  uint8 ad_data[21] = {
    (2),                                  // field length
    BGLIB_GAP_AD_TYPE_FLAGS,              // field type (0x01)
    (6),                                  // data
    (1),                                  // field length (1 is a temporary default value.)
    BGLIB_GAP_AD_TYPE_LOCALNAME_COMPLETE  // field type (0x09)
  };
  /*  */
  uint8_t lenStr2 = strDeviceName.length();
  ad_data[3] = (lenStr2 + 1);  // field length
  uint8 u8Index;
  for (u8Index = 0; u8Index < lenStr2; u8Index++) {
    ad_data[5 + u8Index] = strDeviceName.charAt(u8Index);
  }
  /*   */
  stLen = (5 + lenStr2);

  /* interval_min :   40ms( =   64 x 0.625ms ) */
  /* interval_max : 1000ms( = 1600 x 0.625ms ) */
  ble112.ble_cmd_le_gap_set_adv_parameters(64, 1600, 7); /* [BGLIB] <interval_min> <interval_max> <channel_map> */
  delay(200);
  while (ble112.checkActivity(1000))
    ; /* [BGLIB] Receive check */

  ble112.ble_cmd_system_get_bt_address();  // アドレスの取得
  while (ble112.checkActivity(1000))
    ;  // 実際の取得はコールバックで
  delay(1000);

  ble112.ble_cmd_le_gap_set_adv_data(SCAN_RSP_ADVERTISING_PACKETS, stLen, ad_data);
  delay(200);
  while (ble112.checkActivity(1000))
    ; /* Receive check */

  /* start */
  //ble112.ble_cmd_le_gap_start_advertising(1, LE_GAP_GENERAL_DISCOVERABLE, LE_GAP_UNDIRECTED_CONNECTABLE);
  ble112.ble_cmd_le_gap_start_advertising(0, LE_GAP_USER_DATA, LE_GAP_CONNECTABLE_SCANNABLE);  // index = 0
  delay(200);
  while (ble112.checkActivity(1000))
    ; /* Receive check */
  /*  */
}

//-----------------------------------------------
// Speakerの初期化
//-----------------------------------------------
void setupSpeaker() {
  pinMode(SPEAKER, OUTPUT);
  //TCCR0A = _BV(COM0B1) | _BV(WGM01) | _BV(WGM00);
  //TCCR0B = _BV(CS00);
}

//------------------------------------------------------------------------------
// その他関数
//------------------------------------------------------------------------------

void StartLED() {
  switch (Balance) {
    case BALANCE_RED:
      analogWrite(LED_R, 255);
      analogWrite(LED_G, 0);
      analogWrite(LED_B, 0);
      break;
    case BALANCE_ORANGE:
      analogWrite(LED_R, 255);
      analogWrite(LED_G, 64);
      analogWrite(LED_B, 0);
      break;
    case BALANCE_YELLOW:
      analogWrite(LED_R, 255);
      analogWrite(LED_G, 255);
      analogWrite(LED_B, 0);
      break;
    case BALANCE_GREEN:
      analogWrite(LED_R, 0);
      analogWrite(LED_G, 255);
      analogWrite(LED_B, 0);
      break;
    default:
      break;
  }
}

void StopLED() {
  analogWrite(LED_R, 0);
  analogWrite(LED_G, 0);
  analogWrite(LED_B, 0);
}

void debug() {
#ifdef DEBUG
  for (int dot = 0; dot < 3; dot++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
#endif
}

//------------------------------------------------------------------------------
// 割り込み処理
//------------------------------------------------------------------------------

//----------------------------------------------
// タイマー割り込み関数
// Timer2 INT
//----------------------------------------------
void intTimer2() {
  StopLED();
  Sval = !Sval;
  MsTimer2::stop();
}

//---------------------------------------------------------------------
// 割り込み処理の初期設定
//---------------------------------------------------------------------

//-----------------------------------------------
// タイマ割込み
// ・割込み間隔：125ms
// ・割込みはオーバーフロー
// メインループのタイマー割り込み設定
//-----------------------------------------------
void setupTC2Int() {
  MsTimer2::set(LOOP_INTERVAL, intTimer2);
}

//------------------------------------------------------------------------------
// setup / 初期化
//------------------------------------------------------------------------------
void setup() {
  delay(1000);

  Serial.begin(115200);  // プログラム書き込み・デバッグ用通信
  Wire.begin();
  delay(200);  // 少し待つと安定する（MCUによってはこれが必要）

  //---- BLE初期化 ----
  setupBLE();
  delay(10);
  delay(10);

  //---- タイマ割込み初期化 ----
  noInterrupts();  // 設定中は割込み禁止
  setupTC2Int();
  interrupts();

  debug();
  Balance = BALANCE_BOOT;
#ifdef DEBUG
  Balance = 4;
#endif
}


//------------------------------------------------------------------------------
// loop / メインループ
//------------------------------------------------------------------------------
void loop() {
  delay(50);
  char val;
  val = digitalRead(SWITCH);
  if ((val == 1) && !Scmped) {
    Scmped = true;
  }
  if ((val == 0) && Scmped) {
    Sval = !Sval;
    Scmped = false;
    if (Sval) {
      StartLED();
    } else {
      StopLED();
#ifdef DEBUG
      Balance -= 1;
      if (Balance <= 0) {
        Balance = 4;
      }
#endif
    }
  }
  if (ble_written && Sval) {
    ble_written = false;
  }
  loopBleRcv();
}


//------------------------------------------------------------------------------
// BLEのコールバック関数
// イベント発生時にライブラリから呼ばれる関数
// https://static4.arrow.com/-/media/arrow/files/pdf/s/silicon-experts_api-ref-guide_blue-gecko-article.pdf
//------------------------------------------------------------------------------

void loopBleRcv(void) {
  // keep polling for new data from BLE
  ble112.checkActivity(0); /* Receive check */

  /*  */
  if (ble_state == BLE_STATE_STANDBY) {
    bBLEconnect = false; /* [BLE] connection state */
  } else if (ble_state == BLE_STATE_ADVERTISING) {
    bBLEconnect = false; /* [BLE] connection state */
  } else if (ble_state == BLE_STATE_CONNECTED_SLAVE) {
    /*  */
    bBLEconnect = true; /* [BLE] connection state */
                        /*  */
  }
}

void my_evt_le_connection_opend(const ble_msg_le_connection_opend_evt_t *msg) {
#ifdef DEBUG
  Serial.print(F("###\tconnection_opend: { "));
  Serial.print(F("address: "));
  // this is a "bd_addr" data type, which is a 6-byte uint8_t array
  for (uint8_t i = 0; i < 6; i++) {
    if (msg->address.addr[i] < 16) Serial.write('0');
    Serial.print(msg->address.addr[i], HEX);
  }
  Serial.println(" }");
#endif
  /*  */
  ble_state = BLE_STATE_CONNECTED_SLAVE;
}
/*  */
//-----------------------------------------------
void my_evt_le_connection_closed(const struct ble_msg_le_connection_closed_evt_t *msg) {
#ifdef DEBUG
  Serial.print(F("###\tconnection_closed: { "));
  Serial.print(F("reason: "));
  Serial.print((uint16_t)msg->reason, HEX);
  Serial.print(F(", connection: "));
  Serial.print(msg->connection, HEX);
  Serial.println(F(" }"));
#endif
  ble112.ble_cmd_le_gap_start_advertising(0, LE_GAP_USER_DATA, LE_GAP_CONNECTABLE_SCANNABLE);  // index = 0
  while (ble112.checkActivity(1000))
    ;

  // set state to ADVERTISING
  ble_state = BLE_STATE_ADVERTISING;

  // clear "encrypted" and "bonding" info
  ble_encrypted = 0;
  ble_bonding = 0xFF;
  /*  */
  bBLEconnect = false; /* [BLE] connection state */
  bBLEsendData = false;
}
/*  */

//-----------------------------------------------
void my_evt_system_boot(const ble_msg_system_boot_evt_t *msg) {
#ifdef DEBUG
  Serial.print("###\tsystem_boot: { ");
  Serial.print("major: ");
  Serial.print(msg->major, HEX);
  Serial.print(", minor: ");
  Serial.print(msg->minor, HEX);
  Serial.print(", patch: ");
  Serial.print(msg->patch, HEX);
  Serial.print(", build: ");
  Serial.print(msg->build, HEX);
  Serial.print(", bootloader_version: ");
  Serial.print(msg->bootloader, HEX); /*  */
  Serial.print(", hw: ");
  Serial.print(msg->hw, HEX);
  Serial.println(" }");
#endif

  // set state to ADVERTISING
  ble_state = BLE_STATE_ADVERTISING;
}

//-----------------------------------------------
void my_evt_system_awake(const ble_msg_system_boot_evt_t *msg) {
  ble112.ble_cmd_system_halt(0);
  while (ble112.checkActivity(1000))
    ;
}


//----------------------------------------------
// モジュールがコマンドの送信を開始する
//----------------------------------------------
void onBusy() {
  debug();  // 動作確認用LEDの点灯（おまけ）
}

//----------------------------------------------
// モジュールが完全な応答または「system_boot」イベントを受信したとき
//----------------------------------------------
void onIdle() {
}

void onTimeout() {
  // set state to ADVERTISING
  ble_state = BLE_STATE_ADVERTISING;

  // clear "encrypted" and "bonding" info
  ble_encrypted = 0;
  ble_bonding = 0xFF;
  /*  */
  bBLEconnect = false; /* [BLE] connection state */
  bBLEsendData = false;
}

//-----------------------------------------------
// called immediately before beginning UART TX of a command
void onBeforeTXCommand() {
}

//-----------------------------------------------
// called immediately after finishing UART TX
void onTXCommandComplete() {
  // allow module to return to sleep (assuming here that digital pin 5 is connected to the BLE wake-up pin)
}

//----------------------------------------------
// データを受信したとき
//----------------------------------------------
void my_evt_gatt_server_attribute_value(const struct ble_msg_gatt_server_attribute_value_evt_t *msg) {
  uint16 attribute = (uint16)msg->attribute;
  uint16 offset = 0;
  uint8 value_len = msg->value.len;

  uint8 value_data[20];
  int8 rcv_data;
  rcv_data = (msg->value.data[0]);


#ifdef DEBUG
  Serial.print(F("###\tgatt_server_attribute_value: { "));
  Serial.print(F("connection: "));
  Serial.print(msg->connection, HEX);
  Serial.print(F(", attribute: "));
  Serial.print((uint16_t)msg->attribute, HEX);
  Serial.print(F(", att_opcode: "));
  Serial.print(msg->att_opcode, HEX);

  Serial.print(", offset: ");
  Serial.print((uint16_t)msg->offset, HEX);
  Serial.print(", value_len: ");
  Serial.print(msg->value.len, HEX);
  Serial.print(", value_data: ");
  Serial.print(rcv_data);

  Serial.println(F(" }"));
#endif
  uint8_t Balance_rcv;
  if (rcv_data <= 0) {
    Balance_rcv = BALANCE_RED;
  } else if (rcv_data < 25) {
    Balance_rcv = BALANCE_ORANGE;
  } else if (rcv_data < 50) {
    Balance_rcv = BALANCE_YELLOW;
  } else {
    Balance_rcv = BALANCE_GREEN;
  }

  if (Balance != Balance_rcv) {
    Balance = Balance_rcv;
    ble_written = true;
  }
  StartLED();
}


//----------------------------------------------
// アドレス取得時にデバッグ出力（おまけ）
//----------------------------------------------
void my_rsp_system_get_bt_address(const struct ble_msg_system_get_bt_address_rsp_t *msg) {
#ifdef DEBUG
  Serial.print("###\tsystem_get_bt_address: { ");
  Serial.print("address: ");
  for (int i = 0; i < 6; i++) {
    Serial.print(msg->address.addr[i], HEX);
  }
  Serial.println(" }");
#endif
  unsigned short addr = 0;
  char cAddr[30];
  addr = msg->address.addr[0] + (msg->address.addr[1] * 0x100);
  sprintf(cAddr, "Device name is Leaf_A_#%05d ", addr);
  Serial.println(cAddr);
}


//==============================================================================
// End of code
