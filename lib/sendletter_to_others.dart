import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'user_data.dart';
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
  XFile? _selectedImage;
  String? _imageUrl;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSending = false;
  Timer? _debounceTimer;
  String _lastSearchConditions = '';
    bool _isDataLoaded = false;
  late UserData userData;


  @override
  void initState() {
    super.initState();
      userData = Provider.of<UserData>(context, listen: false);
       _loadUserData();


  }


  Future<void> _loadUserData() async {
      final prefs = await SharedPreferences.getInstance();
      final String? currentUserId = prefs.getString('current_user_id');
      final String? rememberedId = prefs.getString('rememberedId');
      final String? rememberedName = prefs.getString('rememberedName');

      if (currentUserId == null || rememberedId == null || rememberedName == null) {
          print('Error: current_user_id is null in SharedPreferences');
          _showErrorSnackBar('获取用户信息失败，请重新登录');
          _clearUserDataAndRedirect();
          return;
      }

    userData.setUserData(currentUserId, rememberedId, rememberedName);

    setState(() {
      _isDataLoaded = true;
    });
  }

  void _clearUserDataAndRedirect() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.remove('rememberedName');
    await prefs.remove('rememberedId');
    userData.clear();
    _redirectToLogin();
  }

  void _redirectToLogin() {
    if (mounted){
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
  // Supabase 客户端
  final SupabaseClient _supabase = Supabase.instance.client;

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
  // 图片上传逻辑
  Future<void> _uploadImage() async {
    if (_selectedImage == null) return; // 如果没有选择图片，则不上传

    try {
      final imageName = path.basename(_selectedImage!.path);
      final imagePath = 'letters/$imageName'; // 设置上传路径
      if (kIsWeb) {
        final String imageUrl = Supabase.instance.client.storage.from('letter-attachments').getPublicUrl(imagePath);
        setState(() {
          _imageUrl = imageUrl;
        });
      }else{
        final String imageUrl = Supabase.instance.client.storage.from('letter-attachments').getPublicUrl(imagePath);
        setState(() {
          _imageUrl = imageUrl;
        });
      }
    } catch (e) {
      _showErrorSnackBar('图片上传失败，请重试');
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

      var queryBuilder = _supabase.from('students').select('''
            id, 
            name, 
            class_name,
            school
          ''');

      // 构建 AND 条件，全部进行模糊匹配
      if (name.isNotEmpty || className.isNotEmpty || school.isNotEmpty) {
        queryBuilder = queryBuilder
            .ilike('name', '%$name%')
            .ilike('class_name', '%$className%')
            .ilike('school', '%$school%');
      }

      final response = await queryBuilder
          .limit(20)
          .withConverter((data) => data.map((e) => e).toList())
          .timeout(const Duration(seconds: 3));

       final highlightQuery = name.toLowerCase();
                 setState(() {
                        _searchResults = response.map((user) {
                            return {...user,
                              'highlightedName': _highlightMatches(user['name'], highlightQuery),
                              'highlightedSubtitle': _highlightMatches(
                                    '${user['school']} ${user['class_name']} ', highlightQuery),
                             };
                           }).toList();
                     });

      print('模糊匹配成功: 返回记录数=${_searchResults.length}, 用时=${stopwatch.elapsedMilliseconds}ms');

    } on PostgrestException catch (e) {
      print('搜索发生 Supabase 异常: ${e.message}, 代码=${e.code}, 用时=${stopwatch.elapsedMilliseconds}ms');
      _handleSearchError(e);
    } on TimeoutException catch (e) {
      print('搜索发生超时异常: ${e.toString()}, 用时=${stopwatch.elapsedMilliseconds}ms');
      _handleSearchError('查询超时，请重试');
    }  catch (e) {
      print('其他错误: $e, 用时=${stopwatch.elapsedMilliseconds}ms');
      _handleSearchError(e);
    } finally {
      stopwatch.stop();
    }
  }
  // 错误处理
  void _handleSearchError(dynamic e) {
    String message = '搜索失败，请稍后重试';
    if (e is String){
      message = e;
    } else if (e is PostgrestException) {
      message = e.code == '42P01' ? '系统维护中，请联系管理员' : '查询超时';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 防抖搜索
  void _debounceSearch() {
    final currentSearchConditions = '${_nameController.text.trim()}${_schoolController.text.trim()}${_classController.text.trim()}';

    if (currentSearchConditions == _lastSearchConditions) {
      print('搜索条件没有变化，跳过搜索');
      return;
    }

    _lastSearchConditions = currentSearchConditions;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _searchUsers);
  }

  // 发送信件核心逻辑
  Future<void> _sendLetter() async {
    if (_isSending) return;
    if (userData.currentUserId == null){
      _showErrorSnackBar('获取用户信息失败，请重新登录');
      return;
    }
    setState(() => _isSending = true);

    try {
      final senderId = userData.currentUserId;

      String receiverId;
      String? temporaryReceiverId;
      if (_searchResults.isNotEmpty) {
        receiverId = _searchResults.first['id'];
      } else {
        temporaryReceiverId = 'temp_${_schoolController.text}_${_gradeController.text}_'
            '${_classController.text}_${_nameController.text}_'
            '${DateTime.now().millisecondsSinceEpoch}';
        receiverId = temporaryReceiverId;
      }
      await _uploadImage();

      await _supabase
          .from('Letters')
          .insert({
        'sender_id': senderId.toString(), 
        'receiver_id': receiverId.toString(),
        'message': _messageController.text,
        'delivery_date': _deliveryDateController.text,
        'is_hidden': true,
        'attachment_url': _imageUrl,
        'temporary_receiver_id' : temporaryReceiverId,
      })
          .select()
          .single();

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
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
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
              Expanded(child:_isDataLoaded == false ? const Center(child: CircularProgressIndicator()): SingleChildScrollView(
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
          // onChanged: (value) => _debounceSearch(), // 移除 onChanged
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _schoolController,
          decoration: const InputDecoration(
            labelText: '学校',
            prefixIcon: Icon(Icons.school),
          ),
          // onChanged: (value) => _debounceSearch(), // 移除 onChanged
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _classController,
          decoration: const InputDecoration(
            labelText: '班级',
            prefixIcon: Icon(Icons.group),
          ),
          // onChanged: (value) => _debounceSearch(), // 移除 onChanged
        ),
        const SizedBox(height: 15),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('智能搜索'),
          onPressed: _debounceSearch,
        ),
        const SizedBox(height: 15),
        if (_searchResults.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        user['name'] != null && user['name'] is String && user['name'].isNotEmpty
                            ? user['name'][0]
                            : '',
                      ),
                    ),
                   title:  Text.rich(user['highlightedName']),
                    subtitle: Text.rich(user['highlightedSubtitle']),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => setState(() => _searchResults = [user]),
                    ),
                  ),
                );
              },
            ),
          ),
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

    TextSpan _highlightMatches(String text, String query) {
    final spans = <TextSpan>[];
    int lastIndex = 0;
    if (query.isEmpty) {
      return TextSpan(text: text, style: TextStyle(color: Colors.grey[600]));
    }
    final index = text.toLowerCase().indexOf(query);

     if(index != -1){
          spans.add(TextSpan(
            text: text.substring(lastIndex, index),
            style: TextStyle(color: Colors.grey[600]),
        ));

         spans.add(TextSpan(
            text: text.substring(index, index + query.length),
            style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.bold),
             ));
         lastIndex = index + query.length;
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
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8)
                ),
                height: 150,
                child: InkWell(
                  onTap: _pickImage,
                  child: _selectedImage == null
                      ? const Center(child:  Icon(Icons.add_a_photo, size: 40, color: Colors.black45,))
                      :
                  kIsWeb
                      ? Image.network(_selectedImage!.path, fit: BoxFit.cover, )
                      :Image.file(File(_selectedImage!.path), fit: BoxFit.cover),

                ),
              ),
            ),

          ],
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


}