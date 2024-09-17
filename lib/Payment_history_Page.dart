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
  
  @override
  Widget build(BuildContext context) {
    final sharingData = list?.firstOrNull?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('決済履歴'),
      ),
      body: SingleChildScrollView(
        child:Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                money_day_list.isNotEmpty
                    ? ListView.builder(
                        shrinkWrap: true, // SingleChildScrollView内でListViewを使う場合必要
                        physics: NeverScrollableScrollPhysics(), // 親のスクロールに従う
                        itemCount: money_day_list.length,
                        itemBuilder: (context, index) {
                          final amount = money_day_list[index]['amount'];
                          final date = money_day_list[index]['date'];
                          return ListTile(
                            title: Text('決済金額: $amount 円, 日付: $date', style: TextStyle(fontSize: 18)),
                          );
                        },
                      )
                    : const Text('決済記録なし')
              ],
        ),
        ),
    );
  }
}

