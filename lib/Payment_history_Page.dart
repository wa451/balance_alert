import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_sharing_intent/model/sharing_file.dart';

class ImageDisplayPage extends StatefulWidget {
  final List<SharedFile>? list;
  final money_day_list;
  final Function(String) adjustSpent;
  const ImageDisplayPage(
      {super.key, this.list, this.money_day_list, required this.adjustSpent});

  @override
  State<ImageDisplayPage> createState() => _ImageDisplayPageState();
}

class _ImageDisplayPageState extends State<ImageDisplayPage> {
  String money_print(amount) {
    if (amount.contains('+')) {
      amount = amount.substring(1);
      return '受け取り金額: +¥$amount';
    } else {
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
              widget.money_day_list.isNotEmpty
                  ? ListView.builder(
                      shrinkWrap:
                          true, // SingleChildScrollView内でListViewを使う場合必要
                      physics: NeverScrollableScrollPhysics(), // 親のスクロールに従う
                      itemCount: widget.money_day_list.length,
                      itemBuilder: (context, index) {
                        final amount =
                            widget.money_day_list[index]['amount'].toString();
                        final date = widget.money_day_list[index]['date'];
                        final imagePath = widget.money_day_list[index]['imagePath']; // 画像のパスを取得
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 3, // カードの影の強さ（立体感）を設定
                          child: ListTile(
                            leading:
                                Icon(Icons.attach_money, color: Colors.green),
                            title: Text(
                              money_print(amount),
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '日付: $date',
                              style: TextStyle(fontSize: 16),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min, // Rowが必要以上に広がらないように
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.photo, color: Colors.blue), // 写真アイコン
                                  onPressed: () {
                                    // アイコンを押したときに画像プレビューを表示
                                    _showImagePreview(context, imagePath);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red), // 削除アイコン
                                  onPressed: () {
                                    // アイコンを押したときに画像プレビューを表示
                                            _showImagePreview(context, imagePath);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        '決済記録なし',
                        style: TextStyle(
                            fontSize: 18, fontStyle: FontStyle.italic),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
