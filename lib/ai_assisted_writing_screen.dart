import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'global_appbar.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiAssistanceMode {
  generate,
  polish,
  write,
}

class AIAssistedWritingScreen extends StatefulWidget {
  final String? initialText;
  final AiAssistanceMode mode;

  const AIAssistedWritingScreen(
      {Key? key, this.initialText, this.mode = AiAssistanceMode.generate})
      : super(key: key);

  @override
  _AIAssistedWritingScreenState createState() =>
      _AIAssistedWritingScreenState();
}

class _AIAssistedWritingScreenState extends State<AIAssistedWritingScreen> {
  final _promptController = TextEditingController();
  bool _isLoading = false;
  final List<Map<String, dynamic>> _messages = [];
  String? _errorMessage;
  AiAssistanceMode _selectedMode = AiAssistanceMode.generate;

  // API 密钥配置
  final String advancedApiKey = "sk-fseyemmlpiggdhjoqhsztbvinavjrjhyhmrqsoghbtkwaxhp"; // 高级模型 API 密钥
  final String flashApiKey = "sk-zqslasquxmtenzcwmrexjpzaklrsjencmeodqznbvtytmlcp"; // Flash 模型 API 密钥
  final String apiUrl = "https://api.siliconflow.cn/v1/chat/completions";

  String _selectedModel = "deepseek-ai/DeepSeek-R1-Distill-Llama-8B";
  final List<Map<String, String>> _availableModels = [
    {"id": "deepseek-ai/DeepSeek-R1-Distill-Llama-8B", "name": "Flash"},
    {"id": "Pro/deepseek-ai/DeepSeek-R1", "name": "Advanced"},
  ];

  final SupabaseClient supabase = Supabase.instance.client;
  late final SharedPreferences _prefs;
  String? _authUserId;

  static const String _currentUserIdKey = 'current_user_id';

  @override
  void initState() {
    super.initState();
    _selectedMode = AiAssistanceMode.generate;
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _promptController.text = widget.initialText!;
      _selectedMode = AiAssistanceMode.polish;
      _addMessage("user",
          "请润色以下文本，使其表达更流畅、更生动：${widget.initialText!.replaceAll('"', '')}");
    }
    _loadAuthUserId();
  }

  Future<void> _loadAuthUserId() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _authUserId = _prefs.getString(_currentUserIdKey);
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _addMessage(String role, String content,
      {String? reasoning, int? thinkingDuration, bool isExpanded = true}) {
    setState(() {
      _messages.add({
        "role": role,
        "content": content,
        "reasoning": reasoning,
        "thinkingDuration": thinkingDuration,
        "isExpanded": isExpanded,
      });
    });
  }

  Future<bool> _checkAIAccess() async {
    try {
      if (_authUserId == null) {
        return false;
      }

      final response = await supabase
          .from('students')
          .select('ai_allowed')
          .eq('auth_user_id', _authUserId as Object)
          .maybeSingle();

      if (response == null) {
        return false;
      }

      return response['ai_allowed'] ?? false;
    } catch (error) {
      return false;
    }
  }


