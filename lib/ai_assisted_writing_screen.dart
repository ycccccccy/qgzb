import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'global_appbar.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;
  String _generatedContentText = '';
  String _generatedReasoningText = '';
  String? _errorMessage;
  bool _isExpanded = true;
  AiAssistanceMode _selectedMode = AiAssistanceMode.generate;

  bool _thinkingStarted = false;
  String _accumulatedReasoning = '';

  DateTime? _reasoningStartTime;
  DateTime? _reasoningEndTime;
  String _thinkingDurationString = '';
  Timer? _thinkingTimer;

  final String apiKey =
      "sk-fseyemmlpiggdhjoqhsztbvinavjrjhyhmrqsoghbtkwaxhp"; // 示例 API Key
  final String apiUrl = "https://api.siliconflow.cn/v1/chat/completions";
  // 模型选择相关变量
  String _selectedModel = "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B";
  final List<Map<String, String>> _availableModels = [
    {"id": "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B", "name": "Flash"},
    {"id": "deepseek-ai/DeepSeek-R1-Distill-Llama-8B", "name": "Advanced"},
  ];

  @override
  void initState() {
    super.initState();
    _selectedMode = AiAssistanceMode.generate;
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _promptController.text = widget.initialText!;
      _selectedMode = AiAssistanceMode.polish;
    }
    _thinkingStarted = false;
    _accumulatedReasoning = '';
    _reasoningStartTime = null;
    _reasoningEndTime = null;
    _thinkingDurationString = '';
    _thinkingTimer = null;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _thinkingTimer?.cancel();
    super.dispose();
  }
      Future<void> _generateText(AiAssistanceMode mode) async {
    // ... (之前的代码保持不变)
      setState(() {
      _isLoading = true;
      _generatedContentText = '';
      _generatedReasoningText = '';
      _errorMessage = null;
      _thinkingStarted = false; // Reset thinking state
      _accumulatedReasoning = ''; // Reset accumulated reasoning
      _reasoningStartTime = null; // 重置思考开始时间
      _reasoningEndTime = null;   // 重置思考结束时间
      _thinkingDurationString = ''; // 重置思考时长字符串
      _thinkingTimer = null; // 重置 Timer
    });

    final prompt = _promptController.text.trim();

    String aiPrompt;
    if (mode == AiAssistanceMode.generate) {
      if (prompt.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = "请输入聊天内容";
        });
        return;
      }
      aiPrompt = prompt; // 聊天模式没有预设
    } else if (mode == AiAssistanceMode.polish) {
      if (prompt.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = "请输入需要润色的内容";
        });
        return;
      }
      aiPrompt = "请润色以下文本，使其表达更流畅、更生动：${prompt.replaceAll('"', '')}"; // 润色模式的预设
    } else {
      if (prompt.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = "请输入写作提示";
        });
        return;
      }
      aiPrompt = "请用流畅的语言，以“${prompt.replaceAll('"', '')}”为主题，创作一段文章。请注意，输出内容必须全部为我要求的语言，禁止语言混用"; // 写作模式的预设
    }

    try {
      final request = http.Request('Post', Uri.parse(apiUrl))
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          "model": _selectedModel, // 使用选择的模型
          "messages": [
            {"role": "user", "content": aiPrompt}
          ],
          "stream": true,
          "max_tokens": 16384,
          "temperature": 1.0,
          "top_p": 0.7,
          "top_k": 15,
          "frequency_penalty": 0.1 ,
          "n": 1,
          "response_format": {"type": "text"},
        });
      // ... 其余部分保持不变
       final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode == 200) {

        final transformer = StreamTransformer<List<int>, String>.fromBind((stream) async* {
          await for (final chunk in stream) {
            final decodedChunk = utf8.decode(chunk);
            yield* Stream<String>.fromIterable(LineSplitter().convert(decodedChunk));
          }
        });

        await streamedResponse.stream
            .transform(transformer)
            .forEach((line) {
          if (line.startsWith("data: ")) {
            String jsonStr = line.substring(5);
            if (jsonStr.trim() == "[DONE]") {
              setState(() {
                _isLoading = false;
              });
              return;
            }

            try {
              final responseJson = jsonDecode(jsonStr);
              if (responseJson['choices'] != null && responseJson['choices'].isNotEmpty) {
                final delta = responseJson['choices'][0]['delta'];
                final contentChunk = delta['content'];
                final reasoningChunk = delta['reasoning_content'];

                if (reasoningChunk != null) {
                  // 启动计时器，如果还没有启动
                  if (_reasoningStartTime == null) {
                    _reasoningStartTime = DateTime.now();
                    // 启动 Timer，每秒更新一次思考时长
                    _thinkingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                      if (_reasoningStartTime != null && _reasoningEndTime == null) {
                        Duration duration = DateTime.now().difference(_reasoningStartTime!);
                        int seconds = duration.inSeconds;
                        setState(() { // 使用 setState 触发 UI 刷新
                          _thinkingDurationString = ' (已深度思考 ${seconds} 秒)';
                        });
                      }
                    });
                  }
                  setState(() {
                    _generatedReasoningText += reasoningChunk;
                  });
                }

                if (contentChunk != null) {
                  // 停止计时器并计算最终时长，如果计时器已经启动
                  if (_thinkingTimer != null && _reasoningEndTime == null) {
                    _reasoningEndTime = DateTime.now();
                    _thinkingTimer!.cancel(); // 停止 Timer
                    Duration duration = _reasoningEndTime!.difference(_reasoningStartTime!);
                    int seconds = duration.inSeconds;
                    _thinkingDurationString = ' (已深度思考 ${seconds} 秒)';
                  }
                  setState(() {
                    _generatedContentText += contentChunk;
                  });
                }
              }

            } catch (e) {
              print("JSON 解析错误: $e, 数据: $jsonStr");
              setState(() {
                _isLoading = false;
                _errorMessage = "AI 响应JSON解析错误";
              });
            }
          }
        });
      } else {
        print("API 请求错误: ${streamedResponse.statusCode}");
        print("响应内容: ${await streamedResponse.stream.bytesToString()}");
        setState(() {
          _isLoading = false;
          _errorMessage = "AI 服务请求失败，状态码: ${streamedResponse.statusCode}";
        });
      }
    } catch (e) {
      print("请求异常: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "请求 AI 服务时发生错误: $e";
      });
    } finally {
      if (!_isLoading && _errorMessage == null) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          title: "AI 写作助手",
          showBackButton: true,
          actions: [],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              // 模型选择 (居中)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "选择模型: ",
                    ),
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

              // 模式选择 (横向充满，内容居中)
