import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'global_appbar.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'brain_icon_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 应用主题
ThemeData appTheme = ThemeData.light().copyWith(
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.light(
    primary: Colors.blue.shade400,
    secondary: Colors.blueAccent.shade400,
    surface: Colors.white,
    error: Colors.redAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.black87,
    onError: Colors.white,
    primaryContainer: Colors.grey.shade100,
    surfaceContainerHighest: Colors.grey.shade200,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: Colors.black87,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: Colors.black87),
  ),
  cardTheme: CardTheme(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: Colors.grey.shade200,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
);

// AI 辅助模式
enum AiAssistanceMode {
  generate,
  polish,
  write,
}

class AIAssistedWritingScreen extends StatefulWidget {
  final String? initialText;
  final AiAssistanceMode mode;

  const AIAssistedWritingScreen({
    super.key,
    this.initialText,
    this.mode = AiAssistanceMode.generate,
  });

  @override
  _AIAssistedWritingScreenState createState() =>
      _AIAssistedWritingScreenState();
}

class _AIAssistedWritingScreenState extends State<AIAssistedWritingScreen> {
  final _promptController = TextEditingController();
  bool _isLoading = false;
  final List<Map<String, dynamic>> _messages = [];
  String? _errorMessage;
  late AiAssistanceMode _selectedMode;
  StreamSubscription? _streamSubscription;
  List<Map<String, dynamic>> _historyDialogs = [];
  int _dialogIdCounter = 0;

  String _selectedModelId = "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B";

