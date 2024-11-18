import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setting.dart';
import 'Payment_history_Page.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BalanceAlert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'BalanceAlert'),
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
  String _selectedPeriod = '週'; //期間範囲
  String _startDay = '月'; //何曜日始まり
  String _startDate = '1'; //何日始まり
  String _budget = "0"; //予算
  String spent = '5000'; //使った額
  double progress = 0;
  // String balance = '10000'; //残高
  DateFormat dateFormat = DateFormat('M月d日');
  DateTime start = DateTime.now(); //期間開始日時
  DateTime end = DateTime.now().add(Duration(days: 7)); //期間終了日時
  late StreamSubscription _intentDataStreamSubscription;
  List<SharedFile>? list;
  List<Map<String, dynamic>> amountsWithDates = []; // 金額と日付のペアを保存するリスト
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.japanese);
  bool flag = false; //now.isAfter(endDateOnly)用

  @override
  void initState() {
    super.initState();
    _awaitFunc();
  }

  @override
  //ロードし終わってからspentを計算する
  Future<void> _awaitFunc() async {
    await _loadSettings();
    await _loadAmountsWithDates(); // アプリ起動時に保存された金額と日付のリストを読み込む
    _checkAndResetSpent();
    getPeriodText();
    // _calculateTotalSpent(); // 読み込み完了後にspentを計算
    // アプリがメモリ内にあるときにアプリ外から来た画像を共有する場合
    _intentDataStreamSubscription = FlutterSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedFile> value) {
      setState(() {
        list = value;
      });
      _recognizeTextFromImage(); // テキスト認識を呼び出す
    }, onError: (err) {
      print('getIntentDataStream error: $err');
    });

    // アプリ終了中にアプリの外から来た画像を共有する場合
    FlutterSharingIntent.instance
        .getInitialSharing()
        .then((List<SharedFile> value) {
      setState(() {
        list = value;
      });
      _recognizeTextFromImage(); // テキスト認識を呼び出す
    });
  }

  void dispose() {
    _intentDataStreamSubscription.cancel();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _recognizeTextFromImage() async {
    if (list == null || list!.isEmpty) return;

    final filePath = list!.first.value; // 画像ファイルのパスを取得

    if (filePath != null) {
      final inputImage =
          InputImage.fromFilePath(filePath); // 画像をInputImage形式に変換

      try {
        final recognizedText =
            await _textRecognizer.processImage(inputImage); // テキスト認識を実行
        final fullText = recognizedText.text; // 認識された全テキスト

        print('認識されたテキスト: $fullText'); // デバッグ用に全テキストを出力

        // 正規表現で日付部分を抽出
        final RegExp dateRegExp = RegExp(r'(\d{4}年\d{1,2}月\d{1,2}日)');
        final matchDate = dateRegExp.firstMatch(fullText);
        String recognizedDate = matchDate != null
            ? matchDate.group(0)!
            : "日付不明"; // 日付が見つからない場合、デフォルト値を使用
        if (matchDate != null) {
          print('抽出された日付: $recognizedDate');
        } else {
          print('日付が見つかりませんでした。');
        }
        DateTime? recognizedDateTime;
        if (matchDate != null) {
          recognizedDateTime = DateFormat('yyyy年M月d日').parse(recognizedDate);
        }

        // 正規表現で金額部分を抽出
        final RegExp amountRegExp = RegExp(r'(\+?\d{1,3}(,\d{3})*)円');
        final matchAmount = amountRegExp.firstMatch(fullText);
        if (matchAmount != null) {
          // 金額をString型からint型に変換
          final amountStr =
              matchAmount.group(1)?.replaceAll(',', ''); // カンマを除去して数値部分を取得
          bool plus = true; //+が含まれているか
          if (amountStr != null && amountStr.startsWith('+')) {
            print('文字列の先頭に+があります: $amountStr');
            plus = false; //+が含まれていたらfalse
          }
          final parsedAmount =
              int.tryParse(amountStr?.replaceFirst('+', '') ?? '');
                  // 日付が期間内なら支出計算を実行
          final parsedSpent_minus;
          final parsedSpent_plus;
          if (recognizedDateTime != null &&
            recognizedDateTime.isAfter(start.subtract(Duration(days: 1))) &&
            recognizedDateTime.isBefore(end.add(Duration(days: 1)))) {
              parsedSpent_minus = int.parse(spent) + (parsedAmount as int);
              parsedSpent_plus = int.parse(spent) - (parsedAmount as int);
            }
          else{
            parsedSpent_minus = int.parse(spent);
            parsedSpent_plus = int.parse(spent);
          }

          //決済した場所の取得
          String shopName = "不明"; //デフォルト
          bool shoporhuman = true; //デフォルト：
          if (plus) {
            for (final block in recognizedText.blocks) {
              for (final line in block.lines) {
                if (line.text.contains('に支払い')) {
                  shopName = line.text.split('に支払い')[0]; // 店名を抽出
                  break;
                } else if (line.text.contains('に送金(譲渡)')) {
                  shopName = line.text.split('に送金(譲渡)')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                } else if (line.text.contains('に支払')) {
                  shopName = line.text.split('に支払')[0]; // 店名を抽出
                  break;
                } else if (line.text.contains('に送金(譲渡)')) {
                  shopName = line.text.split('に送金(譲渡)')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                } else if (line.text.contains('に支')) {
                  shopName = line.text.split('に支')[0]; // 店名を抽出
                  break;
                } else if (line.text.contains('に送金(譲')) {
                  shopName = line.text.split('に送金(譲')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                } else if (line.text.contains('に送金')) {
                  shopName = line.text.split('に送金')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                }
              }
            }
          } else {
            for (final block in recognizedText.blocks) {
              for (final line in block.lines) {
                if (line.text.contains('から受け取り')) {
                  shopName = line.text.split('から受け取り')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                } else if (line.text.contains('から受け取')) {
                  shopName = line.text.split('から受け取')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                } else if (line.text.contains('から受け')) {
                  shopName = line.text.split('から受け')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                } else if (line.text.contains('から受')) {
                  shopName = line.text.split('から受')[0]; // 人名を抽出
                  shoporhuman = false;
                  break;
                }
              }
            }
          }
          if (parsedAmount != null) {
            setState(() {
              // 新しい金額と日付のペアをリストの先頭に追加
              if (amountsWithDates.length >= 20) {
                amountsWithDates.removeLast(); // リストのサイズが20を超えた場合、最も古い項目を削除
              }
              amountsWithDates.insert(0, {
                'amount': amountStr ?? '0',
                'date': recognizedDate ?? '日付不明',
                'shop': shopName ?? '不明',
                'shoporhuman': shoporhuman ?? true,
                'imagePath': filePath ?? '',
              });
              if (plus) {
                spent = parsedSpent_minus.toString();
              } else {
                spent = parsedSpent_plus.toString();
              }
            });
            await _saveSettings(); // 認識した金額と日付のリストを保存
            print('抽出された金額: $parsedAmount');
          } else {
            print('金額の変換に失敗しました。');
          }
        } else {
          print('金額が見つかりませんでした。');
        }
      } catch (e) {
        print('テキスト認識エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('画像の読み込みに失敗しました。ファイルを確認してください。'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('画像ファイルのパスが無効です。');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像ファイルが見つかりません。'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
  }

  //期間が過ぎたか判定
  void _checkAndResetSpent() {
    DateTime now = DateTime.now();
    DateTime endDateOnly =
        DateTime(end.year, end.month, end.day).add(Duration(days: 1));
    setState(() {
      flag = now.isAfter(endDateOnly);
    });
    print(flag);
    if (flag) {
      setState(() {
        spent = '0';

      if (_selectedPeriod == '月') {
        // 1ヶ月の場合
        start = DateTime(end.year, end.month, end.day + 1);
        end = DateTime(start.year, start.month + 1, start.day - 1);
      } else if (_selectedPeriod == '週') {
        // 1週間の場合
        start = DateTime(end.year, end.month, end.day + 1);
        end = start.add(Duration(days: 6));
      }

        _saveSettings();
      });
      getPeriodText();
      _saveSettings();
    }
  }

  Future<void> _loadSettings() async {
    //データベースから取り出す
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPeriod = prefs.getString('selectedPeriod') ?? '週';
      _startDay = prefs.getString('startDay') ?? '月';
      _startDate = prefs.getString('startDate') ?? '1';
      _budget = prefs.getString('budget') ?? '0';
      spent = prefs.getString('spent') ?? '0';
      // balance = prefs.getString('balance') ?? '0';
      start = DateTime.parse(
          prefs.getString('start') ?? DateTime.now().toIso8601String());
      end = DateTime.parse(prefs.getString('end') ??
          DateTime.now().add(Duration(days: 7)).toIso8601String());
    });
  }

  Future<void> _saveSettings() async {
    //データベース保存
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedPeriod', _selectedPeriod);
    await prefs.setString('startDay', _startDay);
    await prefs.setString('startDate', _startDate);
    await prefs.setString('budget', _budget);
    await prefs.setString('spent', spent);
    // await prefs.setString('balance', balance);
    await prefs.setString('start', start.toIso8601String());
    await prefs.setString('end', end.toIso8601String());
    String jsonString = jsonEncode(amountsWithDates);
    await prefs.setString('saved_amounts_with_dates', jsonString);
  }

  // 保存された金額と日付のリストを読み込むメソッド
  Future<void> _loadAmountsWithDates() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('saved_amounts_with_dates');
    if (jsonString != null) {
      List<dynamic> jsonList = jsonDecode(jsonString);
      setState(() {
        amountsWithDates =
            jsonList.map((e) => e as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _clearAllValues() async {
    //データベース初期化
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _clearSpecificValue(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  double getProgress() {
    //円グラフ進捗計算
    int i_budget = int.tryParse(_budget) ?? 1;
    int i_spent = int.tryParse(spent) ?? 0;
    if (i_budget != 0) {
      setState(() {
        progress = i_spent / i_budget;
      });
    } else {
      setState(() {
        progress = 0;
      });
    }
    return progress;
  }

  String getSub() {
    //予算との差額計算
    int i_budget = int.tryParse(_budget) ?? 0;
    int i_spent = int.tryParse(spent) ?? 0;
    return '${i_budget - i_spent}円';
  }

  Color getColorForProgress(double progress) {
    if (progress <= 0.5) {
      return Colors.green;
    } else if (progress <= 0.75) {
      return Colors.yellow;
    } else if (progress < 1.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String getPeriodText() {
    //期間計算
    DateTime now = DateTime.now();

    if (_selectedPeriod == '月') {
      int startDate = int.tryParse(_startDate) ?? 1;
      startDate = startDate > 30 ? 30 : startDate;
      DateTime startDateTime = DateTime(now.year, now.month, startDate);
      DateTime endDateTime = DateTime(now.year, now.month + 1, startDate - 1);

      if (startDateTime.isAfter(now)) {
        startDateTime = DateTime(now.year, now.month - 1, startDate);
        endDateTime = DateTime(now.year, now.month, startDate - 1);
      }

      if (endDateTime.isBefore(startDateTime)) {
        endDateTime = DateTime(now.year, now.month + 1, startDate - 1);
      }
      setState(() {
        start = startDateTime;
        end = endDateTime;
      });
    } else if (_selectedPeriod == '週') {
      int startDayIndex =
          ['月', '火', '水', '木', '金', '土', '日'].indexOf(_startDay);
      DateTime startOfWeek =
          now.subtract(Duration(days: now.weekday - 1 - startDayIndex));
      DateTime endOfWeek = startOfWeek.add(Duration(days: 6));

      if (startOfWeek.isAfter(now)) {
        startOfWeek = startOfWeek.subtract(Duration(days: 7));
        endOfWeek = startOfWeek.add(Duration(days: 6));
      }
      setState(() {
        start = startOfWeek;
        end = endOfWeek;
      });
    }
    return '${dateFormat.format(start)}~${dateFormat.format(end)}';
  }

  void adjustSpent(String amount, String date) {
    // 金額を整数に変換
    int i_spent = int.parse(spent);
    int amountValue = int.parse(amount.replaceAll('+', ''));
    DateTime dateTime = DateFormat('yyyy年M月d日').parse(date);

    if (dateTime != null &&
      dateTime.isAfter(start.subtract(Duration(days: 1))) &&
      dateTime.isBefore(end.add(Duration(days: 1)))) {
      if (amount.startsWith('+')) {
        // +がついている場合はspentから引く
        i_spent += amountValue;
      } else {
        // +がついていない場合はspentに足す
        i_spent -= amountValue;
      }
      setState(() {
        spent = i_spent.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffFFF8E1), //背景色
      appBar: AppBar(
        backgroundColor: Color(0xffFFC107), //appBar背景色
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                child: Text(
                  '期間 ${getPeriodText()}',
                  style: TextStyle(fontSize: 18.0),
                ),
              ),
              SizedBox(height: 10),
              Container(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 180.0,
                        height: 180.0,
                        child: CircularProgressIndicator(
                          value: getProgress(),
                          backgroundColor: Color(0xffFFF8E1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              getColorForProgress(progress)),
                          strokeWidth: 40,
                        ),
                      ),
                      const SizedBox(height: 40), // 円グラフと凡例の間にスペースを追加

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 16.0,
                            height: 16.0,
                            color: Color(0xffFFD900), // 使った額の色
                          ),
                          const SizedBox(width: 4.0),
                          const Text('支出'),
                          const SizedBox(width: 20),
                          Container(
                            width: 16.0,
                            height: 16.0,
                            color: Color(0xffFFF8E1), // 残りの色
                          ),
                          const SizedBox(width: 4.0),
                          const Text('残額'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xffFFE082), //枠線の色
                      width: 1, //枠線の太さ
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceAround, // 要素間のスペースを均等にする
                  children: [
                    Column(
                      children: [
                        const Text(
                          '予算',
                          style: TextStyle(
                              fontSize: 12.0, color: Color(0xff795548)),
                        ),
                        Text(
                          '$_budget円',
                          style: TextStyle(
                            fontSize: 24.0,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          '支出',
                          style: TextStyle(
                              fontSize: 12.0, color: Color(0xff795548)),
                        ),
                        Text(
                          '$spent円',
                          style: TextStyle(
                            fontSize: 24.0,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          '残額',
                          style: TextStyle(
                              fontSize: 12.0, color: Color(0xff795548)),
                        ),
                        // 差額の表示のために適切な値を入れる
                        Text(
                          '${getSub()}', // 必要に応じて変数を設定してください
                          style: TextStyle(
                            fontSize: 24.0,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(
                        selectedPeriod: _selectedPeriod,
                        startDay: _startDay,
                        startDate: _startDate,
                        budget: _budget,
                      ),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _selectedPeriod = result['period'];
                      _startDay = result['startDay'];
                      _startDate = result['startDate'];
                      _budget = result['budget'];
                    });
                    await _saveSettings();
                  }
                },
                icon: Icon(Icons.settings, color: Colors.black), // アイコンを設定
                label: Text(
                  '設定',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xffFFC107),
                  elevation: 10, // 影の強さ
                  shadowColor: Colors.grey, // 影の色
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ImageDisplayPage(
                            list: list,
                            money_day_list: amountsWithDates,
                            adjustSpent: adjustSpent)),
                  );
                  await _saveSettings();
                },
                icon: Icon(Icons.history, color: Colors.black), // 適切なアイコンを設定
                label: Text(
                  '決済履歴',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xffFFC107),
                  elevation: 10, // 影の強さ
                  shadowColor: Colors.grey, // 影の色
                ),
              ),
              // ElevatedButton.icon(
              //   onPressed:,
              //   icon: Icon(Icons.history, color: Colors.black), // 適切なアイコンを設定
              //   label: Text(
              //     '接続',
              //     style: TextStyle(color: Colors.black),
              //   ),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Color(0xffFFC107),
              //     elevation: 10, // 影の強さ
              //     shadowColor: Colors.grey, // 影の色
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
