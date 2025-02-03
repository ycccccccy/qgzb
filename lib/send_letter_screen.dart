import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'school_data.dart';
import 'global_appbar.dart';

class SendLetterScreen extends StatefulWidget {
  @override
  _SendLetterScreenState createState() => _SendLetterScreenState();
}

class _SendLetterScreenState extends State<SendLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  String? _selectedGrade;
  int? _selectedClass;
  bool _isAnonymous = false;  // 匿名发送状态
  String? _selectedDistrict;
  String? _selectedSchool;
  String? _mySchool;
  bool _isSpecificClass = false;
  String? _selectedClassName;
  String? _senderName;

  @override
  void initState() {
    super.initState();
    _loadMySchoolAndName();
  }

  void _updateClassValue() {
    if (_selectedGrade != null && _selectedClass != null) {
      setState(() {
        _selectedClassName = '$_selectedGrade$_selectedClass班';
      });
    } else {
      setState(() {
        _selectedClassName = null;
      });
    }
  }

  Future<void> _loadMySchoolAndName() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rememberedId = prefs.getString('rememberedId');
    final String? rememberedName = prefs.getString('rememberedName');
    if (rememberedId != null && rememberedName != null) {
      try {
        final studentData = await _fetchStudentData(rememberedId, rememberedName);
        if (studentData != null) {
          setState(() {
            _mySchool = studentData['school'];
            _senderName = studentData['name'];
          });
        }
      } catch (e) {
        print('Error loadMySchoolAndName: $e');
      }
    }
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _sendLetter() async {
    if (!_formKey.currentState!.validate() || _selectedSchool == null) {
      _showErrorSnackBar('请选择目标学校，并填写内容');
      return;
    }
    if (_isSpecificClass && _selectedClassName == null) {
      _showErrorSnackBar('请选择年级和班级');
      return;
    }
    if (!_isSpecificClass) {
      final confirmSend = await _showConfirmationDialog();
      if (!confirmSend) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';

      final receiverName = _receiverNameController.text.trim();
      final content = _contentController.text.trim();

      final letter = await Supabase.instance.client
          .from('letters')
          .insert({
        'sender_id': currentUserId,
        'sender_name': _senderName,
        'receiver_name': receiverName,
        'content': content,
        'send_time': DateTime.now().toIso8601String(),
        'is_anonymous': _isAnonymous, // 使用 _isAnonymous
        'target_school': _selectedSchool,
        'my_school': _mySchool,
        'receiver_class': _isSpecificClass ? _selectedClassName : null,
      })
          .select()
          .single();
      print('Supabase letter insert result: $letter');
      _showSuccessSnackBar('信件发送成功');
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      print('获取信件数据发生 Supabase 错误: ${e.message}');
      _showErrorSnackBar('发送失败');
    } catch (e) {
      print('其他错误：$e');
      _showErrorSnackBar('发送失败');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('您选择了模糊发送，是否确认发送？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('确认'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(title: '发送信件', showBackButton: true, actions: [],)),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '目标区',
                    hintText: '请选择目标区',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  value: _selectedDistrict,
                  items: schoolList.keys.map((district) => DropdownMenuItem(
                    value: district,
                    child: Text(district),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDistrict = value;
                      _selectedSchool = null;
                      _selectedGrade = null;
                      _selectedClass = null;
                      _isSpecificClass = false;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请选择目标区';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '目标学校',
                    hintText: '请选择目标学校',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  value: _selectedSchool,
                  items: _selectedDistrict != null
                      ? schoolList[_selectedDistrict]?.map((school) => DropdownMenuItem(
                    value: school,
                    child: Text(school),
                  )).toList()
                      : [],
                  onChanged: (value) {
                    setState(() {
                      _selectedSchool = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请选择目标学校';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _isSpecificClass,
                      onChanged: (value) {
                        setState(() {
                          _isSpecificClass = value!;
                          if (!_isSpecificClass) {
                            _selectedGrade = null;
                            _selectedClass = null;
                            _selectedClassName = null;
                          }
                        });
                      },
                    ),
                    const Text('指定班级发送', style: TextStyle(fontSize: 16, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isSpecificClass)
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
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
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
                      const SizedBox(width: 16),
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
                const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                 Row(
                  children: [
                    Checkbox(
                        value: _isAnonymous,
                        onChanged: (value) {
                            setState(() {
                                _isAnonymous = value!;
                             });
                           },
                     ),
                     const Text('匿名发送', style: TextStyle(fontSize: 16, color: Colors.black87)),
                    ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendLetter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('发送', style: TextStyle(color: Colors.white)),
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
        border: UnderlineInputBorder(
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

  Future<Map<String, dynamic>?> _fetchStudentData(
      String studentId, String name) async {
    final query = Supabase.instance.client
        .from('students')
        .select()
        .eq('student_id', studentId)
        .eq('name', name);
    final response = await query;
    if (response.isEmpty) {
      return null;
    }
    return response[0];
  }
}