SizedBox(
    width: double.infinity,
    child: IntrinsicWidth(
      child: Align(
        alignment: Alignment.center,
        child: SegmentedButton<AiAssistanceMode>(
          // ... (SegmentedButton 的内容)
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
            });
          },
        ),
      ),
    ),
),

              const SizedBox(height: 10),

              // TextFormField (居中)
              Center(
                child: TextFormField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    labelText: promptLabelText,
                    hintText: promptHintText,
                    border: InputBorder.none,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 3,
                ),
              ),

              const SizedBox(height: 10),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 20),

              // 思考过程
              ExpansionTile(
                title: Text("思考过程${_thinkingDurationString}", // 动态拼接思考时长字符串
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                initiallyExpanded: _isExpanded,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: MarkdownBody(
                      // 使用 MarkdownBody
                      data: _generatedReasoningText.replaceAll(
                          RegExp(r'</?think>'), ''), // 去除标签 (虽然实际上已经没有这个标签了)
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                    ),
                  ),
                ],
              ),

              // 修改：AI 最终的回答放在文本框里面，可以选择复制
              Column(
                // Wrap with a Column to control layout
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AI 生成内容',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context, _generatedContentText);
                        },
                        icon: const Icon(Icons.copy),
                        tooltip: '复制到发信界面',
                      ),
                    ],
                  ),
                  // 使用 MarkdownBody 渲染 AI 生成的内容
                  MarkdownBody(
                    data: _generatedContentText.isNotEmpty
                        ? _generatedContentText
                        : "AI 生成的文本将显示在这里",
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                    selectable: true, // 允许选择文本
                  )
                ],
              ),
              const SizedBox(height: 20),
              // 发送按钮
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _generateText(_selectedMode),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  label:
                      const Text('发送', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}