  static const List<Map<String, String>> _availableModels = [
    {
      "id": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B",
      "name": "DeepSeek-R1-Distill-Qwen-7B"
    },
    {"id": "Pro/deepseek-ai/DeepSeek-R1", "name": "DeepSeek-R1"},
    {"id": "deepsleep", "name": "DeepSleep-R1"},
  ];

  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadHistoryDialogs();
    _loadDialogIdCounter();
    _selectedMode = widget.mode;
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _promptController.text = widget.initialText!;
      if (_selectedMode == AiAssistanceMode.generate) {
        _selectedMode = AiAssistanceMode.polish;
      }
      _addMessage("user",
          "请润色以下文本，使其表达更流畅、更生动：${widget.initialText!.replaceAll('"', '')}");
    }
  }

  @override
  void dispose() {
    _saveCurrentDialogToHistory();
    _promptController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _addMessage(String role, String content,
      {String? reasoning, bool isExpanded = true, int? reasoningStartTimeMs, int? reasoningEndTimeMs}) {
    _messages.add({
      "role": role,
      "content": content,
      "reasoning": reasoning,
      "isExpanded": isExpanded,
      "reasoningStartTimeMs": reasoningStartTimeMs,
      "reasoningEndTimeMs": reasoningEndTimeMs,
    });
  }

  // 处理流式响应 (兼容两种格式, 并添加详细日志)
Future<void> _processStreamedResponse(http.StreamedResponse streamedResponse) async {
  String fullResponseContent = "";
  String fullReasoning = "";
  int? reasoningStartTimeMs;
  bool contentStarted = false;
  StringBuffer buffer = StringBuffer();

  _addMessage("assistant", "", reasoning: "", isExpanded: true);
  int tempMessageIndex = _messages.length - 1;

  try {
    _streamSubscription = streamedResponse.stream.transform(utf8.decoder).listen((String chunk) {
      buffer.write(chunk);
      String bufferedString = buffer.toString();

      RegExp exp = RegExp(r"data:\s*(.*?)\n\n");
      Match? match = exp.firstMatch(bufferedString);

      while (match != null) {
        String? jsonStr = match.group(1);
        if (jsonStr == null || jsonStr.isEmpty) {
          bufferedString = bufferedString.substring(match.end);
          buffer.clear();
          buffer.write(bufferedString);
          match = exp.firstMatch(bufferedString);
          continue;
        }

        if (jsonStr.trim() == "[DONE]") {
          _messages[tempMessageIndex]['content'] = fullResponseContent;
          _messages[tempMessageIndex]['reasoning'] =
              fullReasoning.isNotEmpty ? fullReasoning : null;
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        try {
          final responseJson = jsonDecode(jsonStr);

          if (responseJson.containsKey('error')) {
            String errorMessage = responseJson['error'];
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = "AI 响应错误: $errorMessage";
              });
            }
            return;
          }

          // 正确的条件判断：检查 reasoning_content 或 content 是否存在
          if (responseJson.containsKey('reasoning_content') || responseJson.containsKey('content')) {

            // 解析 reasoning_content
            if (responseJson.containsKey('reasoning_content') && responseJson['reasoning_content'] != null) {
              String reasoningChunk = responseJson['reasoning_content'];
              if (reasoningStartTimeMs == null) {
                reasoningStartTimeMs = DateTime.now().millisecondsSinceEpoch;
                _messages[tempMessageIndex]['reasoningStartTimeMs'] = reasoningStartTimeMs;
              }
              fullReasoning += reasoningChunk;
              _messages[tempMessageIndex]['reasoning'] = fullReasoning;
            }

            // 解析 content
            final contentChunk = responseJson['content'];  // 直接从 responseJson 获取
            if (contentChunk != null && !contentStarted) {
              _messages[tempMessageIndex]['reasoningEndTimeMs'] =
                  DateTime.now().millisecondsSinceEpoch;
              contentStarted = true;
            }
            if (contentChunk != null) {
              fullResponseContent += contentChunk;
            }
          } else {
            // 记录意外的 JSON 格式
          }


          // 立即更新 UI
          if (mounted) {
            setState(() {
              _messages[tempMessageIndex]['content'] = fullResponseContent; // 更新内容
               if (responseJson.containsKey(
                  'reasoning_content')) { //如果本次有reasoning_content,就更新UI
                _messages[tempMessageIndex]['reasoning'] = fullReasoning;
              }
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = "AI 响应 JSON 解析错误: $e";
            });
          }
        }

        bufferedString = bufferedString.substring(match.end);
        buffer.clear();
        buffer.write(bufferedString);
        match = exp.firstMatch(bufferedString);
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "AI响应流错误: $error";
        });
      }
    }, onDone: () {
      _messages[tempMessageIndex]['content'] = fullResponseContent;
      _messages[tempMessageIndex]['reasoning'] =
          fullReasoning.isNotEmpty ? fullReasoning : null;
      if (mounted) setState(() => _isLoading = false);
    });
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = "处理AI响应时发生错误: $e";
      });
    }
  }
}

    Future<void> _generateText(AiAssistanceMode mode) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 检查高级模型权限
    if (_selectedModelId == "Pro/deepseek-ai/DeepSeek-R1" &&
        !await _apiService.checkAIAccess()) {
      setState(() {
        _isLoading = false;
        _errorMessage = "请先登录或联系管理员开通 AI 高级版权限";
      });
      return;
    }

    final prompt = _promptController.text.trim();
    _promptController.clear();

    if (prompt.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = switch (mode) {
          AiAssistanceMode.generate => "请输入聊天内容",
          AiAssistanceMode.polish => "请输入需要润色的内容",
          _ => "请输入写作提示"
        };
      });
      return;
    }

    // 根据模式构建 AI prompt
    String aiPrompt = switch (mode) {
      AiAssistanceMode.generate => prompt,
      AiAssistanceMode.polish => "请润色以下文本，使其表达更流畅、更生动：${prompt.replaceAll('"', '')}",
      AiAssistanceMode.write =>
        "请用流畅的语言，以“${prompt.replaceAll('"', '')}”为主题，创作一段文章。请注意，输出内容必须全部为我要求的语言，禁止语言混用",
    };

    _addMessage("user", aiPrompt); // 添加用户消息
    setState(() {}); // 更新 UI

    try {
      if (_selectedModelId == "deepsleep") {
        await _performDeepSleepRequest();
      } else {
        await _performAIRequest(aiPrompt); // 调用修改后的 _performAIRequest
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "请求 AI 服务时发生错误: $e";
        });
      }
    }
  }

  Future<void> _performAIRequest(String aiPrompt) async {
    // 构建消息列表 (只包含 'user' 和 'assistant' 角色的消息)
    final messages = _messages
        .where((message) => message['role'] == 'user' || message['role'] == 'assistant')
        .map((message) => {
              'role': message['role'],
              'content': message['content'],
            })
        .toList();

// 通过 ApiService 调用你的 Flask 后端
    _processStreamedResponse(await _apiService.generateText(
      // 注意这里的 await
      model: _selectedModelId,
      messages: messages, // 传递消息列表
      stream: true, // 使用流式响应
      mode: _selectedMode.toString().split('.').last, // 传递模式
    ));
  }

  Future<void> _performDeepSleepRequest() async {
    await Future.delayed(Duration(seconds: 5 + Random().nextInt(4)));
    if (mounted) {
      _addMessage("assistant", "服务器繁忙，请稍后再试");
      setState(() => _isLoading = false);
    }
  }

