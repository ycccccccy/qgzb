import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_appbar.dart';
import 'package:collection/collection.dart';

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
  Timer? _debounceTimer;

  // Supabase 客户端
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // 图片压缩逻辑
  Future<Uint8List> _compressImage(File image) async {
    return compute(_compressImageInBackground, await image.readAsBytes());
  }

  static Uint8List _compressImageInBackground(List<int> imageBytes) {
    final image = img.decodeImage(Uint8List.fromList(imageBytes))!;
    final resized = img.copyResize(image, width: 800);
    return img.encodeJpg(resized, quality: 70);
  }

  // 图片上传逻辑
  Future<String?> _uploadImage(Uint8List image) async {
    try {
      final filePath = 'attachments/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('Letters')
          .upload(filePath, image as File, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      return filePath;
    } catch (e) {
      print('图片上传失败: $e');
      return null;
    }
  }

    Future<void> _searchUsers() async {
    final stopwatch = Stopwatch()..start();
    try {
      final name = _nameController.text.trim();
      final className = _classController.text.trim();
      final school = _schoolController.text.trim();

      if (name.isEmpty && className.isEmpty && school.isEmpty) {
        setState(() {
          _searchResults = [];
        });
        print('所有搜索字段为空，跳过搜索');
        return;
      }

      final queryBuilder = _supabase.from('students').select('''
            id, 
            name, 
            class_name,
            school
          ''');


     // 精确匹配优先
        if (name.isNotEmpty) {
        final exactMatch = await queryBuilder.or('''
              name.like."$name"
            ''').limit(20);

       if ((exactMatch as List).isNotEmpty) {
        setState(() {
          _searchResults = (exactMatch).cast<Map<String, dynamic>>();
        });
        print('精确匹配成功，用时=${stopwatch.elapsedMilliseconds}ms');
         return;
       }
    }

      // 构建 AND 条件
      String andCondition = '';
      final conditions = [];
      if (name.isNotEmpty) {
         conditions.add('name.ilike."%$name%"');
      }
      if (className.isNotEmpty) {
        conditions.add('class_name.ilike."%$className%"');
      }

         if (school.isNotEmpty) {
        conditions.add('school.ilike."%$school%"');
      }
       
      if(conditions.isNotEmpty){
          andCondition = conditions.join(' and ');
           final response = await queryBuilder
          .or(andCondition)
           .limit(20);

         setState(() {
        _searchResults = (response as List).cast<Map<String, dynamic>>();
         });
       } else {
            setState(() {
            _searchResults = [];
        });
      }

    print('模糊匹配成功: 返回记录数=${_searchResults.length}, 用时=${stopwatch.elapsedMilliseconds}ms');

    } on PostgrestException catch (e) {
      print('搜索发生 Supabase 异常: ${e.message}, 代码=${e.code}, 用时=${stopwatch.elapsedMilliseconds}ms');
      _handleSearchError(e);
    } catch (e) {
      print('其他错误: $e, 用时=${stopwatch.elapsedMilliseconds}ms');
      _handleSearchError(e);
    } finally {
      stopwatch.stop();
    }
  }
  // 错误处理
  void _handleSearchError(dynamic e) {
    String message = '搜索失败，请稍后重试';
    if (e is PostgrestException) {
      message = e.code == '42P01' ? '系统维护中，请联系管理员' : '查询超时';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 防抖搜索
  void _debounceSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 5000), _searchUsers);
  }

  // 发送信件核心逻辑
  Future<void> _sendLetter() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final sender = _supabase.auth.currentUser;
      if (sender == null) throw '请先登录';

      String receiverId;
      String? tempId;
      if (_searchResults.isNotEmpty) {
        receiverId = _searchResults.first['id'];
      } else {
        tempId = 'temp_${_schoolController.text}_${_gradeController.text}_'
            '${_classController.text}_${_nameController.text}_'
            '${DateTime.now().millisecondsSinceEpoch}';
        receiverId = tempId;
      }

          String? imagePath;
      if (_selectedImage != null) {
        final compressed = await _compressImage(_selectedImage!);
        imagePath = await _uploadImage(compressed);
        if (imagePath == null) throw '图片上传失败';
      }

     final letterResponse = await _supabase
          .from('Letters')
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

      if (imagePath != null) {
        await _supabase
            .from('attachments')
            .insert({
              'letter_id': letterResponse['id'],
              'file_path': imagePath,
            });
      }

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

  // 清空表单
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
                      _buildSearchSection(),
                      const Divider(height: 40),
                      _buildLetterForm(),
                    ],
                  ),
                ),
              ),
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
            hintText: '请输入姓名',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => _debounceSearch(),
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
        TextField(
          controller: _classController,
          decoration: const InputDecoration(
            labelText: '班级',
            prefixIcon: Icon(Icons.group),
          ),
        ),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('智能搜索'),
          onPressed: _searchUsers,
        ),
        const SizedBox(height: 15),
        if (_searchResults.isNotEmpty)
          ..._searchResults.map((user) => Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  user['name'] != null && user['name'] is String && user['name'].isNotEmpty
                      ? user['name'][0]
                      : '',
                ),
              ),
              title: Text.rich(_highlightMatches(user['name'])),
              subtitle: Text.rich(_highlightMatches(
                  '${user['school']} ${user['class_name']} ')),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => setState(() => _searchResults = [user]),
              ),
            ),
          )),
        if (_searchResults.isEmpty && _nameController.text.isNotEmpty)
          Card(
            color: Colors.amber[50],
            child: const ListTile(
              leading: Icon(Icons.info, color: Colors.amber),
              title: Text('未找到匹配用户'),
              subtitle: Text('信件将暂存服务器，当对方注册时会自动送达'),
            ),
          ),
      ],
    );
  }

    // 关键词高亮组件
  TextSpan _highlightMatches(String text) {
    final query = _nameController.text.toLowerCase();
    final matches = query.split(' ');
    final spans = <TextSpan>[];
    int lastIndex = 0;

     for (final match in matches) {
      if (match.isEmpty) continue;
        final index = text.toLowerCase().indexOf(match);
        if (index != -1) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, index),
          style: TextStyle(color: Colors.grey[600]),
        ));
        spans.add(TextSpan(
          text: text.substring(index, index + match.length),
          style: TextStyle(
              color: Colors.blue[700], fontWeight: FontWeight.bold),
        ));
         lastIndex = index + match.length;
       }
     }
     spans.add(TextSpan(
      text: text.substring(lastIndex),
      style: TextStyle(color: Colors.grey[600]),
    ));
    return TextSpan(children: spans);
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
     
    );
    if (image != null) {
      final file = File(image.path);
      if (await file.length() > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片大小超过5MB，请重新选择')),
        );
        return;
      }
      setState(() => _selectedImage = file);
    }
  }
}