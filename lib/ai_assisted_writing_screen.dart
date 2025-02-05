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
  write, // 添加写作模式
}

// 修改后的 AIAssistedWritingScreen 代码，使其可以接收初始文本和模式
class AIAssistedWritingScreen extends StatefulWidget {
  final String? initialText;
  final AiAssistanceMode mode;

  const AIAssistedWritingScreen({Key? key, this.initialText, this.mode = AiAssistanceMode.generate}) : super(key: key);

  @override
  _AIAssistedWritingScreenState createState() => _AIAssistedWritingScreenState();
}

class _AIAssistedWritingScreenState extends State<AIAssistedWritingScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;
  String _generatedContentText = '';
  String _generatedReasoningText = '';
  String? _errorMessage;
  bool _isExpanded = true;
  AiAssistanceMode _selectedMode = AiAssistanceMode.generate; // 默认模式

  // !!! 替换成你自己的 API Key !!!
  final String apiKey = "sk-fseyemmlpiggdhjoqhsztbvinavjrjhyhmrqsoghbtkwaxhp";
  final String apiUrl = "https://api.siliconflow.cn/v1/chat/completions";

  @override
  void initState() {
    super.initState();
    _selectedMode = AiAssistanceMode.generate; // 默认选择聊天模式
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _promptController.text = widget.initialText!;
      _selectedMode = AiAssistanceMode.polish; // 如果有初始文本，默认选择润色模式
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateText(AiAssistanceMode mode) async {
    setState(() {
      _isLoading = true;
      _generatedContentText = '';
      _generatedReasoningText = '';
      _errorMessage = null;
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
          "model": "deepseek-ai/DeepSeek-R1-Distill-Llama-8B",
          "messages": [
            {"role": "user", "content": aiPrompt}
          ],
          "stream": true,
          "max_tokens": 8192,
          "temperature": 1.4,
          "top_p": 0.7,
          "top_k": 50,
          "frequency_penalty": 0.5,
          "n": 1,
          "response_format": {"type": "text"},
        });

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode == 200) {
        String accumulatedJsonString = '';

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

            accumulatedJsonString += jsonStr;

            try {
              final responseJson = jsonDecode(accumulatedJsonString);
              if (responseJson['choices'] != null && responseJson['choices'].isNotEmpty) {
                final delta = responseJson['choices'][0]['delta'];
                final contentChunk = delta['content'];

                if (contentChunk != null) {
                  setState(() {
                    _generatedContentText = contentChunk;
                  });
                }
              }

              accumulatedJsonString = '';

            } catch (e) {
              print("JSON 解析错误: $e, 数据: $accumulatedJsonString");
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

              // 模式选择器
              SegmentedButton<AiAssistanceMode>(
                segments: const <ButtonSegment<AiAssistanceMode>>[
                  ButtonSegment<AiAssistanceMode>(
                    value: AiAssistanceMode.generate,
                    label: Text('聊天模式'),
                  ),
                  ButtonSegment<AiAssistanceMode>(
                    value: AiAssistanceMode.polish,
                    label: Text('润色模式'),
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
              const SizedBox(height: 10),

              TextFormField(
                controller: _promptController,
                decoration: InputDecoration(
                  labelText: promptLabelText,
                  hintText: promptHintText,
                  border: InputBorder.none,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 3,
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
                title: const Text("思考过程", style: TextStyle(fontWeight: FontWeight.bold)),
                initiallyExpanded: _isExpanded,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(_generatedReasoningText, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),

              // 修改：AI 最终的回答放在文本框里面，可以选择复制
              Column( // Wrap with a Column to control layout
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AI 生成内容',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                   SelectableText(
                     _generatedContentText.isNotEmpty
                        ? _generatedContentText
                        : "AI 生成的文本将显示在这里",
                     style: theme.textTheme.bodyMedium,
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
                  label: const Text('发送', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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