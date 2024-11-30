import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:intl/intl.dart';

class ImageDisplayPage extends StatefulWidget {
  final List<SharedFile>? list;
  final money_day_list;
  final Function(String, String) adjustSpent;
  const ImageDisplayPage(
      {super.key, this.list, this.money_day_list, required this.adjustSpent});

  @override
  State<ImageDisplayPage> createState() => _ImageDisplayPageState();
}

class _ImageDisplayPageState extends State<ImageDisplayPage> {
  final TextEditingController _amountController = TextEditingController();

  String money_print(amount) {
    if (amount.contains('+')) {
      amount = amount.substring(1);
      return '受け取り金額: +¥$amount';
    } else {
      return '決済金額: ¥$amount';
    }
  }

  String shop_print(shop, bool? shoporhuman, amount) {
    if (!amount.contains('+')) {
      if (shoporhuman ?? true) {
        //店に支払う場合
        return '支払い先: $shop';
      } else {
        //人にあげる場合
        return '譲渡先: $shop';
      }
    } else {
      return '送金元: $shop';
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

  void _showEditDialog(BuildContext context, int index) {
    final originalAmount = widget.money_day_list[index]['amount'].toString();
    _amountController.text = originalAmount; // 初期値として既存の金額をセット

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('編集または削除'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '金額を編集'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                String date = widget.money_day_list[index]['date'];
                setState(() {
                  widget.money_day_list.removeAt(index); // 決済を削除
                });
                widget.adjustSpent(originalAmount, date); // 削除された金額をadjustSpentに反映
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
              child: Text('削除'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.money_day_list[index]['amount'] =
                      int.parse(_amountController.text); // 金額を更新
                });
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
              child: Text('保存'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  // 日付の新しい順に並び替え
  Widget build(BuildContext context) {
  final dateFormat = DateFormat('yyyy年MM月dd日');

  widget.money_day_list.sort((a, b) {
    final dateA = dateFormat.parse(a['date']);
    final dateB = dateFormat.parse(b['date']);
    return dateB.compareTo(dateA); // 降順ソート
  });

    return Scaffold(
      backgroundColor: Color(0xffFFF8E1), //背景色
      appBar: AppBar(
        backgroundColor: Color(0xffFFC107), //appBar背景色
        title: const Row(
          mainAxisSize: MainAxisSize.min, // 必要以上に広がらないように設定
          children: [
            Icon(Icons.history, color: Colors.black), // アイコンの色を白に
            SizedBox(width: 8), // テキストとアイコンの間隔
            Text('決済履歴')
          ],
        ),
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
                        final shop =
                            widget.money_day_list[index]['shop'].toString();
                        final shoporhuman =
                            widget.money_day_list[index]['shoporhuman'];
                        final imagePath = widget.money_day_list[index]
                            ['imagePath']; // 画像のパスを取得
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 3, // カードの影の強さ（立体感）を設定
                          color: Colors.white,
                          child: ListTile(
                            // leading:
                            //     Icon(Icons.attach_money, color: Colors.green),
                            title: Text(
                              money_print(amount),
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            // subtitle: Text(
                            //   '日付: $date',
                            //   style: TextStyle(fontSize: 16),
                            // ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '日付: $date', // 日付を表示
                                  style: TextStyle(fontSize: 16),
                                ),
                                SizedBox(height: 4), // 少し間隔を空ける
                                Text(
                                  shop_print(shop, shoporhuman,
                                      amount), // shop_print を使用
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.blueGrey),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize:
                                  MainAxisSize.min, // Rowが必要以上に広がらないように
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.photo,
                                      color: Colors.blue), // 写真アイコン
                                  onPressed: () {
                                    // アイコンを押したときに画像プレビューを表示
                                    _showImagePreview(context, imagePath);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.green), // 編集アイコン
                                  onPressed: () {
                                    // 編集ダイアログを表示
                                    _showEditDialog(context, index);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0), // 見た目の調整用のパディング
                        child: Text(
                          '決済なし',
                          style: TextStyle(
                            fontSize: 26,
                            color: Colors.grey, // 文字色をグレーに設定
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