// 构建消息气泡 (保持不变)
  Widget _buildMessageBubble(Map<String, dynamic> message, ThemeData theme) {
    final isUser = message['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (message['reasoning'] is String &&
              message['reasoning'].isNotEmpty)
            _buildReasoningTile(message, theme), // 传入 message
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8),
            child: Card(
              color: isUser
                  ? Colors.grey.shade200
                  : theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SelectionArea(
                  child: MarkdownBody(
                    data: message['content'] ?? '',
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// 构建思考过程提示 (保持不变)
  Widget _buildReasoningTile(Map<String, dynamic> message, ThemeData theme) {
    final titleTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade700,
      fontSize: 14,
    );
    final reasoningTextStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 14,
    );

    int thinkingTimeInSeconds = 0; // 存储秒数
    if (message['reasoningStartTimeMs'] != null) {
      final endTimeMs =
          message['reasoningEndTimeMs'] ?? DateTime.now().millisecondsSinceEpoch;
      final durationMs = endTimeMs - message['reasoningStartTimeMs']!;
      thinkingTimeInSeconds =
          Duration(milliseconds: durationMs).inSeconds; // 直接计算秒数
    }

    return InkWell(
      onTap: () {
        setState(() {
          message['isExpanded'] = !message['isExpanded'];
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 垂直提示线
              Padding(
                padding: const EdgeInsets.only(top: 22), // 添加顶部内边距
                child: Container(
                  width: 3, // 更粗的提示线
                  margin: const EdgeInsets.only(right: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 4.0),
                      child: Row(
                        children: [
                          CustomPaint(
                            painter: BrainIconPainter(color: Colors.grey.shade700),
                            size: const Size(16, 16), //  控制图标大小
                          ),
                          const SizedBox(width: 4),
                          Text("已深度思考", style: titleTextStyle),
                          const SizedBox(width: 4),
                          Text("(用时$thinkingTimeInSeconds秒)",
                              style: titleTextStyle), // 修改时间显示
                          const Spacer(),
                          Icon(
                            message['isExpanded']
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ),
                    if (message['isExpanded'])
                      SelectionArea(
                        child: MarkdownBody(
                          data: message['reasoning']!,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: reasoningTextStyle,
                            blockquote: reasoningTextStyle,
                            code: reasoningTextStyle.copyWith(
                                backgroundColor: Colors.grey.shade200),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// 构建输入区域 (保持不变)
  Widget _buildInputArea(ThemeData theme) {
    String promptLabelText = switch (_selectedMode) {
      AiAssistanceMode.generate => '聊天内容',
      AiAssistanceMode.polish => '待润色内容',
      _ => '写作提示/主题'
    };

    String promptHintText = switch (_selectedMode) {
      AiAssistanceMode.generate => '我们聊点什么？',
      AiAssistanceMode.polish => '输入你希望 AI 帮你润色的内容',
      _ => '输入你文章内容提示'
    };

    return TextFormField(
      controller: _promptController,
      decoration: InputDecoration(
        labelText: promptLabelText,
        hintText: promptHintText,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 10.0, bottom: 8.0),
          child: IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.grey),
                  )
                : Icon(Icons.send, color: theme.colorScheme.primary),
            onPressed:
                _isLoading ? null : () => _generateText(_selectedMode),
          ),
        ),
      ),
      maxLines: 3,
    );
  }

// 构建主界面 (保持不变)
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return Theme(
      data: appTheme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(
            title: "AI 协作",
            showBackButton: true,
            actions: [
              Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
        ),
        endDrawer: _buildEndDrawer(), // 传入主题色
        body: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    return _buildMessageBubble(message, theme);
                  },
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(_errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 10),
              _buildInputArea(theme),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

// 构建抽屉菜单 (保持不变)
  Widget _buildEndDrawer() {
    return Drawer(
      backgroundColor: Colors.white, // 侧边栏背景色
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '设置',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade300),
            // 模型选择
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildModelSelection(),
            ),
            // 模式选择
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildModeSelection(),
            ),
            Divider(height: 1, color: Colors.grey.shade300),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '历史对话',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87),
              ),
            ),
            Expanded(
              child: ListView(
                shrinkWrap: true, // 重要：允许 ListView 在 Column 中自适应高度
                children: _buildHistoryDialogList(),
              ),
            ),
            const SizedBox(height: 16) // 底部留白
          ],
        ),
      ),
    );
  }