  Future<void> _generateText(AiAssistanceMode mode) async {
    // 1. 根据所选模型选择 API 密钥
    String currentApiKey =
        (_selectedModel == "Pro/deepseek-ai/DeepSeek-R1") ? advancedApiKey : flashApiKey;

    // 2. 权限检查 (仅对高级模型)
    if (_selectedModel == "Pro/deepseek-ai/DeepSeek-R1") {
      final hasAccess = await _checkAIAccess();
      if (!hasAccess) {
        setState(() {
          _isLoading = false;
          _errorMessage = "你没有权限访问高级模型。联系作者或赞助以获取权限";
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prompt = _promptController.text.trim();
    _promptController.clear();

    String aiPrompt;
    if (mode == AiAssistanceMode.generate) {
      if (prompt.isEmpty) {
        setState(() { _isLoading = false; _errorMessage = "请输入聊天内容"; }); return; }
      aiPrompt = prompt;
      _addMessage("user", aiPrompt);
    } else if (mode == AiAssistanceMode.polish) {
      if (prompt.isEmpty) {
        setState(() { _isLoading = false; _errorMessage = "请输入需要润色的内容"; }); return;}
      aiPrompt = "请润色以下文本，使其表达更流畅、更生动：${prompt.replaceAll('"', '')}";
      _addMessage("user", aiPrompt);
    } else {
      if (prompt.isEmpty) { setState(() { _isLoading = false; _errorMessage = "请输入写作提示"; }); return; }
      aiPrompt = "请用流畅的语言，以“${prompt.replaceAll('"', '')}”为主题，创作一段文章。请注意，输出内容必须全部为我要求的语言，禁止语言混用";
      _addMessage("user", aiPrompt);
    }

    try {
      // 3. 使用正确的 API 密钥
      final request = http.Request('Post', Uri.parse(apiUrl))
        ..headers.addAll({
          'Authorization': 'Bearer $currentApiKey', // 使用动态选择的密钥
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          "model": _selectedModel,
          "messages": _messages
              .where((message) => message['role'] != 'thinking')
              .map((message) => {
            'role': message['role'],
            'content': message['content'],
          }).toList(),
          "stream": true,
          "response_format": {"type": "text"},
        });

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode == 200) {
        String fullResponseContent = "";
        String fullReasoning = "";
        DateTime? reasoningStartTime;
        Timer? reasoningTimer;

        _addMessage("assistant", "", reasoning: "", thinkingDuration: 0, isExpanded: true);
        int tempMessageIndex = _messages.length - 1;

        final transformer = StreamTransformer<List<int>, String>.fromBind((stream) async* {
          await for (final chunk in stream) {
            final decodedChunk = utf8.decode(chunk);
            yield* Stream<String>.fromIterable(LineSplitter().convert(decodedChunk));
          }
        });

        await streamedResponse.stream.transform(transformer).forEach((line) {
          if (line.startsWith("data: ")) {
            String jsonStr = line.substring(5);
            if (jsonStr.trim() == "[DONE]") {
              if (reasoningTimer != null) { reasoningTimer?.cancel(); }
              _messages[tempMessageIndex]['content'] = fullResponseContent;
              _messages[tempMessageIndex]['reasoning'] = fullReasoning.isNotEmpty ? fullReasoning : null;
              _messages[tempMessageIndex]['thinkingDuration'] = reasoningStartTime != null
                  ? DateTime.now().difference(reasoningStartTime!).inSeconds : null;
              setState(() { _isLoading = false; });
              return;
            }

            try {
              final responseJson = jsonDecode(jsonStr);
              if (responseJson['choices'] != null && responseJson['choices'].isNotEmpty) {
                final delta = responseJson['choices'][0]['delta'];
                final contentChunk = delta['content'];
                final reasoningChunk = delta['reasoning_content'];

                if (reasoningChunk != null) {
                  if (reasoningStartTime == null) {
                    reasoningStartTime = DateTime.now();
                    reasoningTimer = Timer.periodic(Duration(seconds: 1), (timer) {
                      if (mounted && reasoningStartTime != null) {
                        setState(() {
                          _messages[tempMessageIndex]['thinkingDuration'] =
                              DateTime.now().difference(reasoningStartTime!).inSeconds;
                        });
                      }
                    });
                  }
                  fullReasoning += reasoningChunk;
                  _messages[tempMessageIndex]['reasoning'] = fullReasoning;
                }
                if (contentChunk != null) {
                  fullResponseContent += contentChunk;
                  _messages[tempMessageIndex]['content'] = fullResponseContent;
                }
                if (mounted) { setState(() {}); }
              }
            } catch (e) {
              setState(() { _isLoading = false; _errorMessage = "AI 响应JSON解析错误"; });
            }
          }
        });
      } else {
        setState(() { _isLoading = false; _errorMessage = "AI 服务请求失败，状态码: ${streamedResponse.statusCode}"; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = "请求 AI 服务时发生错误: $e"; });
    }
  }
    Widget _buildMessageBubble(
      Map<String, dynamic> message, ThemeData theme, BuildContext context) {
    final isUser = message['role'] == 'user';

    return Column(
      crossAxisAlignment:
      isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // 可折叠的思考过程
        if (message['reasoning'] != null && message['reasoning'].isNotEmpty)
          ExpansionTile(
            initiallyExpanded: message['isExpanded'] ?? true,
            onExpansionChanged: (bool expanded) {
              setState(() {
                message['isExpanded'] = expanded;
              });
            },
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  "思考过程${message['thinkingDuration'] != null ? ' (${message['thinkingDuration']} 秒)' : ''}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.black87),
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
                child: MarkdownBody(
                  data: message['reasoning'],
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                  selectable: true,
                ),
              ),
            ],
          ),
        // 消息主体
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: MarkdownBody(
            data: message['content']!,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
            selectable: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);

    String promptLabelText;
    String promptHintText;

    switch (_selectedMode) {
      case AiAssistanceMode.generate:
        promptLabelText = '聊天内容';
        promptHintText = '请输入你想和AI聊的内容';
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: GlobalAppBar(
          title: "AI协作",
          showBackButton: true,
          actions: [],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模型选择
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("选择模型: "),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedModel,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedModel = newValue!;
                      });
                    },
                    isExpanded: false,
                    underline: Container(),
                    items: _availableModels
                        .map<DropdownMenuItem<String>>(
                            (Map<String, String> model) {
                      return DropdownMenuItem<String>(
                        value: model["id"]!,
                        child: Text(model["name"]!),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 模式选择
            SizedBox(
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
            ),
            const SizedBox(height: 10),

            // 聊天记录
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message =
                      _messages[_messages.length - 1 - index];
                  return _buildMessageBubble(message, theme, context);
                },
              ),
            ),

            // 错误消息
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 10),

            // 输入框和发送按钮
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
                  onPressed: _isLoading ? null : () => _generateText(_selectedMode),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  label:
                      const Text('发送', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  )),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}