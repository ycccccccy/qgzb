import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

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
  String? _selectedGrade;
  int? _selectedClass;
   bool _isAnonymous = false;

  @override
  void initState() {
    _selectedGrade = null;
    _selectedClass = null;
    super.initState();
  }

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
        'send_time': DateTime.now().toIso8601String(),
        'is_anonymous': _isAnonymous
      })
          .select()
          .single();
      print('Supabase letter insert result: $letter');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('信件发送成功')));
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      print('获取信件数据发生 Supabase 错误: ${e.message}');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('发送失败')));
    } catch (e) {
      print('其他错误：$e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('发送失败')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.grey[100],
       appBar:  PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: GlobalAppBar(title: '发送信件', showBackButton: true)),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildTextFormField(
                  controller: _receiverNameController,
                  labelText: '收件人姓名',
                  hintText: '请输入收件人姓名',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入收件人姓名';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: buildDropdownButtonFormField(
                        labelText: '年级',
                        hintText: '请选择年级',
                        value: _selectedGrade,
                        items: [
                          '初一',
                          '初二',
                          '初三',
                          '高一',
                          '高二',
                          '高三',
                        ].map((grade) => DropdownMenuItem(
                          value: grade,
                          child: Text(grade),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGrade = value;
                            _updateClassValue();
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请选择年级';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: buildDropdownButtonFormField(
                        labelText: '班级',
                        hintText: '请选择班级',
                        value: _selectedClass,
                        items: List.generate(13, (index) => index + 1)
                            .map((classNum) => DropdownMenuItem(
                                  value: classNum,
                                  child: Text('$classNum班'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClass = value;
                            _updateClassValue();
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return '请选择班级';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                buildTextFormField(
                  controller: _contentController,
                  labelText: '信件内容',
                  hintText: '请输入信件内容',
                  maxLines: 10,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入信件内容';
                    }
                    return null;
                  },
                ),
                  SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                            value: _isAnonymous,
                            onChanged: (value){
                              setState(() {
                                _isAnonymous = value!;
                              });
                            },
                           ),
                          const Text('匿名发送', style: TextStyle(fontSize: 16, color: Colors.black87)),
                        ],
                    ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendLetter,
                    style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.blue,
                       padding: EdgeInsets.symmetric(vertical: 14),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                     ),
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

  TextFormField buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
          filled: true,
        fillColor: Colors.white,
          border:  UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
      ),
      validator: validator,
    );
  }

  DropdownButtonFormField<T> buildDropdownButtonFormField<T>({
    required String labelText,
    required String hintText,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
          filled: true,
        fillColor: Colors.white,
        border: UnderlineInputBorder(
           borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  void _updateClassValue() {
    if (_selectedGrade != null && _selectedClass != null) {
      _receiverClassController.text = '$_selectedGrade$_selectedClass班';
    }
  }
}