// 构建历史对话列表 (保持不变)
  List<Widget> _buildHistoryDialogList() {
    return _historyDialogs.map((dialog) {
      final timestamp = dialog['timestamp'] as int? ?? 0;
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
      String dialogTitle = "新对话";
      final messages = dialog['messages'] as List<dynamic>? ?? [];
      final firstUserMessage =
          messages.firstWhere((msg) => msg['role'] == 'user', orElse: () => null);
      if (firstUserMessage != null && firstUserMessage['content'] != null) {
        dialogTitle = (firstUserMessage['content'] as String)
            .substring(0, min((firstUserMessage['content'] as String).length, 30));
      }

      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Dismissible(
          key: Key(dialog['id'].toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) => _deleteHistoryDialog(dialog['id']),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(dialogTitle,
                style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500)), // 稍微加粗
            subtitle: Text(formattedTime,
                style: const TextStyle(color: Colors.black54)),
            onTap: () {
              _loadHistoryDialog(dialog['id']);
              Navigator.pop(context); // 关闭侧边栏
            },
          ),
        ),
      );
    }).toList();
  }

// 构建模型选择 (保持不变)
  Widget _buildModelSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("模型:",
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8), // 增加间距
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 增加内边距
          decoration: BoxDecoration(
            color: Colors.grey.shade100, // 浅灰色背景
            borderRadius: BorderRadius.circular(8), // 圆角
            border: Border.all(color: Colors.grey.shade300), // 细边框
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedModelId,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() => _selectedModelId = newValue);
              }
            },
            underline: const SizedBox.shrink(),
            items: _availableModels
                .map<DropdownMenuItem<String>>(
                  (Map<String, String> model) => DropdownMenuItem<String>(
                    value: model["id"]!,
                    child: Text(model["name"]!,
                        style: const TextStyle(color: Colors.black87)),
                  ),
                )
                .toList(),
            style: const TextStyle(fontSize: 16, color: Colors.black87), // 调整字体大小
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700), // 下拉箭头图标
          ),
        ),
      ],
    );
  }

