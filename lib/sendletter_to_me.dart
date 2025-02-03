import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_appbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart'; // 引入 Provider
import 'user_data.dart';


class SendToSelfPage extends StatefulWidget {
  const SendToSelfPage({super.key});

  @override
  _SendToSelfPageState createState() => _SendToSelfPageState();
}

class _SendToSelfPageState extends State<SendToSelfPage> {
  final _messageController = TextEditingController();
  final _deliveryDateController = TextEditingController();
  bool _isSending = false;
  final _formKey = GlobalKey<FormState>();
  XFile? _selectedImage;
  String? _imageUrl; // 用于存储上传后的图片 URL

  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const EdgeInsets padding = EdgeInsets.all(16);
  static const double buttonHeight = 48;
  static const double spacing = 16;

   @override
  void initState() {
    super.initState();
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
          final userData = Provider.of<UserData>(context, listen: false);
          userData.setUserData(currentUserId, rememberedId, rememberedName);

    }

    void _clearUserDataAndRedirect() async{
       final prefs = await SharedPreferences.getInstance();
        final userData = Provider.of<UserData>(context, listen: false);
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
  @override
  void dispose() {
    _messageController.dispose();
    _deliveryDateController.dispose();
    super.dispose();
  }

  Future<void> _sendLetter() async {
    if (_isSending) return;
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('请填写所有必填项！');
      return;
    }
    final userData = Provider.of<UserData>(context, listen: false);
      if (userData.currentUserId == null){
         _showErrorSnackBar('获取用户信息失败，请重新登录');
         return;
      }
    setState(() => _isSending = true);
    try {
       await _uploadImage();

      await _storeLetter(userData.currentUserId!);
      _showSuccessSnackBar('信件已保存，将在指定时间送达！期待跨时空和亲爱的你再相见！');
      Navigator.pop(context);
    } catch (e) {
      _showErrorSnackBar('发送失败: ${e.toString()}');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _storeLetter(String userId) async {
    try {
        await Supabase.instance.client
          .from('Letters')
          .insert({
        'sender_id': userId,
        'receiver_id': userId,
        'message': _messageController.text,
        'delivery_date': _deliveryDateController.text,
        'attachment_url': _imageUrl, // 保存图片 URL
      });
        //print('Supabase letter insert result: $letter');
    } on PostgrestException catch (e) {
      //print('Supabase letter insert error: $e');
      throw '发送失败：$e';
    }
  }

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
                 //print('Image upload success: $imageUrl');
                         }else{
                 final String imageUrl = Supabase.instance.client.storage.from('letter-attachments').getPublicUrl(imagePath);
                 setState(() {
                    _imageUrl = imageUrl;
                 });
                 //print('Image upload success: $imageUrl');
                         }


      } catch (e) {
        //print('Image upload error: $e');
       _showErrorSnackBar('图片上传失败，请重试');
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
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      final userData = context.watch<UserData>();
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: padding,
          child: Column(
            children: [
              const GlobalAppBar(
                title: '给未来的自己',
                showBackButton: true,
                actions: [],
              ),
             Expanded(child:userData.currentUserId == null ? const Center(child: CircularProgressIndicator()): _buildForm())

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          children: [
            _buildMessageTextField(),
            const SizedBox(height: spacing),
            _buildDeliveryDatePicker(),
             const SizedBox(height: spacing),
             _buildImagePicker(),
            const SizedBox(height: spacing * 2),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }
   Widget _buildImagePicker() {
      return  Row(
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
      );
   }

  Widget _buildMessageTextField() {
    return TextFormField(
      controller: _messageController,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: '写下你对未来自己的心声与祝福',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入您的心声！';
        }
        return null;
      },
    );
  }

  Widget _buildDeliveryDatePicker() {
    return InkWell(
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
        child: IgnorePointer(
          child: TextFormField(
            controller: _deliveryDateController,
            decoration: const InputDecoration(
              labelText: '选择送达日期',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请选择送达日期！';
              }
              return null;
            },
          ),
        ));
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : _sendLetter,
        icon: _isSending
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.send, color: Colors.white),
        label: Text(_isSending ? '正在密封胶囊...' : '密封时间胶囊',
            style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
        ),
      ),
    );
  }
}