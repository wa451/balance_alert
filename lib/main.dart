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
  String _selectedPeriod = '一週間'; //期間範囲
  String _startDay = '月'; //何曜日始まり
  String _startDate = '1'; //何日始まり
  String _budget = "0"; //予算
  String spent = '5000'; //使った額
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
    _loadAmountsAndCalculateSpent();
  }

  @override
  //ロードし終わってからspentを計算する
  Future<void> _loadAmountsAndCalculateSpent() async {
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

        // 正規表現で金額部分を抽出
        final RegExp amountRegExp = RegExp(r'(\+?\d{1,3}(,\d{3})*)円');
        final matchAmount = amountRegExp.firstMatch(fullText);
        if (matchAmount != null) {
          // 金額をString型からint型に変換
          final amountStr =
              matchAmount.group(1)?.replaceAll(',', ''); // カンマを除去して数値部分を取得
          bool plus=true; //+が含まれているか
          if (amountStr != null && amountStr.startsWith('+')){
            print('文字列の先頭に+があります: $amountStr');
            plus=false;//+が含まれていたらfalse
          }
          final parsedAmount = int.tryParse(amountStr?.replaceFirst('+', '') ?? ''); 
          final parsedSpent_minus = int.parse(spent) + (parsedAmount as int);
          final parsedSpent_plus = int.parse(spent) - (parsedAmount as int);
          if (parsedAmount != null) {
            setState(() {
              // 新しい金額と日付のペアをリストの先頭に追加
              if (amountsWithDates.length >= 20) {
                amountsWithDates.removeLast(); // リストのサイズが20を超えた場合、最も古い項目を削除
              }
              amountsWithDates
                  .insert(0, {'amount': amountStr, 'date': recognizedDate,'imagePath': filePath});
              if (plus){
                spent = parsedSpent_minus.toString();
              }
              else{
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
      }
    } else {
      print('画像ファイルのパスが無効です。');
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
      _selectedPeriod = prefs.getString('selectedPeriod') ?? '一週間';
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

  // 金額と日付のリストを保存するメソッド
  // Future<void> _saveAmountsWithDates() async {
  //   final prefs = await SharedPreferences.getInstance();

  // }

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

  // amountWithDatesの金額部分を全て足した値を計算しspentにいれる
  // void _calculateTotalSpent() {
  //   if (amountsWithDates.isNotEmpty) {
  //     int totalSpent = 0;

  //     for (var entry in amountsWithDates) {
  //       final datePattern = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日');
  //       final match = datePattern.firstMatch(entry['date']);

  //       if (match != null) {
  //         int year = int.parse(match.group(1)!);
  //         int month = int.parse(match.group(2)!);
  //         int day = int.parse(match.group(3)!);

  //         // 抽出した値を使って DateTime を作成する
  //         DateTime entryDate = DateTime(year, month, day);

  //         // start以上、end以下の範囲の日付だけを計算
  //         if (entryDate.isAfter(start.subtract(const Duration(days: 1))) &&
  //             entryDate.isBefore(end.add(const Duration(days: 1)))) {
  //           totalSpent += entry['amount'] as int;
  //         }
  //       }

  //       // 計算結果をsetStateでUIに反映
  //       setState(() {
  //         spent = totalSpent.toString();
  //       });
  //     }
  //   }
  // }

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
    return i_budget != 0 ? i_spent / i_budget : 0;
  }

  String getSub() {
    //予算との差額計算
    int i_budget = int.tryParse(_budget) ?? 0;
    int i_spent = int.tryParse(spent) ?? 0;
    return '${i_budget - i_spent}円';
  }

  String getPeriodText() {
    //期間計算
    DateTime now = DateTime.now();

    if (_selectedPeriod == '一ヶ月') {
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
    } else if (_selectedPeriod == '一週間') {
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

  void adjustSpent(String amount) {
    // 金額を整数に変換
    int i_spent = int.parse(spent);
    int amountValue = int.parse(amount.replaceAll('+', ''));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xffC6D8F7),
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Color(0xffFAE6E1),
                  borderRadius: BorderRadius.circular(30.0),
                ),
                child: Center(
                  child: Text(
                    '期間 ${getPeriodText()}',
                    style: TextStyle(fontSize: 18.0),
                  ),
                ),
              ),

              SizedBox(height: 20),

              Container(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // const Text(
                      //   '残高',
                      //   style: TextStyle(fontSize: 18.0),
                      // ),
                      // Text(
                      //   '${balance}円',
                      //   style: TextStyle(
                      //     fontSize: 36.0,
                      //   ),
                      // ),
                      // SizedBox(height: 20),
                      const Text(
                        '予算',
                        style: TextStyle(fontSize: 18.0),
                      ),
                      Text(
                        '$_budget円',
                        style: TextStyle(
                          fontSize: 36.0,
                          color: Color(0xffA5D9BC),
                        ),
                      ),
                      SizedBox(height: 20),
                      const Text(
                        '使った額',
                        style: TextStyle(fontSize: 18.0),
                      ),
                      Text(
                        '$spent円',
                        style: TextStyle(
                          fontSize: 36.0,
                          color: Color(0xffF29083),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        '予算との差額',
                        style: TextStyle(fontSize: 18.0),
                      ),
                      SizedBox(height: 20),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150.0,
                            height: 150.0,
                            child: CircularProgressIndicator(
                              value: getProgress(),
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xffF29083)),
                              strokeWidth: 30,
                            ),
                          ),
                          Text(
                            getSub(),
                            style: TextStyle(fontSize: 17.0),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              ElevatedButton(
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
                child: Text(
                  '設定',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xffC6D8F7),
                ),
              ),
              ElevatedButton(
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
                child: Text('決済履歴確認'),
              ),

              // ElevatedButton(
              //   onPressed: () async {
              //     await _clearAllValues();
              //     // Optionally, you can navigate back or show a confirmation message
              //   },
              //   child: Text('すべての設定を削除'),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Color(0xffF29083),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
