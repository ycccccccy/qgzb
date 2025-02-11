import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'school_data.dart'; // 假设你有这个文件
import 'global_appbar.dart';
import 'ai_assisted_writing_screen.dart';
import 'api_service.dart';
import 'models.dart';

class SendLetterScreen extends StatefulWidget {
  const SendLetterScreen({Key? key}) : super(key: key);

  @override
  _SendLetterScreenState createState() => _SendLetterScreenState();
}

class _SendLetterScreenState extends State<SendLetterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController(); // 用于显示学校
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  bool _isAnonymous = false;
  String? _selectedDistrict;
  String? _selectedSchool;
  String? _mySchool;
  String? _selectedGrade;
  String? _selectedClassNumber;
  String? _selectedClassName;
  bool _isSpecificClass = false;  // 是否指定了具体班级
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  String _lastSearchConditions = ''; // 记录上一次搜索的条件
  bool _showNoResultTip = false;    // 是否显示“未找到结果”提示
  bool _isSearchResultSelected = false; // 是否选择了搜索结果
  Map<String, dynamic>? _selectedSearchResult; // 保存选择的搜索结果

  late AnimationController _animationController; // 动画控制器
  late Animation<double> _animation; // 动画

  final _apiService = ApiService(); // 使用 ApiService

  @override
  void initState() {
    super.initState();
    _loadMySchoolAndName(); // 加载用户的学校和姓名

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 监听搜索框变化, 如果从有内容到无内容, 则收起列表
    _receiverNameController.addListener(() {
      if (_receiverNameController.text.isEmpty) {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _schoolController.dispose();
    _contentController.dispose();
    _debounceTimer?.cancel();
    _animationController.dispose(); // 释放动画控制器
    super.dispose();
  }

    // 更新 _selectedClassName
  void _updateClassValue() {
    setState(() {
      if (_selectedGrade != null && _selectedClassNumber != null) {
         _selectedClassName = '$_selectedGrade$_selectedClassNumber班';
      } else {
        _selectedClassName = null;
      }
    });
  }

// 加载用户学校和姓名
Future<void> _loadMySchoolAndName() async {
  final prefs = await SharedPreferences.getInstance();
  final String? rememberedId = prefs.getString('rememberedId');
  final String? rememberedName = prefs.getString('rememberedName');

  if (rememberedId != null && rememberedName != null) {
    try {
      final studentData =
          await _apiService.fetchStudentData(rememberedId, rememberedName);
      if (studentData != null) {
        setState(() {
          _mySchool = studentData['school'];
        });
      }
    } catch (e) {
      print("Error loading school and name: $e");
      if (mounted) {
        _showErrorSnackBar(e.toString()); // 显示错误
      }
    }
  }
}


  Future<void> _sendLetterWithSearchResult() async {
    if (!_formKey.currentState!.validate() || _selectedSearchResult == null) { // 改为检查 _selectedSearchResult
      _showErrorSnackBar('请选择收件人'); // 更准确的提示
      return;
    }
    await _sendLetter();
  }

  Future<void> _sendLetter() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 如果没有选择搜索结果 且 没有选择具体班级，则显示确认对话框
    if (!_isSearchResultSelected &&
        (_selectedClassName == null || _selectedClassName!.isEmpty)) {
          final confirmSend = await _showConfirmationDialog();
          if (!confirmSend) {
            return; // 用户取消发送
          }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? currentUserName = prefs.getString('rememberedName');
      final senderName = currentUserName ?? ''; // 如果为空，则使用空字符串

      // final receiverName = _receiverNameController.text.trim(); // 不再需要，从 _selectedSearchResult 或表单获取
      final content = _contentController.text.trim();

    // 根据是否选择了搜索结果，构造不同的 Letter 对象
      Letter letter;
      if (_isSearchResultSelected) {
      // 从搜索结果构造 Letter
        letter = Letter(
          receiverName: _selectedSearchResult!['name'],
          receiverClass: _selectedSearchResult!['class_name'] ?? '', // 搜索结果中的班级
          content: content,
          isAnonymous: _isAnonymous.toString(),
          mySchool: _mySchool ?? '',
          targetSchool: _selectedSearchResult!['school'] ?? '', // 搜索结果中的学校
          senderName: _isAnonymous ? "匿名" : senderName,
        );
      } else {
      // 从表单构造 Letter
        letter = Letter(
          receiverName: _receiverNameController.text.trim(),
          receiverClass: _selectedClassName ?? '',  // 可能为空
          content: content,
          isAnonymous: _isAnonymous.toString(),
          mySchool: _mySchool ?? '',
          targetSchool: _selectedSchool ?? '', // 从表单获取
          senderName: _isAnonymous ? "匿名" : senderName,
        );
      }

      await _apiService.createLetter(letter);

      _showSuccessSnackBar('信件发送成功');
      Navigator.pop(context); // 发送成功后，返回上一页
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUsers() async {
    setState(() {
      _isSearching = true;
      _showNoResultTip = false; // 开始搜索时，隐藏“未找到结果”
    });

    final name = _receiverNameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showNoResultTip = false;
        _animationController.reverse(); // 收起列表
      });
      return;
    }

    try {
      final response = await _apiService.searchUsers(name);

      // 高亮匹配的文本
      final highlightQuery = name.toLowerCase();
      final List<Map<String, dynamic>> searchResults = response.map((user) {
        return {
          ...user,
          'id': user['student_id'],
          'highlightedName': _highlightMatches(user['name'], highlightQuery),
          'highlightedSubtitle': _highlightMatches(
              '${user['school']} ${user['class_name']}', highlightQuery),
        };
      }).toList();

      setState(() {
        _searchResults = searchResults;
        _isSearching = false;
        _showNoResultTip =
            _searchResults.isEmpty; // 只有在搜索完成且结果为空时才显示
        if (_searchResults.isNotEmpty) {
          _animationController.forward(); // 展开列表
        } else {
          _animationController.reverse(); // 收起列表
        }
      });
    } catch (e) {
      _handleSearchError(e); // 统一的错误处理
      setState(() {
        _isSearching = false;
        _showNoResultTip = true;
        _animationController.reverse(); // 收起列表
      });
    }
  }

   void _handleSearchError(dynamic e) {
    String message = '搜索失败，请稍后重试';
    if (e is String) {
      message = e;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // 防抖处理 (限制搜索频率)
  void _debounceSearch() {
    final currentSearchConditions = _receiverNameController.text.trim();
    // 如果搜索条件没有变化，则不执行搜索
    if (currentSearchConditions == _lastSearchConditions) {
      return;
    }
     _showNoResultTip = true;
    _lastSearchConditions = currentSearchConditions; // 更新搜索条件

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _searchUsers);
  }

  // 高亮匹配的文本
  TextSpan _highlightMatches(String text, String query) {
    final spans = <TextSpan>[];
    int lastIndex = 0;

    if (query.isEmpty) {
      return TextSpan(text: text, style: TextStyle(color: Colors.grey[600]));
    }

    final regex = RegExp(RegExp.escape(query), caseSensitive: false);
    final matches = regex.allMatches(text);

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: Colors.grey[600]),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.bold),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: Colors.grey[600]),
      ));
    }

    return TextSpan(children: spans);
  }

  // 确认模糊发送对话框
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
        ) ??
        false; // 如果对话框被取消，返回 false
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // 处理搜索结果点击
  void _handleSearchResultTap(Map<String, dynamic> user) {
    setState(() {
      _isSearchResultSelected = true;
      _selectedSearchResult = user; // 保存选择的搜索结果

      // 将搜索结果中的信息填充到输入框
      _receiverNameController.text = user['name'];
      _schoolController.text = user['school'];

       // 找到 school 对应的 district
      final district = schoolList.entries.firstWhere((element) => element.value.contains(user['school'])).key;
      _selectedDistrict = district;

      _showNoResultTip = false;
      _selectedSchool = user['school']; // 设置 _selectedSchool
      _isSpecificClass = true;
      _selectedClassName = user['class_name']; // 设置班级名称, 即使用户没有选择年级和班级

      _searchResults = []; // 清空搜索结果
    });
    _animationController.reverse(); // 收起列表
  }

  // 取消搜索结果选择
  void _cancelSearchResult() {
    setState(() {
      _isSearchResultSelected = false;
      _selectedSearchResult = null;
      _receiverNameController.clear();
      _schoolController.clear();
      _selectedSchool = null; // 清空 _selectedSchool
      _selectedDistrict = null; // 清空区
      _selectedClassName = null;
      _selectedClassNumber = null;
      _selectedGrade = null;
      _showNoResultTip =
          true; // 显示未找到结果 (只有在输入框不为空的情况下)
      _isSpecificClass = false; // 重置为非具体目标
    });
  }

  // 打开 AI 写作助手
  Future<void> _openAIAssistedWriting(
      {String? initialText,
      AiAssistanceMode mode = AiAssistanceMode.generate}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AIAssistedWritingScreen(initialText: initialText, mode: mode),
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
    final aiButtonText =
        _contentController.text.isEmpty ? 'AI 协作' : 'AI 润色';

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
                  // 收件人姓名输入框 和 搜索按钮
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _receiverNameController,
                          enabled:
                              !_isSearchResultSelected, // 如果选择了搜索结果，禁用输入框
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
                            // 如果没有选择搜索结果，则执行搜索
                            if (!_isSearchResultSelected) {
                              _debounceSearch(); // 防抖搜索
                            }
                          },
                        ),
                      ),
                      // 搜索按钮 (加载时显示指示器)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSearching
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 3),
                                ),
                              )
                            : InkWell(
                                key: const ValueKey(
                                    'search_icon'), // 为了动画效果，添加 key
                                onTap:
                                    _debounceSearch, // 点击时触发 _debounceSearch (防抖)
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(Icons.search,
                                      color: theme.colorScheme.primary),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 搜索结果列表 (使用 AnimatedBuilder 实现动画)
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: _animation.value, // 控制高度
                          child: child,
                        ),
                      );
                    },
                    child: _searchResults.isNotEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 0,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2), // 阴影稍微向下偏移
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero, // 移除默认 padding
                              shrinkWrap:
                                  true, // 让 ListView 根据内容自适应高度 (重要，否则可能无法滚动)
                              physics:
                                  const NeverScrollableScrollPhysics(), // 禁止 ListView 滚动
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  color: _selectedSearchResult ==
                                          user // 高亮选中的结果
                                      ? Colors.grey.withOpacity(0.2)
                                      : Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _handleSearchResultTap(user);
                                    },
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                      leading: CircleAvatar(
                                        radius: 18, // 圆形头像
                                        child: Text(
                                          // 显示名字的第一个字
                                          user['name'] != null &&
                                                  user['name'] is String &&
                                                  user['name'].isNotEmpty
                                              ? user['name'][0]
                                              : '',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      // 使用 Text.rich 显示高亮文本
                                      title: Text.rich(user['highlightedName'],
                                          style:
                                              const TextStyle(fontSize: 16)),
                                      subtitle: Text.rich(
                                          user['highlightedSubtitle'],
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600])),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox
                            .shrink(), // 如果搜索结果为空，则不显示任何内容 (高度为 0)
                  ),

                  // “未找到结果”提示 (放在 AnimatedBuilder 之外)
                  if (_receiverNameController.text.isNotEmpty &&
                      !_isSearching &&
                      _showNoResultTip)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showNoResultTip ? 1.0 : 0.0, // 控制透明度
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8), // 和其他组件的间距
                        decoration: BoxDecoration(
                          color: Colors.amber[100], // 使用浅黄色背景
                          borderRadius: BorderRadius.circular(12),
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
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Icon(Icons.info_outline, color: Colors.black87),
                          title: Text('未找到匹配用户',
                              style: TextStyle(color: Colors.black87)),
                          subtitle: Text(
                              '信件将暂存服务器，当对方注册时会自动送达',
                              style: TextStyle(color: Colors.grey)), // 提示信息
                        ),
                      ),
                    ),

                  // 搜索结果确认信息 (使用 AnimatedOpacity 实现动画)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isSearchResultSelected ? 1.0 : 0.0,
                    child: _isSearchResultSelected
                        ? Card(
                            elevation: 1, // 稍微降低阴影
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 12, top: 8),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest, // 使用更高级别的表面颜色
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              leading: Icon(Icons.info_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary), // 使用主题的主要颜色
                              title: Text(
                                '您正在使用服务器返回的信息发送',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'MiSans'), // 可以自定义字体
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '收件人: ${_selectedSearchResult!['name']}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                  ),
                                  Text(
                                    '学校: ${_selectedSearchResult!['school']}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                  ),
                                  Text(
                                    // 使用 _selectedClassName
                                    '班级: $_selectedClassName',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                  )
                                ],
                              ),
                            ),
                          )
                        : Container(), // 如果不是搜索结果，则不显示任何内容
                  ),
                  // 取消搜索结果的按钮
                  if (_isSearchResultSelected)
                    Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity( // 添加动画
                        duration: const Duration(milliseconds: 200),
                        opacity: _isSearchResultSelected ? 1.0 : 0.0,
                        child: TextButton(
                          onPressed:
                              _cancelSearchResult, // 点击时取消选择搜索结果,并清空输入
                          child: Text('取消选择',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ),
                      ),
                    ),
                  // 如果没有选择搜索结果，则显示区、学校、班级的选择
                  if (!_isSearchResultSelected)
                    Column(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: _inputDecoration(
                            labelText: '目标区',
                            hintText: '请选择目标区',
                          ),
                          value: _selectedDistrict,
                          items: schoolList.keys // 从 school_data.dart 获取
                              .map((district) => DropdownMenuItem(
                                    value: district,
                                    child: Text(district),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDistrict = value;
                              _selectedSchool = null; // 重置学校
                              _selectedClassName = null; // 重置班级
                              _isSpecificClass = false; // 重置为非具体班级
                              _showNoResultTip =
                                  false; // 选择区域后，隐藏“未找到结果”提示
                              _selectedClassNumber =
                                  null; // 当区更改时，重置班级数字
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
                              ? schoolList[_selectedDistrict]
                                  ?.map((school) => DropdownMenuItem(
                                        value: school,
                                        child: Text(school),
                                      ))
                                  .toList()
                              : [], // 如果没有选择区，则显示空列表
                          onChanged: (value) {
                            setState(() {
                              _selectedSchool = value;
                              // _selectedClassName = null; // 选择学校后，不清空班级
                              _showNoResultTip =
                                  false; // 选择学校后，隐藏“未找到结果”提示
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

                  // 年级和班级选择, 只有在选择了区和学校，且没有选择搜索结果时才显示
                  if (!_isSearchResultSelected)
                    Row(
                      children: [
                        Checkbox(
                          value: _isSpecificClass,
                          onChanged: (value) {
                            setState(() {
                              _isSpecificClass = value!;
                              // 如果取消选择具体班级，则清空班级信息
                              if (!_isSpecificClass) {
                                _selectedClassName = null;
                                _selectedClassNumber = null;
                                _selectedGrade = null;
                              }
                            });
                          },
                        ),
                        Text('指定具体班级',
                            style: TextStyle(
                                fontSize: 16,
                                color: theme.colorScheme.onSurface)),
                      ],
                    ),

                  // 年级和班级选择 (两个 Dropdown，水平排列)
                  if (_isSpecificClass && !_isSearchResultSelected)
                    Row(
                      children: [
                        Expanded(
                          child: buildDropdownButtonFormField<String>(
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
                            ] // 年级列表
                                .map((grade) => DropdownMenuItem(
                                      value: grade,
                                      child: Text(grade),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedGrade = value;
                                _selectedClassNumber =
                                    null; // 当年级更改时，重置班级数字
                                _updateClassValue(); // 更新组合班级名称
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
                        const SizedBox(width: 16), // 年级和班级之间的间距
                        Expanded(
                          child: buildDropdownButtonFormField<String>(
                            labelText: '班级',
                            hintText: '请选择班级',
                            value: _selectedClassNumber,
                            items: List.generate(50, (index) => index + 1)
                                .map((classNum) => DropdownMenuItem(
                                      value:
                                          '$classNum班', // 将班级数字转为字符串, 和_selectedClassName 统一类型
                                      child: Text('$classNum班'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClassNumber = value;
                                _updateClassValue(); // 更新组合班级名称
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请选择班级';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // 信件内容输入框
                  buildTextFormField(
                    controller: _contentController,
                    labelText: '信件内容',
                    hintText: '请输入信件内容',
                    maxLines: 10, // 多行文本框
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入信件内容';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      // 添加 onChanged 回调，更新按钮文字
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  // 匿名发送
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
                      Text('匿名发送',
                          style: TextStyle(
                              fontSize: 16, color: theme.colorScheme.onSurface)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // AI 助手按钮 (使用 ElevatedButton)
                  ElevatedButton(
                    onPressed: () {
                      _openAIAssistedWriting(
                        initialText: _contentController.text,
                        mode: _contentController.text.isEmpty
                            ? AiAssistanceMode.generate
                            : AiAssistanceMode.polish,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.surface, // 白色/浅色 背景
                      foregroundColor:
                          theme.colorScheme.primary, // 蓝色文字
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: theme.colorScheme
                                  .primary)), // 圆角边框和蓝色边框
                      textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500), // 设置文字样式
                      minimumSize:
                          const Size(double.infinity, 40), // 最小宽度为屏幕宽度
                    ),
                    child: Text(aiButtonText),
                  ),

                  const SizedBox(height: 20),

                  // 发送按钮 (使用 ElevatedButton)
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null // 如果正在加载，禁用按钮
                        : _isSearchResultSelected
                            ? _sendLetterWithSearchResult // 如果选择了搜索结果，发送到搜索结果
                            : _sendLetter, // 否则，正常发送
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary, // 蓝色背景
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                                                        width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : const Text('发送',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 抽取 InputDecoration
  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest, // 使用更高级别的表面颜色
      labelStyle: TextStyle(color: Colors.grey[600]), // 标签文本颜色
      hintStyle: TextStyle(color: Colors.grey[400]), // 提示文本颜色
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // 移除默认边框,
      ),
      focusedBorder: OutlineInputBorder(
        // 设置焦点边框样式
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  // 抽取 TextFormField
  TextFormField buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    int? maxLines,
    String? Function(String?)? validator,
    required void Function(String) onChanged, // 添加 onChanged 回调
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(
        labelText: labelText,
        hintText: hintText,
      ),
      validator: validator,
      onChanged: onChanged, // 使用 onChanged
    );
  }

  // 抽取 DropdownButtonFormField
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
      borderRadius:
          BorderRadius.circular(12), // 添加圆角
    );
  }
}