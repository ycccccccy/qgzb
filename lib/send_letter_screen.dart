import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'school_data.dart';
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
  final _receiverNameController = TextEditingController();
  final _schoolController =
      TextEditingController(); // 用于显示学校, 不参与搜索逻辑，只用于展示
  final _contentController = TextEditingController();

  bool _isLoading = false;
  bool _isAnonymous = false;
  String? _selectedDistrict;
  String? _selectedSchool;
  String? _mySchool;
  String? _selectedGrade;
  String? _selectedClassNumber;
  String? _selectedClassName;
  bool _isSpecificClass = false;
  List<Map<String, dynamic>> _searchResults =
      const []; // 初始为空列表, 使用 const 提高性能
  bool _isSearching = false;
  Timer? _debounceTimer;
  String _lastSearchQuery = ''; // 记录上一次搜索的关键词, 而不是全部条件
  bool _showNoResultTip = false;
  bool _isSearchResultSelected = false;
  Map<String, dynamic>? _selectedSearchResult;

  late final AnimationController _animationController; // 使用 late final
  late final Animation<double> _animation;

  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadMySchoolAndName();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _receiverNameController.addListener(_onReceiverNameChanged); // 使用单独的方法
  }

  @override
  void dispose() {
    _receiverNameController.removeListener(
        _onReceiverNameChanged); // 移除监听器, 防止内存泄漏
    _receiverNameController.dispose();
    _schoolController.dispose();
    _contentController.dispose();
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // 收件人输入框变化监听
  void _onReceiverNameChanged() {
    if (_receiverNameController.text.isEmpty) {
      if (_searchResults.isNotEmpty) {
        setState(() {
          _searchResults =
              const []; // 清空搜索结果, 使用 const 避免不必要的重建
          _showNoResultTip = false;
        });
      }
      _animationController.reverse();
    } else {
      // 如果没有选择搜索结果，则执行搜索
      if (!_isSearchResultSelected) {
        _debounceSearch();
      }
    }
  }

  void _updateClassValue() {
    if (_selectedGrade != null && _selectedClassNumber != null) {
      // 使用 ??= 简化赋值
      _selectedClassName ??= '$_selectedGrade$_selectedClassNumber班';
    } else {
      _selectedClassName = null;
    }
    // 不需要 setState, 因为 _selectedClassName 的变化只影响 build 方法
  }

  Future<void> _loadMySchoolAndName() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('rememberedId'); // 简化变量名
    final studentName = prefs.getString('rememberedName');

    if (studentId != null && studentName != null) {
      try {
        final data = await _apiService.fetchStudentData(studentId, studentName);
        if (data != null) {
          // 使用 ??= 简化赋值, 只在 _mySchool 为 null 时赋值
          _mySchool ??= data['school'];
          if (mounted) setState(() {}); // 确保组件已挂载
        }
      } catch (e) {
        print("Error loading school and name: $e");
        if (mounted) {
          _showErrorSnackBar(e.toString());
        }
      }
    }
  }

  Future<void> _sendLetter() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 简化逻辑: 如果没有选择搜索结果且没有指定具体班级, 则显示确认对话框
    if (!_isSearchResultSelected && (_selectedClassName?.isEmpty ?? true)) {
      final confirm = await _showConfirmationDialog();
      if (!confirm) return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final senderName = prefs.getString('rememberedName') ?? '';

      // 根据是否选择了搜索结果，构造不同的 Letter 对象
      final letter = _isSearchResultSelected
          ? Letter(
              receiverName: _selectedSearchResult!['name'],
              receiverClass: _selectedSearchResult!['class_name'] ?? '',
              content: _contentController.text.trim(),
              isAnonymous: _isAnonymous.toString(),
              mySchool: _mySchool ?? '',
              targetSchool: _selectedSearchResult!['school'] ?? '',
              senderName: _isAnonymous ? "匿名" : senderName,
            )
          : Letter(
              receiverName: _receiverNameController.text.trim(),
              receiverClass: _selectedClassName ?? '',
              content: _contentController.text.trim(),
              isAnonymous: _isAnonymous.toString(),
              mySchool: _mySchool ?? '',
              targetSchool: _selectedSchool ?? '',
              senderName: _isAnonymous ? "匿名" : senderName,
            );

      await _apiService.createLetter(letter);

      if (mounted) {
        _showSuccessSnackBar('信件发送成功');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers() async {
    final query = _receiverNameController.text.trim();

    if (query.isEmpty) {
      // 如果查询为空, 则清空搜索结果, 收起列表, 隐藏提示
      if (_searchResults.isNotEmpty || _showNoResultTip) { // 只有当状态改变时才 setState
        setState(() {
          _searchResults = const [];
          _isSearching = false;
          _showNoResultTip = false;
        });
      }
      _animationController.reverse(); // 确保列表收起
      return;
    }

    // 开始搜索
    setState(() {
      _isSearching = true;
      _showNoResultTip = false; // 开始搜索时，隐藏“未找到结果”
    });

    try {
      final response = await _apiService.searchUsers(query);

      // 高亮匹配的文本
      final List<Map<String, dynamic>> searchResults = response.map((user) {
        return {
          ...user,
          'id': user['student_id'],
          'highlightedName': _highlightMatches(user['name'], query),
          'highlightedSubtitle': _highlightMatches(
              '${user['school']} ${user['class_name']}', query),
        };
      }).toList();

      // 只有当搜索结果或提示状态发生变化时才 setState
      if (!const DeepCollectionEquality()
              .equals(_searchResults, searchResults) ||
          _showNoResultTip != searchResults.isEmpty) {
        setState(() {
          _searchResults = searchResults;
          _isSearching = false;
          _showNoResultTip = _searchResults.isEmpty;
        });
      }

      // 根据结果展开或收起列表
      if (_searchResults.isNotEmpty) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    } catch (e) {
      _handleSearchError(e); // 统一的错误处理
      if(mounted){
        setState(() {
        _isSearching = false;
        _showNoResultTip = true;
        });
      }
      
      _animationController.reverse();
    }
  }

  // 防抖处理
  void _debounceSearch() {
    final query = _receiverNameController.text.trim();
    // 如果搜索关键词没有变化，则不执行搜索
    if (query == _lastSearchQuery) {
      return;
    }

    _lastSearchQuery = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _searchUsers);
  }

  // 高亮匹配的文本 (使用 TextSpan, 优化性能)
  TextSpan _highlightMatches(String text, String query) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: TextStyle(color: Colors.grey[600]));
    }

    final matches = RegExp(RegExp.escape(query), caseSensitive: false)
        .allMatches(text); // 使用 RegExp 性能更好
    if (matches.isEmpty) {
      return TextSpan(text: text, style: TextStyle(color: Colors.grey[600]));
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

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
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color, // 使用 ?., 避免空指针
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // 使用 context 变量
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
      ),
    );
    return result ?? false; // 如果对话框被取消，返回 false
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _handleSearchError(dynamic e) {
    String message = '搜索失败，请稍后重试';
    if (e is String) {
      message = e;
    }
    if (mounted) {
      _showErrorSnackBar(message);
    }
  }

  void _handleSearchResultTap(Map<String, dynamic> user) {
    setState(() {
      _isSearchResultSelected = true;
      _selectedSearchResult = user;

      _receiverNameController.text = user['name'];
      _schoolController.text = user['school']; // 只更新显示

      final district = schoolList.entries
          .firstWhere((element) => element.value.contains(user['school']))
          .key;
      _selectedDistrict = district;
      _selectedSchool = user['school'];
      _selectedClassName = user['class_name']; // 班级也直接从搜索结果获取
      _isSpecificClass = true; // 标记为选择了具体班级
       _searchResults = const []; // 清空搜索结果

      _showNoResultTip = false; // 选择后隐藏提示
     
    });
     _animationController.reverse(); // 收起列表
  }

  void _cancelSearchResult() {
    setState(() {
      _isSearchResultSelected = false;
      _selectedSearchResult = null;
      _receiverNameController.clear();
      _schoolController.clear(); // 清空学校显示
      _selectedSchool = null;
      _selectedDistrict = null;
      _selectedClassName = null;
      _selectedClassNumber = null;
      _selectedGrade = null;
      _isSpecificClass = false;

      // 如果输入框不为空，显示“未找到结果”提示
      _showNoResultTip = _receiverNameController.text.isNotEmpty;
    });
  }

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
      // 只有当 result 不为空时才 setState
      setState(() {
        _contentController.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFFF7FAFC), //   导航栏颜色
    systemNavigationBarIconBrightness: Brightness.light, //   导航栏图标颜色
  ));
    // 使用 ?? 运算符简化
    final aiButtonText =
        _contentController.text.isEmpty ? 'AI 协作' : 'AI 润色';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC), // 统一背景颜色
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: GlobalAppBar(title: '发送信件', showBackButton: true, actions: []),
      ),
      body: Padding(
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
                        enabled: !_isSearchResultSelected,
                        decoration: _inputDecoration(
                          labelText: '收件人姓名',
                          hintText: '请输入收件人姓名',
                        ),
                        validator: (value) =>
                            value?.trim().isNotEmpty ?? false ? null : '请输入收件人姓名',
                        // onChanged: (value) { // 移除 onChanged, 使用 _onReceiverNameChanged
                        //   _debounceSearch();
                        // },
                      ),
                    ),
                    // 搜索按钮 (加载时显示指示器)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3),
                              ),
                            )
                          : InkWell(
                              key: const ValueKey('search_icon'),
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
                        heightFactor: _animation.value,
                        child: child,
                      ),
                    );
                  },
                  child: _searchResults.isNotEmpty
                      ? _buildSearchResultList() // 抽取方法
                      : const SizedBox.shrink(),
                ),

                // “未找到结果”提示 (放在 AnimatedBuilder 之外)
                if (_receiverNameController.text.isNotEmpty &&
                    !_isSearching &&
                    _showNoResultTip)
                  _buildNoResultTip(), // 抽取方法

                // 搜索结果确认信息
                if (_isSearchResultSelected) _buildSearchResultConfirmation(),

                // 取消搜索结果的按钮
                if (_isSearchResultSelected)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _cancelSearchResult,
                      child: Text(
                        '取消选择',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),

                // 如果没有选择搜索结果，则显示区、学校、班级的选择
                if (!_isSearchResultSelected) _buildLocationSelection(),

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
                              fontSize: 16, color: theme.colorScheme.onSurface)),
                    ],
                  ),

                if (_isSpecificClass && !_isSearchResultSelected)
                  _buildGradeAndClassSelection(), // 抽取方法

                const SizedBox(height: 12),

                buildTextFormField(
                  controller: _contentController,
                  labelText: '信件内容',
                  hintText: '请输入信件内容',
                  maxLines: 10,
                  validator: (value) =>
                      value?.trim().isNotEmpty ?? false ? null : '请输入信件内容',
                  onChanged: (_) {
                    // 更新按钮文字 (只有当内容变化时才触发)
                    if (_contentController.text.isEmpty !=
                        aiButtonText.startsWith('AI 协作')) {
                      setState(() {});
                    }
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

                const SizedBox(height: 12),

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
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.colorScheme.primary)),
                    textStyle:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: Text(aiButtonText),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _isSearchResultSelected
                          ? _sendLetter // 使用 _sendLetter, 简化逻辑
                          : _sendLetter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
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
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 抽取搜索结果列表
  Widget _buildSearchResultList() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
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
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final user = _searchResults[index];
          return Material(
            color: _selectedSearchResult == user
                ? Colors.grey.withOpacity(0.2)
                : Colors.transparent, // 使用 Material 包裹 InkWell, 避免颜色问题
            child: InkWell(
              onTap: () => _handleSearchResultTap(user),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 18,
                  child: Text(
                    user['name']?[0] ?? '', // 使用 ?. 安全访问
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                title: Text.rich(user['highlightedName'],
                    style: const TextStyle(fontSize: 16)),
                subtitle: Text.rich(user['highlightedSubtitle'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ),
            ),
          );
        },
      ),
    );
  }

  // 抽取“未找到结果”提示
  Widget _buildNoResultTip() {
    return AnimatedOpacity(
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Icon(Icons.info_outline, color: Colors.black87),
          title:
              Text('未找到匹配用户', style: TextStyle(color: Colors.black87)),
          subtitle: Text('信件将暂存服务器，当对方注册时会自动送达',
              style: TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }

  // 抽取搜索结果确认信息
  Widget _buildSearchResultConfirmation() {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12, top: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading:
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
        title: Text(
          '您正在使用服务器返回的信息发送',
          style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontFamily: 'MiSans'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '收件人: ${_selectedSearchResult!['name']}', // 使用 ?. 安全访问
              style:
                  TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            ),
            Text(
              '学校: ${_selectedSearchResult!['school']}',
              style:
                  TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            ),
            Text(
              '班级: $_selectedClassName', // 使用 _selectedClassName
              style:
                  TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
            )
          ],
        ),
      ),
    );
  }

  // 抽取地区和学校选择
  Widget _buildLocationSelection() {
    return Column(
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
            // 使用 setState 包裹所有状态更新
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
          validator: (value) => value?.isNotEmpty ?? false ? null : '请选择目标区',
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
              //_selectedClassName = null; //  选择学校后，不清空班级
              _showNoResultTip = false;
            });
          },
          validator: (value) => value?.isNotEmpty ?? false ? null : '请选择目标学校',
        ),
      ],
    );
  }

  // 抽取年级和班级选择
  Widget _buildGradeAndClassSelection() {
    return Row(
      children: [
        Expanded(
          child: buildDropdownButtonFormField<String>(
            labelText: '年级',
            hintText: '请选择年级',
            value: _selectedGrade,
            items: ['初一', '初二', '初三', '高一', '高二', '高三']
                .map((grade) => DropdownMenuItem(
                      value: grade,
                      child: Text(grade),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedGrade = value;
                _selectedClassNumber = null;
                _updateClassValue();
              });
            },
            validator: (value) => value?.isNotEmpty ?? false ? null : '请选择年级',
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
                      value: '$classNum班',
                      child: Text('$classNum班'),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedClassNumber = value;
                _updateClassValue();
              });
            },
            validator: (value) => value?.isNotEmpty ?? false ? null : '请选择班级',
          ),
        ),
      ],
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

  // 抽取 TextFormField
  TextFormField buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    int? maxLines,
    String? Function(String?)? validator,
    required void Function(String) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(
        labelText: labelText,
        hintText: hintText,
      ),
      validator: validator,
      onChanged: onChanged,
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