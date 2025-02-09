import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'school_data.dart';
import 'global_appbar.dart';
import 'ai_assisted_writing_screen.dart';

class SendLetterScreen extends StatefulWidget {
  const SendLetterScreen({Key? key}) : super(key: key);

  @override
  _SendLetterScreenState createState() => _SendLetterScreenState();
}

class _SendLetterScreenState extends State<SendLetterScreen>
    with SingleTickerProviderStateMixin {
  // 添加 SingleTickerProviderStateMixin

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

  // 新增：动画控制器
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadMySchoolAndName();

    // 初始化动画控制器
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
        _animationController.reverse(); // 收起
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
        final studentData =
            await _fetchStudentData(rememberedId, rememberedName);
        if (studentData != null) {
          setState(() {
            _mySchool = studentData['school'];
            _senderName = studentData['name'];
          });
        }
      } catch (e) {
        // 可以选择在这里处理错误，例如显示一个提示
        print("Error loading school and name: $e"); // 打印错误信息
      }
    }
  }

  Future<void> _sendLetterWithSearchResult() async {
    if (!_formKey.currentState!.validate() || _selectedSchool == null) {
      _showErrorSnackBar('请选择目标学校，并填写内容');
      return;
    }
    // 移除对 _selectedClassName 的检查，允许发送给搜索结果中的用户
    await _sendLetter();
  }

  Future<void> _sendLetter() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 不需要检查 _selectedSchool 是否为空，因为如果选择了搜索结果，_selectedSchool 会被赋值

    if (!_isSearchResultSelected &&
        (_selectedClassName == null || _selectedClassName!.isEmpty)) {
      final confirmSend = await _showConfirmationDialog();
      if (!confirmSend) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id; // 使用 Supabase Auth 获取 currentUserId
      if (currentUserId == null) {
        _showErrorSnackBar('用户未登录，无法发送信件');
        return;
      }

      final prefs =
          await SharedPreferences.getInstance(); // sender_name 暂时保持从 SharedPreferences 获取
      final String? currentUserName = prefs.getString('rememberedName');
      final senderName = currentUserName ?? '';

      final receiverName = _receiverNameController.text.trim();
      final content = _contentController.text.trim();

      // 使用 _selectedSchool，如果选择了搜索结果，它会被赋值
      final targetSchool = _selectedSchool;
      final String? receiverClass = _isSearchResultSelected
          ? _selectedSearchResult!['class_name']
          : _selectedClassName;

      final letter = await Supabase.instance.client.from('letters').insert({
        'sender_id': currentUserId,
        'sender_name': _isAnonymous ? "匿名" : senderName, // 根据 _isAnonymous 决定是否匿名
        'receiver_name': receiverName,
        'content': content,
        'send_time': DateTime.now().toIso8601String(),
        'is_anonymous': _isAnonymous, // 添加 is_anonymous 字段
        'target_school': targetSchool,
        'my_school': _mySchool,
        'receiver_class': receiverClass,
      }).select().single();

      _showSuccessSnackBar('信件发送成功');
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      _showErrorSnackBar('发送失败: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('发送失败: $e');
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
      //如果搜索框为空, 则收起列表, 并清空之前的结果
      if (name.isEmpty) {
        _animationController.reverse(); // 收起列表
        setState(() {
          _searchResults = [];
          _showNoResultTip = false;
        });
        return;
      }

      // *** 修改：从 public_students 视图查询 ***
      final queryBuilder = Supabase.instance.client
          .from('public_students') // 从视图查询
          .select('''
            name,
            student_id,
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
          return {
            ...user,
            // 使用 student_id 作为 id
            'id': user['student_id'],  // 确保这里使用的是 student_id
            'highlightedName': _highlightMatches(user['name'], highlightQuery),
            'highlightedSubtitle': _highlightMatches(
                '${user['school']} ${user['class_name']} ', highlightQuery),
          };
        }).toList();
        _showNoResultTip = _searchResults.isEmpty;
        if (_searchResults.isNotEmpty) {
          _animationController.forward(); // 展开列表
        } else {
          _animationController.reverse(); //收起列表
        }
      });
    } on PostgrestException catch (e) {
      _handleSearchError(e);
      setState(() {
        _showNoResultTip = true;
        _animationController.reverse(); // 收起列表
      });
    } on TimeoutException catch (e) {
      _handleSearchError('查询超时，请重试');
      setState(() {
        _showNoResultTip = true;
        _animationController.reverse(); // 收起列表
      });
    } catch (e) {
      _handleSearchError(e);
      setState(() {
        _showNoResultTip = true;
        _animationController.reverse(); // 收起列表
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
      stopwatch.stop();
      // print('Search time: ${stopwatch.elapsedMilliseconds} ms');
    }
  }

  // 错误处理
  void _handleSearchError(dynamic e) {
    String message = '搜索失败，请稍后重试';
    if (e is String) {
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

    // 如果查询为空，直接返回原始文本
    if (query.isEmpty) {
      return TextSpan(text: text, style: TextStyle(color: Colors.grey[600]));
    }

    // 使用正则表达式进行不区分大小写的匹配
    final regex = RegExp(RegExp.escape(query), caseSensitive: false);
    final matches = regex.allMatches(text);

    for (final match in matches) {
      // 添加匹配之前的文本
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: Colors.grey[600]),
        ));
      }

      // 添加匹配的文本，并高亮
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color, // 使用当前主题的文本颜色
            fontWeight: FontWeight.bold),
      ));

      lastIndex = match.end;
    }

    // 添加最后一个匹配项之后的文本
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: Colors.grey[600]),
      ));
    }

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
        ) ??
        false;
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

  // 当点击搜索结果时，更新表单
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
    _animationController.reverse(); // 收起列表
  }

// 取消搜索结果
  void _cancelSearchResult() {
    setState(() {
      _isSearchResultSelected = false;
      _selectedSearchResult = null;
      _receiverNameController.clear();
      _schoolController.clear();
      _selectedSchool = null; // 清空 _selectedSchool
      _selectedDistrict = null;
      _selectedClassName = null;
      _selectedClassNumber = null;
      _selectedGrade = null;
      _showNoResultTip = true; // 显示未找到结果的提示
      _isSpecificClass = false; // 重置为非具体目标
    });
  }

  // AI 写作助手
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
                  // 收件人姓名输入框和搜索按钮
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
                      // 搜索按钮
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSearching
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    )),
                              )
                            : InkWell(
                                key: const ValueKey('search_icon'),
                                onTap: _debounceSearch,
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
                  // 搜索结果列表
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: _animation.value,
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
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  color: _selectedSearchResult == user
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
                                        radius: 18,
                                        child: Text(
                                          user['name'] != null &&
                                                  user['name'] is String &&
                                                  user['name'].isNotEmpty
                                              ? user['name'][0]
                                              : '',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
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
                            .shrink(), //  搜索结果为空时, AnimatedBuilder 的 child 是 SizedBox.shrink()
                  ),

                  // “未找到结果”提示 (放在 AnimatedBuilder 之外)
                  if (_receiverNameController.text.isNotEmpty &&
                      !_isSearching &&
                      _showNoResultTip)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showNoResultTip ? 1.0 : 0.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
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
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ),

                  // 搜索结果确认信息
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
                                    fontFamily: 'MiSans'),
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
                      child: AnimatedOpacity(
                        // 添加动画
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
                          items: schoolList.keys
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
                              ? schoolList[_selectedDistrict]
                                  ?.map((school) => DropdownMenuItem(
                                        value: school,
                                        child: Text(school),
                                      ))
                                  .toList()
                              : [],
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
                            ]
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildDropdownButtonFormField<String>(
                            labelText: '班级',
                            hintText: '请选择班级',
                            value: _selectedClassNumber,
                            items: List.generate(50, (index) => index + 1)
                                .map((classNum) => DropdownMenuItem(
                                      value: '$classNum班', // 将班级数字转为字符串
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
                    onChanged: (_) {
                      // 添加 onChanged 回调，更新按钮文字
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12), // 匿名和 AI 按钮之间的间距

                  // 修改：AI 助手按钮样式
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
                          theme.colorScheme.surface, // 白色/浅色 背景, 和主题一致
                      foregroundColor:
                          theme.colorScheme.primary, // 蓝色文字, 和主题一致
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 24), // 调整 padding
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: theme.colorScheme
                                  .primary)), // 圆角边框和蓝色边框, 和主题一致
                      textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500), // 设置文字样式
                      minimumSize:
                          const Size(double.infinity, 40), // 修改：按钮最小尺寸
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize:
                          const Size(double.infinity, 50), // 修改：发送按钮最小尺寸
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
      labelStyle: TextStyle(color: Colors.grey[600]),
      hintStyle: TextStyle(color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none, // 移除默认边框
      ),
      focusedBorder: OutlineInputBorder(
        // 设置焦点边框样式
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );
  }

  // 简化后的 buildTextFormField
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

  // 简化后的 buildDropdownButtonFormField
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

  // *** 修改：从 public_students 视图查询 ***
  Future<Map<String, dynamic>?> _fetchStudentData(
      String studentId, String name) async {
    final query = Supabase.instance.client
        .from('public_students') // 从视图查询
        .select('name, school, student_id') // 只选择需要的列
        .eq('student_id', studentId)
        .eq('name', name);
    final response = await query;
    if (response.isEmpty) {
      return null;
    }
    return response[0];
  }
}