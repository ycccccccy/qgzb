import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SendLetterScreen extends StatefulWidget {
  @override
  _SendLetterScreenState createState() => _SendLetterScreenState();
}

class _SendLetterScreenState extends State<SendLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _receiverClassController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
    bool _isLoading = false;

  @override
  void dispose() {
    _receiverNameController.dispose();
    _receiverClassController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _sendLetter() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
     _isLoading = true;
    });

    try {
     final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id') ?? '';

    
      final receiverName = _receiverNameController.text.trim();
      final receiverClass = _receiverClassController.text.trim();
      final content = _contentController.text.trim();
       print('Sender ID: $currentUserId');
      print('Receiver Name: $receiverName');
       print('Receiver Class: $receiverClass');
      print('Content: $content');


    final letter = await Supabase.instance.client
        .from('letters')
        .insert({
      'sender_id': currentUserId,
      'receiver_name': receiverName,
      'receiver_class': receiverClass,
      'content': content,
      'send_time': DateTime.now().toIso8601String()
    })
        .select()
      .single();
       print('Supabase letter insert result: $letter');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('信件发送成功')));
       Navigator.pop(context);
    }
     on PostgrestException catch (e) {
     print('获取信件数据发生 Supabase 错误: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败')));
      }
    catch (e) {
      print('其他错误：$e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败')));
    }
     finally{
      setState(() {
         _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text('发送信件', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _receiverNameController,
                  decoration: InputDecoration(
                    labelText: '收件人姓名',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入收件人姓名';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _receiverClassController,
                  decoration: InputDecoration(
                    labelText: '收件人班级',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入收件人班级';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: '信件内容',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入信件内容';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),
                   ElevatedButton(
                            onPressed: _isLoading ? null : _sendLetter,
                           child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text('发送', style: TextStyle(color: Colors.white)),
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}