// 构建模式选择 (保持不变)
  Widget _buildModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("模式:",
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)), // 加粗并增大字体
        const SizedBox(height: 8),
        SegmentedButton<AiAssistanceMode>(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                return states.contains(WidgetState.selected)
                    ? appTheme.colorScheme.primary
                        .withOpacity(0.1) // 选中时使用更浅的主题色
                    : Colors.grey.shade100; // 未选中时使用浅灰色
              },
            ),
            foregroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) =>
                  states.contains(WidgetState.selected)
                      ? appTheme.colorScheme.primary
                      : Colors.black87,
            ),
            side: WidgetStateProperty.all<BorderSide>(
              BorderSide(color: Colors.grey.shade300), // 边框颜色
            ),
            shape: WidgetStateProperty.all<OutlinedBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // 圆角
              ),
            ),
          ),
          segments: const <ButtonSegment<AiAssistanceMode>>[
            ButtonSegment<AiAssistanceMode>(
                value: AiAssistanceMode.generate, label: Text('聊天')),
            ButtonSegment<AiAssistanceMode>(
                value: AiAssistanceMode.polish, label: Text('润色')),
            ButtonSegment<AiAssistanceMode>(
                value: AiAssistanceMode.write, label: Text('写作')),
          ],
          selected: <AiAssistanceMode>{_selectedMode},
          onSelectionChanged: (Set<AiAssistanceMode> newSelection) {
            setState(() {
              _selectedMode = newSelection.first;
              _messages.clear();
              if (_selectedMode == AiAssistanceMode.polish &&
                  widget.initialText != null &&
                  widget.initialText!.isNotEmpty) {
                _addMessage("user",
                    "请润色以下文本，使其表达更流畅、更生动：${widget.initialText!.replaceAll('"', '')}");
              }
            });
          },
        ),
      ],
    );
  }

// 加载历史对话 (保持不变)
  Future<void> _loadHistoryDialogs() async {
    final prefs = await SharedPreferences.getInstance();
    final historyDialogsJson = prefs.getStringList('historyDialogs');
    if (historyDialogsJson != null) {
      _historyDialogs = historyDialogsJson
          .map((jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>)
          .toList();
    }
    setState(() {});
  }

// 保存历史对话 (保持不变)
  Future<void> _saveHistoryDialogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'historyDialogs',
        _historyDialogs.map((dialog) => jsonEncode(dialog)).toList());
  }

// 加载对话 ID 计数器 (保持不变)
  Future<void> _loadDialogIdCounter() async {
    final prefs = await SharedPreferences.getInstance();
    _dialogIdCounter = prefs.getInt('dialogIdCounter') ?? 0;
  }

// 保存对话 ID 计数器 (保持不变)
  Future<void> _saveDialogIdCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dialogIdCounter', _dialogIdCounter);
  }

// 保存当前对话到历史记录 (保持不变)
  Future<void> _saveCurrentDialogToHistory() async {
    if (_messages.isEmpty) return;

    final dialogId = ++_dialogIdCounter;
    _saveDialogIdCounter();

    final dialog = {
      'id': dialogId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'messages': List<Map<String, dynamic>>.from(_messages),
    };
    _historyDialogs.insert(0, dialog);
    _saveHistoryDialogs();
  }

// 加载历史对话 (保持不变)
  void _loadHistoryDialog(int dialogId) {
    final dialog =
        _historyDialogs.firstWhere((d) => d['id'] == dialogId, orElse: () => {});
    if (dialog.isNotEmpty && dialog['messages'] != null) {
      setState(() {
        _messages.clear();
        _messages.addAll(List<Map<String, dynamic>>.from(dialog['messages']));
      });
    }
  }

// 删除历史对话 (保持不变)
  Future<void> _deleteHistoryDialog(int dialogId) async {
    _historyDialogs.removeWhere((dialog) => dialog['id'] == dialogId);
    await _saveHistoryDialogs();
    setState(() {});
  }
}