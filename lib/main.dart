import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setting.dart';

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
  String balance = '10000'; //残高
  DateFormat dateFormat = DateFormat('M月d日');
  DateTime start = DateTime.now(); //期間開始日時
  DateTime end = DateTime.now().add(Duration(days: 7));//期間終了日時

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAndResetSpent();
    getPeriodText();
  }

  void _checkAndResetSpent() { //期間が過ぎたか判定
    DateTime now = DateTime.now();
    if (now.isAfter(end)) {
      setState(() {
        spent = '0';
        _saveSettings();
      });
      getPeriodText();
      _saveSettings();
    }
  }

  Future<void> _loadSettings() async { //データベースから取り出す
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPeriod = prefs.getString('selectedPeriod') ?? '一週間';
      _startDay = prefs.getString('startDay') ?? '月';
      _startDate = prefs.getString('startDate') ?? '1';
      _budget = prefs.getString('budget') ?? '0';
      spent = prefs.getString('spent') ?? '0';
      balance = prefs.getString('balance') ?? '0';
      end = DateTime.parse(prefs.getString('end') ??
          DateTime.now().add(Duration(days: 7)).toIso8601String());
    });
  }

  Future<void> _saveSettings() async { //データベース保存
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedPeriod', _selectedPeriod);
    await prefs.setString('startDay', _startDay);
    await prefs.setString('startDate', _startDate);
    await prefs.setString('budget', _budget);
    await prefs.setString('spent', spent);
    await prefs.setString('balance', balance);
    await prefs.setString('end', end.toIso8601String());
  }

  Future<void> _clearAllValues() async { //データベース初期化
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _clearSpecificValue(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  double getProgress() { //円グラフ進捗計算
    int i_budget = int.tryParse(_budget) ?? 1;
    int i_spent = int.tryParse(spent) ?? 0;
    return i_budget != 0 ? i_spent / i_budget : 0;
  }

  String getSub() { //予算との差額計算
    int i_budget = int.tryParse(_budget) ?? 0;
    int i_spent = int.tryParse(spent) ?? 0;
    return '${i_budget - i_spent}円';
  }

  String getPeriodText() { //期間計算
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
      start = startDateTime;
      end = endDateTime;
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
      start = startOfWeek;
      end = endOfWeek;
    }
    return '${dateFormat.format(start)}~${dateFormat.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xffC6D8F7),
        title: Text(widget.title),
      ),
      body: Padding(
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
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '残高',
                      style: TextStyle(fontSize: 18.0),
                    ),
                    Text(
                      '$balance円',
                      style: TextStyle(
                        fontSize: 36.0,
                      ),
                    ),
                    SizedBox(height: 20),
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
    );
  }
}

