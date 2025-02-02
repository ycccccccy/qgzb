import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_appbar.dart';

class SendToSelfPage extends StatefulWidget {
  const SendToSelfPage({super.key});

  @override
  _SendToSelfPageState createState() => _SendToSelfPageState();
}

class _SendToSelfPageState extends State<SendToSelfPage> {
  final _messageController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  File? _image;
  bool _isSending = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> _sendLetter() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      // 确保用户会话有效
      final session = _supabase.auth.currentSession;
      if (session == null) throw '用户未登录或会话已过期';

      final user = _supabase.auth.currentUser;
      if (user == null) throw '用户信息获取失败';

      // 压缩图片并上传到存储
      String? imagePath;
      if (_image != null) {
        final compressedImage = await _compressImage(_image!);
        imagePath = await _uploadImage(compressedImage);
        if (imagePath.isEmpty) throw '图片上传失败';
      }

      // 存储信件（使用新语法）
      final letterResponse = await _supabase
          .from('Letters')
          .insert({
            'sender_id': user.id,
            'receiver_id': user.id,
            'message': _messageController.text,
            'delivery_date': _deliveryDateController.text,
          })
          .select()
          .single();

      // 存储附件
      if (imagePath != null) {
        await _supabase.from('attachments').insert({
          'letter_id': letterResponse['id'],
          'file_path': imagePath,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('信件已保存，将在指定时间送达！期待跨时空和亲爱的你再相见！'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('发送失败: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<Uint8List> _compressImage(File image) async {
    return compute(_compressImageInBackground, await image.readAsBytes());
  }

  static Uint8List _compressImageInBackground(List<int> imageBytes) {
    final imageDecoded = img.decodeImage(Uint8List.fromList(imageBytes))!;
    final resized = img.copyResize(imageDecoded, width: 800);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
  }

  Future<String> _uploadImage(Uint8List image) async {
    try {
      final filePath = 'attachments/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('Letters')
          .upload(filePath, image as File, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      return filePath;
    } catch (e) {
      print('图片上传失败: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const GlobalAppBar(title: '给未来的自己', showBackButton: true, actions: [],),
              Expanded(child: _buildForm()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '写下你对未来自己的心声与祝福'),
          ),
          TextField(
            controller: _deliveryDateController,
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                _deliveryDateController.text = DateFormat('yyyy-MM-dd').format(date);
              }
            },
            decoration: const InputDecoration(labelText: '选择送达日期'),
          ),
          _image != null
              ? Image.file(_image!, height: 150)
              : ElevatedButton(
                  onPressed: () async {
                    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (image != null) setState(() => _image = File(image.path));
                  },
                  child: const Text('添加图片附件'),
                ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSending ? null : _sendLetter,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_isSending ? '正在密封胶囊...' : '密封时间胶囊'),
          ),
        ],
      ),
    );
  }
}