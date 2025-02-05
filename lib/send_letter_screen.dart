import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'school_data.dart';
import 'global_appbar.dart';
import 'ai_assisted_writing_screen.dart'; // 导入 AI 写作助手页面

class SendLetterScreen extends StatefulWidget {
  const SendLetterScreen({Key? key}) : super(key: key);

  @override
  _SendLetterScreenState createState() => _SendLetterScreenState();
}

class _SendLetterScreenState extends State<SendLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  bool _isAnonymous = false;
  String? _selectedDistrict;
  String? _selectedSchool;
  String? _mySchool;
  String? _selectedGrade;
  String? _selectedClassNumber;
  String? _selectedClassName;
  bool _isSpecificClass = false;
  String? _senderName;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  String _lastSearchConditions = '';
  bool _showNoResultTip = false;
  bool _isSearchResultSelected = false;
  Map<String, dynamic>? _selectedSearchResult;

  @override
  void initState() {
    super.initState();
    _loadMySchoolAndName();
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _schoolController.dispose();
    _contentController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _updateClassValue() {
    setState(() {
      if (_selectedGrade != null && _selectedClassNumber != null) {
        _selectedClassName = '$_selectedGrade$_selectedClassNumber';
      } else {
        _selectedClassName = null;
      }
    });
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
      }
    }
  }

  Future<void> _sendLetterWithSearchResult() async {
    if (!_formKey.currentState!.validate() || _selectedSchool == null) {
      _showErrorSnackBar('请选择目标学校，并填写内容');
      return;
    }
    if (_selectedClassName == null || _selectedClassName!.isEmpty) {
      _showErrorSnackBar('请选择年级和班级');
      return;
    }
    await _sendLetter();
  }
  Future<void> _sendLetter() async {
    if (!_formKey.currentState!.validate() || _selectedSchool == null) {
      _showErrorSnackBar('请选择目标学校，并填写内容');
      return;
    }
    if (_selectedClassName == null || _selectedClassName!.isEmpty) {
      final confirmSend = await _showConfirmationDialog();
      if (!confirmSend) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id; // 修改：使用 Supabase Auth 获取 currentUserId
      if (currentUserId == null) {
        _showErrorSnackBar('用户未登录，无法发送信件'); // 添加用户未登录提示
        return;
      }

      final prefs = await SharedPreferences.getInstance(); // sender_name 暂时保持从 SharedPreferences 获取
      final String? currentUserName = prefs.getString('rememberedName');
      final senderName = currentUserName ?? '';

      final receiverName = _receiverNameController.text.trim();
      final content = _contentController.text.trim();

      final letter = await Supabase.instance.client
          .from('letters')
          .insert({
        'sender_id': currentUserId, // 修改：使用 Supabase Auth 获取的 currentUserId
        'sender_name': _senderName,
        'receiver_name': receiverName,
        'content': content,
        'send_time': DateTime.now().toIso8601String(),
        'is_anonymous': _isAnonymous,
        'target_school': _selectedSchool,
        'my_school': _mySchool,
        'receiver_class': _selectedClassName,
      })
          .select()
          .single();
      _showSuccessSnackBar('信件发送成功');
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      _showErrorSnackBar('发送失败');
    } catch (e) {
      _showErrorSnackBar('发送失败');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 模糊搜索
  Future<void> _searchUsers() async {
    final stopwatch = Stopwatch()..start();
    try {
      setState(() {
        _isSearching = true;
      });
      final name = _receiverNameController.text.trim();

      if (name.isEmpty) {
        setState(() {
          _searchResults = [];
          _showNoResultTip = false;
        });
        return;
      }

      final queryBuilder = Supabase.instance.client
          .from('students')
          .select('''
            id,
            name,
            class_name,
            school
           ''')
          .ilike('name', '%$name%')
          .limit(20);


      final response = await queryBuilder
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
        _showNoResultTip = _searchResults.isEmpty;
      });

    } on PostgrestException catch (e) {
      _handleSearchError(e);
      setState(() {
        _showNoResultTip = true;
      });
    } on TimeoutException catch (e) {
      _handleSearchError('查询超时，请重试');
      setState(() {
        _showNoResultTip = true;
      });
    }  catch (e) {
      _handleSearchError(e);
      setState(() {
        _showNoResultTip = true;
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
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
    final currentSearchConditions = _receiverNameController.text.trim();
    if (currentSearchConditions == _lastSearchConditions) {
      return;
    }
    _showNoResultTip = true;
    _lastSearchConditions = currentSearchConditions;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _searchUsers);
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

  void _handleSearchResultTap(Map<String, dynamic> user) {
    setState(() {
      _isSearchResultSelected = true;
      _selectedSearchResult = user;
      _receiverNameController.text = user['name'];
      _schoolController.text = user['school'];
      _showNoResultTip = false;
      _selectedSchool = user['school'];

      final district = schoolList.entries
          .firstWhere((element) => element.value.contains(user['school']))
          .key;
      _selectedDistrict = district;
      _isSpecificClass = true;
      _selectedClassName = user['class_name'];
      _searchResults = [];
    });
  }

  void _cancelSearchResult() {
    setState(() {
      _isSearchResultSelected = false;
      _selectedSearchResult = null;
      _receiverNameController.clear();
      _schoolController.clear();
      _selectedSchool = null;
      _selectedDistrict = null;
      _selectedClassName = null;
      _selectedClassNumber = null;
      _selectedGrade = null;
      _showNoResultTip = true;
      _isSpecificClass = false;
    });
  }

  Future<void> _openAIAssistedWriting({String? initialText, AiAssistanceMode mode = AiAssistanceMode.generate}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIAssistedWritingScreen(initialText: initialText, mode: mode),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        _contentController.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    final aiButtonText = _contentController.text.isEmpty ? 'AI 协作' : 'AI 润色';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: GlobalAppBar(title: '发送信件', showBackButton: true, actions: []),
      ),
      body: Material(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _receiverNameController,
                          enabled: !_isSearchResultSelected,
                          decoration: _inputDecoration(
                            labelText: '收件人姓名',
                            hintText: '请输入收件人姓名',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入收件人姓名';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            if (!_isSearchResultSelected) {
                              _debounceSearch();
                            }
                          },
                        ),
                      ),
                      InkWell(
                        onTap: _debounceSearch,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.search, color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ... (之前代码 - 搜索结果、提示等)
                  if (_searchResults.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const itemHeight = 52.0;
                        const maxListHeight = 200.0;
                        double calculatedHeight;

                        if (_searchResults.length == 1) {
                          calculatedHeight = itemHeight + 10;
                        } else {
                          calculatedHeight = _searchResults.length * itemHeight > maxListHeight
                              ? maxListHeight
                              : _searchResults.length * itemHeight;
                        }

                        return Container(
                          height: calculatedHeight,
                          constraints: const BoxConstraints(maxHeight: maxListHeight),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 0,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return InkWell(
                                onTap: (){
                                  _handleSearchResultTap(user);
                                },
                                child:  ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 18,
                                    child: Text(
                                      user['name'] != null && user['name'] is String && user['name'].isNotEmpty
                                          ? user['name'][0]
                                          : '',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  title:  Text.rich(user['highlightedName'], style: const TextStyle(fontSize: 16)),
                                  subtitle: Text.rich(user['highlightedSubtitle'], style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    )
                  else if (_receiverNameController.text.isNotEmpty && !_isSearching && _showNoResultTip)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 0,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading: Icon(Icons.info_outline, color: Colors.black87),
                        title: Text('未找到匹配用户', style: TextStyle(color: Colors.black87)),
                        subtitle: Text('信件将暂存服务器，当对方注册时会自动送达', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isSearchResultSelected ? 1.0 : 0.0,
                    child: _isSearchResultSelected
                        ? Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12, top: 8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading:  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                        title:  Text(
                          '您正在使用服务器返回的信息发送',
                          style: TextStyle(color:Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontFamily: 'MiSans'),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '收件人: ${_selectedSearchResult!['name']}',
                              style:  TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            Text(
                              '学校: ${_selectedSearchResult!['school']}',
                              style:  TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            Text(
                              '班级: $_selectedClassName',
                              style:  TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                            )
                          ],
                        ),
                      ),
                    )
                        : Container(),
                  ),
                  if (_isSearchResultSelected)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _cancelSearchResult,
                        child: Text('取消选择', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    ),
                  if (!_isSearchResultSelected)
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration(
                            labelText: '目标区',
                            hintText: '请选择目标区',
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
                              _selectedClassName = null;
                              _isSpecificClass = false;
                              _showNoResultTip = false;
                              _selectedClassNumber = null;
                              _selectedGrade = null;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请选择目标区';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration(
                            labelText: '目标学校',
                            hintText: '请选择目标学校',
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
                              _showNoResultTip = false;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请选择目标学校';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (!_isSearchResultSelected)
                    Row(
                      children: [
                        Checkbox(
                          value: _isSpecificClass,
                          onChanged: (value) {
                            setState(() {
                              _isSpecificClass = value!;
                              if (!_isSpecificClass){
                                _selectedClassName = null;
                                _selectedClassNumber = null;
                                _selectedGrade = null;
                              }
                            });
                          },
                        ),
                        Text('匿名发送', style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
                      ],
                    ),
                  const SizedBox(height: 12), // AI 按钮放置在匿名发送下面

                  // 添加：信件内容输入框
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
                    onChanged: (_) { // 添加 onChanged 回调，更新按钮文字
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12), // 添加信件内容后，添加与AI按钮之间的间距

                  // 修改：AI 助手按钮样式
                  ElevatedButton(
                    onPressed: () {
                      _openAIAssistedWriting(
                        initialText: _contentController.text,
                        mode: _contentController.text.isEmpty ? AiAssistanceMode.generate : AiAssistanceMode.polish,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface, // 白色背景
                      foregroundColor: theme.colorScheme.primary, // 蓝色文字
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24), // 调整 padding
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.primary)), // 圆角边框和蓝色边框
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), // 设置文字样式
                      minimumSize: const Size(double.infinity, 40), // 修改：按钮最小尺寸
                    ),
                    child: Text(aiButtonText),
                  ),

                  const SizedBox(height: 20),
                  // ** 恢复：发送按钮代码 **
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : _isSearchResultSelected
                        ? _sendLetterWithSearchResult
                        : _sendLetter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 50), // 修改：发送按钮最小尺寸
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                        : const Text('发送', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: Colors.grey[600]),
      hintStyle: TextStyle(color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  TextFormField buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    int? maxLines,
    String? Function(String?)? validator, required Null Function(dynamic _) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(
        labelText: labelText,
        hintText: hintText,
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
      decoration: _inputDecoration(
        labelText: labelText,
        hintText: hintText,
      ),
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      borderRadius: BorderRadius.circular(12),
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