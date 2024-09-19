import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_sharing_intent/model/sharing_file.dart';

class ImageDisplayPage extends StatelessWidget {
  final List<SharedFile>? list;
  final money_day_list;
  const ImageDisplayPage({
    super.key, 
    this.list,
    this.money_day_list});
    
  String money_print(amount){
    if (amount.contains('+')){
      amount = amount.substring(1);
      return '受け取り金額: +¥$amount';
    }
    else{
      return '決済金額: ¥$amount';
    }
  }

// 画像プレビューのためのモーダルダイアログ表示
  void _showImagePreview(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(
                      File(imagePath), // 画像を表示
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              // 左上に「×」ボタンを配置
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    Navigator.of(context).pop(); // モーダルを閉じる
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('決済履歴'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              money_day_list.isNotEmpty
                  ? ListView.builder(
                      shrinkWrap: true, // SingleChildScrollView内でListViewを使う場合必要
                      physics: NeverScrollableScrollPhysics(), // 親のスクロールに従う
                      itemCount: money_day_list.length,
                      itemBuilder: (context, index) {
                        final amount = money_day_list[index]['amount'].toString();
                        final date = money_day_list[index]['date'];
                        final imagePath = money_day_list[index]['imagePath']; // 画像のパスを取得
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 3,// カードの影の強さ（立体感）を設定
                          child: ListTile(
                            leading: Icon(Icons.attach_money, color: Colors.green),
                            title: 
                            Text(
                              money_print(amount),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '日付: $date',
                              style: TextStyle(fontSize: 16),
                            ),
                            trailing: Icon(Icons.calendar_today, color: Colors.blue),
                            onTap: () {
                                // カードを押したときに画像を表示する
                                _showImagePreview(context, imagePath);
                              },
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        '決済記録なし',
                        style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
