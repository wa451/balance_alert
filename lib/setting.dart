import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final String selectedPeriod;
  final String startDay;
  final String startDate;
  final String budget;

  SettingsScreen({
    required this.selectedPeriod,
    required this.startDay,
    required this.startDate,
    required this.budget,
  });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedPeriod;
  late String _startDay;
  late String _startDate;
  late String _budget;

  late TextEditingController _budgetController;
  late TextEditingController _startDateController;

  @override
  void dispose() {
    // メモリリークを防ぐためにコントローラーを破棄する
    _startDateController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void initState() {
    super.initState();
    _selectedPeriod = widget.selectedPeriod;
    _startDay = widget.startDay;
    _startDate = widget.startDate;
    _budget = widget.budget;

    _startDateController = TextEditingController(text: _startDate);
    _budgetController = TextEditingController(text: _budget);
  }

  @override
  void _submitSettings() { //変数渡し
    Navigator.pop(context, {
      'period': _selectedPeriod,
      'startDay': _startDay,
      'startDate': _startDateController.text,
      'budget': _budgetController.text,
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xffC6D8F7),
        title: Text('設定'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _submitSettings, // 戻るボタンを押したときにデータを返す
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.pink[50],
                borderRadius: BorderRadius.circular(30.0),
              ),
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Text(
                    '予算',
                    style: TextStyle(fontSize: 18.0),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _budgetController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(hintText: '予算を入力してください'),
                          keyboardType: TextInputType.number,
                          onChanged: (String value) {
                            setState(() {
                              _budget = value;
                            });
                          },
                        ),
                      ),
                      Text('円'),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    '期間',
                    style: TextStyle(fontSize: 18.0),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<String>(
                            value: '一週間',
                            groupValue: _selectedPeriod,
                            onChanged: (value) {
                              setState(() {
                                _selectedPeriod = value!;
                              });
                            },
                          ),
                          Text('一週間'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<String>(
                            value: '一ヶ月',
                            groupValue: _selectedPeriod,
                            onChanged: (value) {
                              setState(() {
                                _selectedPeriod = value!;
                              });
                            },
                          ),
                          Text('一ヶ月'),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  if (_selectedPeriod == '一週間')
                    Container(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('毎月'),
                              SizedBox(
                                width: 8,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  DropdownButton<String>(
                                    value: _startDay,
                                    onChanged: (value) {
                                      setState(() {
                                        _startDay = value!;
                                      });
                                    },
                                    items: ['月', '火', '水', '木', '金', '土', '日']
                                        .map((day) => DropdownMenuItem(
                                              value: day,
                                              child: Text(day),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 8,
                              ),
                              Text('曜日始まり'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_selectedPeriod == '一ヶ月')
                    Container(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('毎月'),
                              Expanded(
                                child: TextField(
                                  controller: _startDateController,
                                  textAlign: TextAlign.center,
                                  decoration:
                                      InputDecoration(hintText: '日付を入力してください'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (String value) {
                                    setState(() {
                                      _startDate = value;
                                    });
                                  },
                                ),
                              ),
                              Text('日始まり'),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
