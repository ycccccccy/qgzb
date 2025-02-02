import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_appbar.dart';

class SendToOthersPage extends StatefulWidget {
  const SendToOthersPage({super.key});

  @override
  _SendToOthersPageState createState() => _SendToOthersPageState();
}

class _SendToOthersPageState extends State<SendToOthersPage> {
  // 控制器
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _gradeController = TextEditingController();
  final _classController = TextEditingController();
  final _messageController = TextEditingController();
  final _deliveryDateController = TextEditingController();

  // 状态管理
  File? _selectedImage;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSending = false;

   // 图片压缩逻辑，使用 compute 在后台线程执行
  Future<Uint8List> _compressImage(File image) async {
    return compute(_compressImageInBackground, await image.readAsBytes());
  }

  // 实际的压缩逻辑
  static Uint8List _compressImageInBackground(List<int> imageBytes) {
      final img.Image image = img.decodeImage(Uint8List.fromList(imageBytes))!;
      final img.Image resized = img.copyResize(image, width: 800);
      return img.encodeJpg(resized, quality: 70);
  }

   // 上传到Supabase存储
  Future<String?> _uploadImage(Uint8List image) async {
    try {
      final filePath = 'attachments/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('letters')
          .upload(filePath, image as File, fileOptions: const FileOptions(contentType: 'image/jpeg'));
       return filePath;
    } catch (e) {
      print('图片上传失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('图片上传失败: ${e.toString()}'), backgroundColor: Colors.red)
      );
      return null;
    }
  }


  // 用户搜索逻辑
  Future<void> _searchUsers() async {
    try {
      // 第一阶段：精确搜索（学校+年级+班级+姓名）
      var response = await Supabase.instance.client
          .from('users')
          .select('id, name, school, grade, class')
          .ilike('name', '%${_nameController.text}%')
          .eq('school', _schoolController.text)
          .eq('grade', _gradeController.text)
          .eq('class', _classController.text);

      // 第二阶段：扩大范围到年级
      if (response.isEmpty) {
        response = await Supabase.instance.client
            .from('users')
          .select('id, name, school, grade, class')
          .ilike('name', '%${_nameController.text}%')
          .eq('school', _schoolController.text)
          .eq('grade', _gradeController.text);
      }

      setState(() {
        _searchResults = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  // 发送信件核心逻辑
  Future<void> _sendLetter() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      // 验证发送者
      final sender = Supabase.instance.client.auth.currentUser;
      if (sender == null) throw '请先登录';

      // 处理收件人ID
      String receiverId;
      String? tempId;
      if (_searchResults.isNotEmpty) {
        receiverId = _searchResults.first['id'];
      } else {
        // 生成临时唯一标识（学校_年级_班级_姓名_时间戳）
        tempId = 'temp_${_schoolController.text}_${_gradeController.text}_'
            '${_classController.text}_${_nameController.text}_'
            '${DateTime.now().millisecondsSinceEpoch}';
        receiverId = tempId;
      }

      // 处理图片附件
      String? imagePath;
       if (_selectedImage != null) {
          final compressed = await _compressImage(_selectedImage!);
         imagePath = await _uploadImage(compressed);
        if(imagePath == null) {
          setState(() => _isSending = false);
          return; // 如果上传失败，直接返回
        }
      }

      // 存储信件记录
      final letterResponse = await Supabase.instance.client
          .from('letters')
          .insert({
            'sender_id': sender.id,
            'receiver_id': receiverId,
            'message': _messageController.text,
            'delivery_date': _deliveryDateController.text,
            'is_hidden': true,
            'temp_id': tempId,
          })
          .select()
          .single();

      // 存储附件记录
      if (imagePath != null) {
        await Supabase.instance.client
            .from('attachments')
            .insert({
              'letter_id': letterResponse['id'],
              'file_path': imagePath,
            });
      }

      // 清空表单
      _clearForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✉️ 时间胶囊已密封！将在指定时间送达')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  // 清空表单内容
  void _clearForm() {
    _nameController.clear();
    _schoolController.clear();
    _gradeController.clear();
    _classController.clear();
    _messageController.clear();
    _deliveryDateController.clear();
    setState(() {
      _selectedImage = null;
      _searchResults.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const GlobalAppBar(title: '给他人写信', showBackButton: true, actions: [],),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 收件人搜索区
                      _buildSearchSection(),
                      const Divider(height: 40),
                      // 信件内容区
                      _buildLetterForm(),
                    ],
                  ),
                )
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('收件人信息', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '姓名',
            hintText: '请输入完整姓名',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _schoolController,
          decoration: const InputDecoration(
            labelText: '学校',
            prefixIcon: Icon(Icons.school),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _gradeController,
                decoration: const InputDecoration(
                  labelText: '年级',
                  prefixIcon: Icon(Icons.class_),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _classController,
                decoration: const InputDecoration(
                  labelText: '班级',
                  prefixIcon: Icon(Icons.group),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('搜索收件人'),
          onPressed: _searchUsers,
        ),
        const SizedBox(height: 15),
        if (_searchResults.isNotEmpty)
          ..._searchResults.map((user) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(user['name'][0])),
              title: Text(user['name']),
              subtitle: Text('${user['school']} ${user['grade']}年级${user['class']}班'),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => setState(() => _searchResults = [user]),
              ),
            ),
          )),
        if (_searchResults.isEmpty && _nameController.text.isNotEmpty)
          Card(
            color: Colors.amber[50],
            child: ListTile(
              leading: const Icon(Icons.info, color: Colors.amber),
              title: const Text('未找到匹配用户'),
              subtitle: const Text('信件将暂存服务器，当对方注册时会自动送达'),
            ),
          ),
      ],
    );
  }

  Widget _buildLetterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('信件内容', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '写下你想说的话...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Text('送达时间', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _deliveryDateController,
          readOnly: true,
          decoration: const InputDecoration(
            hintText: '选择信件开启日期',
            prefixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder(),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (date != null) {
              _deliveryDateController.text = DateFormat('yyyy-MM-dd').format(date);
            }
          },
        ),
        const SizedBox(height: 20),
        Text('添加附件', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _selectedImage != null
            ? Column(
                children: [
                  Image.file(_selectedImage!, height: 150),
                  TextButton(
                    child: const Text('更换图片', style: TextStyle(color: Colors.blue)),
                    onPressed: _pickImage,
                  ),
                ],
              )
            : OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: const Text('添加图片（不超过1MB）'),
                onPressed: _pickImage,
              ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          icon: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_isSending ? '正在密封胶囊...' : '立即发送'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _isSending ? null : _sendLetter,
        ),
      ],
    );
  }

   Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
      if (image != null) {
       final file = File(image.path);
      if (await file.length() > 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片大小超过1MB，请重新选择')),
          );
        return;
      }
        setState(() => _selectedImage = file);
    }
  }
}