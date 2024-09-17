import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_sharing_intent/model/sharing_file.dart';


class ImageDisplayPage extends StatelessWidget {
  final List<SharedFile>? list;
  const ImageDisplayPage({super.key, this.list});
  
  @override
  Widget build(BuildContext context) {
    final sharingData = list?.firstOrNull?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('画像表示ページ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: sharingData != null
            ? Image.file(File(sharingData)) // 画像を表示
            : const Center(
                child: Text('画像がありません'),
              ),
      ),
    );
  }
}

