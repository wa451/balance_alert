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
      backgroundColor:Color(0xffFFF8E1),
      appBar: AppBar(
        backgroundColor: Color(0xffFFC107),
        title: Text('設定'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _submitSettings, // 戻るボタンを押したときにデータを返す
        ),
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              
              children: [
                Container(
                  decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                  padding: EdgeInsets.all(40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '予算',
                        style: TextStyle(fontSize: 12.0,
                        color: Color(0xff795548)),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _budgetController,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: '予算を入力してください',
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xffFFE082)), // 通常時の下線色
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xffFFE082)), // フォーカス時の下線色
                                ),
                              ),
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
                      SizedBox(height: 50),

                      Text(
                        '期間',
                        style: TextStyle(fontSize: 12.0,
                        color: Color(0xff795548)),
                      ),

                      Column(//ラジオボタン
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Radio<String>(
                                value: '一週間',
                                groupValue: _selectedPeriod,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPeriod = value!;
                                  });
                                },
                                activeColor: Color(0xffFFE082),
                              ),
                              Text('一週間'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Radio<String>(
                                value: '一ヶ月',
                                groupValue: _selectedPeriod,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPeriod = value!;
                                  });
                                },
                                activeColor: Color(0xffFFE082),
                              ),
                              Text('一ヶ月'),
                            ],
                          ),
                        ],
                      ),

                      if (_selectedPeriod == '一週間')
                        Container(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
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
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text('毎月'),
                                  Expanded(
                                    child: TextField(
                                      controller: _startDateController,
                                      textAlign: TextAlign.center,
                                      decoration:
                                          InputDecoration(hintText: '日付を入力してください',
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xffFFE082)), // 通常時の下線色
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xffFFE082)), // フォーカス時の下線色
                                          ),),
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
      ),
    );
  }
}
