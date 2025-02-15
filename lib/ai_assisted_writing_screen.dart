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

enum AiAssistanceMode {
  generate,
  polish,
  write,
}

class AIAssistedWritingScreen extends StatefulWidget {
  final String? initialText;
  final AiAssistanceMode mode;

  const AIAssistedWritingScreen({
    Key? key,
    this.initialText,
    this.mode = AiAssistanceMode.generate,
  }) : super(key: key);

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
  StreamSubscription? _streamSubscription; // 用于取消 Stream 订阅

  // API 密钥配置
  static const String _advancedApiKey =
      "sk-fseyemmlpiggdhjoqhsztbvinavjrjhyhmrqsoghbtkwaxhp"; // 高级模型 API 密钥
  static const String _flashApiKey =
      "sk-zqslasquxmtenzcwmrexjpzaklrsjencmeodqznbvtytmlcp"; //  Flash 模型 API 密钥
  static const String _apiUrl = "https://api.siliconflow.cn/v1/chat/completions";

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
    _promptController.dispose();
    _streamSubscription?.cancel(); // 取消 Stream 订阅
    super.dispose();
  }

  void _addMessage(String role, String content,
      {String? reasoning, bool isExpanded = true, int? reasoningStartTimeMs, int? reasoningEndTimeMs}) {
    // 注意这里没有 setState
    _messages.add({
      "role": role,
      "content": content,
      "reasoning": reasoning,
      "isExpanded": isExpanded,
      "reasoningStartTimeMs": reasoningStartTimeMs,
      "reasoningEndTimeMs": reasoningEndTimeMs,
    });
  }
  // 处理流式响应
    Future<void> _processStreamedResponse(
      http.StreamedResponse streamedResponse) async {
    String fullResponseContent = "";
    String fullReasoning = "";
    int? reasoningStartTimeMs;
    bool contentStarted = false; // 新增标志：是否已开始输出内容

    _addMessage("assistant", "", reasoning: "", isExpanded: true);
    int tempMessageIndex = _messages.length - 1;

    final transformer = StreamTransformer<List<int>, String>.fromHandlers(
      handleData: (data, sink) {
        final decodedChunk = utf8.decode(data, allowMalformed: true);
        sink.add(decodedChunk);
      },
    );

    try {
      _streamSubscription = streamedResponse.stream
          .transform(transformer)
          .listen(
            (line) {
              List<String> lines = line.split("\n");

              for (String singleLine in lines) {
                if (singleLine.trim().isEmpty) {
                  continue;
                }

                if (!singleLine.startsWith("data: ")) continue;

                String jsonStr = singleLine.substring(5).trim();

                if (jsonStr == "[DONE]") {
                  _messages[tempMessageIndex]['content'] = fullResponseContent;
                  _messages[tempMessageIndex]['reasoning'] =
                      fullReasoning.isNotEmpty ? fullReasoning : null;
                  // [DONE] 时不再设置，因为可能已经设置过了
                  // _messages[tempMessageIndex]['reasoningEndTimeMs'] =
                  //     DateTime.now().millisecondsSinceEpoch;

                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                  return;
                }
                try {
                  final responseJson = jsonDecode(jsonStr);
                  final choices = responseJson['choices'];
                  if (choices != null && choices.isNotEmpty) {
                    final delta = choices[0]['delta'];
                    final contentChunk = delta['content'];
                    final reasoningChunk = delta['reasoning_content'];

                    if (reasoningChunk != null) {
                      reasoningStartTimeMs ??=
                          DateTime.now().millisecondsSinceEpoch;
                      if (_messages[tempMessageIndex]['reasoningStartTimeMs'] ==
                          null) {
                        _messages[tempMessageIndex]['reasoningStartTimeMs'] =
                            reasoningStartTimeMs;
                      }
                      fullReasoning += reasoningChunk;
                      _messages[tempMessageIndex]['reasoning'] = fullReasoning;
                    }

                    if (contentChunk != null ) {
                        // 首次收到 contentChunk，设置 reasoningEndTimeMs
                        if(!contentStarted){
                            _messages[tempMessageIndex]['reasoningEndTimeMs'] =
                                DateTime.now().millisecondsSinceEpoch;
                            contentStarted = true;
                        }

                      fullResponseContent += contentChunk;
                    }
                    if ((contentChunk != null || reasoningChunk != null) &&
                        mounted) {
                        // 仅更新当前消息
                      setState(() {
                        _messages[tempMessageIndex]['content'] =
                            fullResponseContent;
                       if (reasoningChunk != null) {
                         _messages[tempMessageIndex]['reasoning'] = fullReasoning;
                       }
                      });
                    }
                  }
                } catch (e) {
                  print("JSON parsing error: $e");
                  print("Problematic JSON string: $jsonStr");
                  if (mounted) {
                    setState(() {
                      // 只更新错误信息和加载状态
                      _isLoading = false;
                      _errorMessage = "AI 响应 JSON 解析错误: $e";
                    });
                  }
                }
              }
            },
            onError: (error) {
              print("Stream error: $error");
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = "AI响应流错误: $error";
                });
              }
            },
          );
    } catch (e) {
      print("asFuture error: $e");
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

    // 权限检查 (仅对 SiliconFlow 平台)
    if (_selectedModelId == "Pro/deepseek-ai/DeepSeek-R1") {
      final hasAccess = await _apiService.checkAIAccess();
      if (!hasAccess) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "请先登录或联系管理员开通 AI 高级版权限";
          });
        }
        return;
      }
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

    String aiPrompt;
    switch (mode) {
      case AiAssistanceMode.generate:
        aiPrompt = prompt;
        break;
      case AiAssistanceMode.polish:
        aiPrompt = "请润色以下文本，使其表达更流畅、更生动：${prompt.replaceAll('"', '')}";
        break;
      case AiAssistanceMode.write:
        aiPrompt =
            "请用流畅的语言，以“${prompt.replaceAll('"', '')}”为主题，创作一段文章。请注意，输出内容必须全部为我要求的语言，禁止语言混用";
        break;
    }

    _addMessage("user", aiPrompt); // 这里不再有 setState

      setState(() {  }); // 触发ListView更新
    try {
      if (_selectedModelId == "deepsleep") {
        await _performDeepSleepRequest();
      } else {
        await _performAIRequest(aiPrompt);
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

  // 将 AI 请求逻辑抽取成一个单独的方法 (只处理 SiliconFlow)
  Future<void> _performAIRequest(String aiPrompt) async {
    final currentApiKey = (_selectedModelId == "Pro/deepseek-ai/DeepSeek-R1")
        ? _advancedApiKey
        : _flashApiKey;

    final request = http.Request('Post', Uri.parse(_apiUrl))
      ..headers.addAll({
        'Authorization': 'Bearer $currentApiKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        "model": _selectedModelId,
        "messages": _messages
            .where((message) => message['role'] != 'thinking')
            .map((message) => {
                  'role': message['role'],
                  'content': message['content'],
                })
            .toList(),
        "stream": true,
        "response_format": {"type": "text"},
      });

    final streamedResponse = await http.Client().send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception("AI 服务请求失败，状态码: ${streamedResponse.statusCode}");
    }

    return _processStreamedResponse(streamedResponse as http.StreamedResponse);
  }

  // DeepSleep 模拟请求
  Future<void> _performDeepSleepRequest() async {
    final random = Random();
    final delay = Duration(seconds: 5 + random.nextInt(4));
    await Future.delayed(delay);

    if (mounted) {
      _addMessage("assistant", "服务器繁忙，请稍后再试");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, ThemeData theme) {
    final isUser = message['role'] == 'user';

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (message['reasoning'] != null && message['reasoning']!.isNotEmpty)
          _buildReasoningTile(message, theme),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: RepaintBoundary(
              child: SelectionArea( // 包裹 MarkdownBody
                child: MarkdownBody(
                  data: message['content']!,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme),
                  // selectable: false,  <-- 移除
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

    Widget _buildReasoningTile(Map<String, dynamic> message, ThemeData theme) {
    // 提取样式
    final titleTextStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black87,
      // fontSize: 可以根据需要设置
    );

    String thinkingTime = "";
      if (message['reasoningStartTimeMs'] != null) {
          final endTimeMs = message['reasoningEndTimeMs'] ?? DateTime.now().millisecondsSinceEpoch;
          final durationMs = endTimeMs - message['reasoningStartTimeMs']!;
          final duration = Duration(milliseconds: durationMs);

          if (duration.inSeconds < 60) {
            thinkingTime = "已思考${duration.inSeconds}秒";
          } else {
            thinkingTime = "已思考${duration.inMinutes}分${duration.inSeconds % 60}秒";
          }
      }

    return ExpansionTile(
      key: ValueKey(message['reasoningStartTimeMs']), // 使用 ValueKey
      maintainState: true,
      initiallyExpanded: message['isExpanded'] ?? true,
      onExpansionChanged: (bool expanded) {
        if (mounted) {
          setState(() {
            message['isExpanded'] = expanded;
          });
        }
      },
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            "思考过程",
            style: titleTextStyle,
          ),
          const SizedBox(width: 4),
          Text(
            "($thinkingTime)",
            style: titleTextStyle,
          ),
        ],
      ),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: RepaintBoundary(
            child: SelectionArea(   // 包裹 MarkdownBody
                child: MarkdownBody(
                  data: message['reasoning']!,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme),
                  // selectable: false,  <-- 移除
                ),
              )
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFFFFFFFF), //  导航栏颜色
      systemNavigationBarIconBrightness: Brightness.light, //  导航栏图标颜色
    ));

    String promptLabelText;
    String promptHintText;

    switch (_selectedMode) {
      case AiAssistanceMode.generate:
        promptLabelText = '聊天内容';
        promptHintText = '请输入你想和 AI 聊的内容';
        break;
      case AiAssistanceMode.polish:
        promptLabelText = '待润色内容';
        promptHintText = '请输入你希望 AI 帮你润色的内容';
        break;
      default:
        promptLabelText = '写作提示/主题';
        promptHintText = '请输入你希望 AI 帮你写的内容提示';
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: GlobalAppBar(
          title: "AI 协作",
          showBackButton: true,
          actions: const [],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModelSelection(),
            const SizedBox(height: 16),
            _buildModeSelection(),
            const SizedBox(height: 10),
            Expanded(
              // 优化后的 ListView.builder
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[_messages.length - 1 - index];
                    return _buildMessageBubble(message, theme);
                },
              ),
            ),
            if (_errorMessage != null) _buildErrorMessage(theme),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      labelText: promptLabelText,
                      hintText: promptHintText,
                      border: InputBorder.none,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _generateText(_selectedMode),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  label: const Text('发送',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelection() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedModelId,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedModelId = newValue;
                });
              }
            },
            isExpanded: false,
            underline: const SizedBox.shrink(),
            items: _availableModels
                .map<DropdownMenuItem<String>>(
                  (Map<String, String> model) => DropdownMenuItem<String>(
                    value: model["id"]!,
                    child: Text(model["name"]!),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection() {
    return SizedBox(
      width: double.infinity,
      child: IntrinsicWidth(
        child: Align(
          alignment: Alignment.center,
          child: SegmentedButton<AiAssistanceMode>(
            segments: const <ButtonSegment<AiAssistanceMode>>[
              ButtonSegment<AiAssistanceMode>(
                value: AiAssistanceMode.generate,
                label: Text('聊天模式'),
              ),
              ButtonSegment<AiAssistanceMode>(
                value: AiAssistanceMode.polish,
                label: Text('润色文本'),
              ),
              ButtonSegment<AiAssistanceMode>(
                value: AiAssistanceMode.write,
                label: Text('写作模式'),
              ),
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
        ),
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Text(
        _errorMessage!,
        style: TextStyle(color: theme.colorScheme.error),
      ),
    );
  }
}