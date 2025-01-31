import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'global_appbar.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _allowAnonymous = false;
   String? _selectedGrade;
  int? _selectedClass;
    final TextEditingController _classController = TextEditingController();

   @override
  void initState() {
      super.initState();
       _loadAnonymousSetting();
       _selectedGrade = null;
      _selectedClass = null;
  }

   Future<void> _loadAnonymousSetting() async {
    final prefs = await SharedPreferences.getInstance();
   setState(() {
      _allowAnonymous = prefs.getBool('allow_anonymous') ?? false;
    });
  }
  Future<void> _updateAnonymousSetting(bool value) async {
     setState(() {
      _allowAnonymous = value;
    });
     _syncAnonymousSetting(value);
  }
    Future<void> _syncAnonymousSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id') ?? '';
     try{
     await Supabase.instance.client
          .from('students')
          .update({
        'allow_anonymous': value,
      })
          .eq('student_id', currentUserId);
   await prefs.setBool('allow_anonymous', value);

      }on PostgrestException catch (e) {
         print('更新匿名信设置发生 Supabase 错误: ${e.message}');
        ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('更新失败，请稍后重试')));
           setState(() {
              _allowAnonymous = !value;
            });
      }catch(e){
          print('更新匿名信设置发生其他错误：$e');
          ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失败，请稍后重试')));
              setState(() {
                _allowAnonymous = !value;
              });
      }
  }
  Future<void> _changeClass() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('修改班级'),
          content: StatefulBuilder(
           builder: (context, setState) {
             return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                   Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: '年级',
                              hintText: '请选择年级',
                               filled: true,
                                fillColor: Colors.white,
                               border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                             ),
                            value: _selectedGrade,
                            items: [
                              '初一',
                              '初二',
                              '初三',
                              '高一',
                              '高二',
                              '高三',
                            ]
                                .map((grade) => DropdownMenuItem(
                                      value: grade,
                                      child: Text(grade),
                                    ))
                                .toList(),
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
                          child: DropdownButtonFormField<int>(
                            decoration: InputDecoration(
                               labelText: '班级',
                              hintText: '请选择班级',
                               filled: true,
                                fillColor: Colors.white,
                              border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                             ),
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
              ],
            );
           },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确认'),
              onPressed: () async {
                 Navigator.of(context).pop();
                  final prefs = await SharedPreferences.getInstance();
                  final currentUserId = prefs.getString('current_user_id') ?? '';
                 try{
                    await Supabase.instance.client
                      .from('students')
                        .update({
                      'class_name': _classController.text,
                      })
                    .eq('student_id', currentUserId);
                       ScaffoldMessenger.of(context)
                         .showSnackBar(SnackBar(content: Text('班级修改成功')));
                   }on PostgrestException catch (e) {
                     print('更新班级发生 Supabase 错误: ${e.message}');
                      ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('班级修改失败')));
                   }catch (e){
                      print('更新班级发生其他错误：$e');
                      ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('班级修改失败')));
                   }

              },
            ),
          ],
        );
      },
    );
  }
   void _updateClassValue() {
    if (_selectedGrade != null && _selectedClass != null) {
      _classController.text = '$_selectedGrade$_selectedClass班';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar:  PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: GlobalAppBar(title: '设置', showBackButton: true)),
      body: Padding(
           padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                 Text('接收匿名信件', style: TextStyle(fontSize: 16, color: Colors.black87)),
                 Switch(
                   value: _allowAnonymous,
                   onChanged: (value) {
                     _updateAnonymousSetting(value);
                   },
                 ),
               ],
             ),
              SizedBox(height: 16),
            InkWell(
                onTap: _changeClass,
                child:  Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('修改班级', style: TextStyle(fontSize: 16, color: Colors.black87)),
                     Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400])
                   ],
                ),
            ),
          ],
        ),
      ),
    );
  }
}