import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'letter_detail_screen.dart';
import 'global_appbar.dart';

class UnreadLetterScreen extends StatefulWidget {
  @override
  _UnreadLetterScreenState createState() => _UnreadLetterScreenState();
}

class _UnreadLetterScreenState extends State<UnreadLetterScreen> {
  late Future<List<Map<String, dynamic>>> _lettersFuture;
  final Color cardColor = Colors.grey[50]!;
  final EdgeInsets cardPadding = const EdgeInsets.all(16.0);
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 0;
  final int _pageSize = 10;
  List<Map<String, dynamic>> _allLetters = [];
  bool _hasMoreData = true;



  @override
  void initState() {
    super.initState();
    _lettersFuture = _loadLetters();
    _scrollController.addListener(_scrollListener);
  }
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        !_isLoadingMore && _hasMoreData) {
      _loadMoreLetters();
    }
  }

  Future<void> _loadMoreLetters() async{
    if(_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    _currentPage++;
    final moreLetters = await fetchUnreadLetters();
    if (moreLetters.isEmpty) {
      setState(() {
        _hasMoreData = false;
      });
    } else {
      setState(() {
        _allLetters.addAll(moreLetters);
      });
    }
    setState(() {
      _isLoadingMore = false;
    });
  }
  Future<List<Map<String, dynamic>>> _loadLetters() async{
    _currentPage = 0;
    _allLetters = [];
    setState(() {

    });
    final letters = await fetchUnreadLetters();
    setState(() {
      _allLetters = letters;
    });
    return letters;
  }

  Future<List<Map<String, dynamic>>> fetchUnreadLetters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';
      final studentData = await _fetchStudentData(currentUserId);

      final allLetters = await _fetchLetters(studentData);

      final filteredLetters = _filterLetters(allLetters, studentData);
      //print("过滤信件的数据$filteredLetters");
      final lettersWithSenderNames =
          await _fetchSenderNames(filteredLetters);
      //print("带有发件人姓名的信件：$lettersWithSenderNames");
      return lettersWithSenderNames;
    } on PostgrestException catch (e) {
      //print('获取信件数据发生 Supabase 错误: ${e.message}');
      _showErrorSnackBar('获取信件数据时发生 Supabase 错误: ${e.message}');
      return [];
    } catch (e) {
      //print('获取信件数据发生其他错误：$e');
      _showErrorSnackBar('获取信件数据时发生其他错误: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchStudentData(String currentUserId) async {
    final response = await Supabase.instance.client
        .from('students')
        .select('name, class_name, allow_anonymous,school')
        .eq('student_id', currentUserId)
        .single();
    return response;
  }

  Future<List<Map<String, dynamic>>> _fetchLetters(
      Map<String, dynamic> studentData) async {
    final query = Supabase.instance.client
        .from('letters')
        .select()
        .or('and(receiver_name.eq.${studentData['name']},my_school.eq.${studentData['school']}),and(receiver_name.eq.${studentData['name']},target_school.eq.${studentData['school']})')
        .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize -1);
    final lettersResponse = await query;

    return lettersResponse;
  }

  List<Map<String, dynamic>> _filterLetters(
      List<Map<String, dynamic>> letters, Map<String, dynamic> studentData) {
    final myClass = studentData['class_name'];
    final allowAnonymous = studentData['allow_anonymous'] ?? false;
    List<Map<String, dynamic>> filteredLetters;

    if (!allowAnonymous) {
      filteredLetters = letters
          .where((letter) =>
      (letter['is_anonymous'] == false || letter['is_anonymous'] == null) &&
          (letter['receiver_class'] == myClass ||
              letter['receiver_class'] == null))
          .toList();
    } else {
      filteredLetters = letters
          .where((letter) =>
      (letter['receiver_class'] == myClass || letter['receiver_class'] == null))
          .toList();
    }
    return filteredLetters;
  }

  Future<List<Map<String, dynamic>>> _fetchSenderNames(
      List<Map<String, dynamic>> letters) async {
    if (letters.isEmpty) return [];

    // 获取所有发件人的ID
    final senderIds = letters.map((letter) => letter['sender_id']).toList();

    // 一次性查询所有发件人姓名
    final senderResponse = await Supabase.instance.client
        .from('students')
        .select('student_id, name')
        .inFilter('student_id', senderIds);

    final senderMap = Map.fromIterable(senderResponse,
        key: (item) => item['student_id'], value: (item) => item['name']);

    // 将发件人姓名添加到信件数据中
    List<Map<String, dynamic>> lettersWithSenderNames = letters.map((letter) {
      final senderId = letter['sender_id'];
      final senderName = senderMap[senderId] as String?;
      return {...letter, 'sender_name': senderName};
    }).toList();

    return lettersWithSenderNames;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: GlobalAppBar(title: '收信箱', showBackButton: true, actions: [])),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _lettersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)));
        } else if (_allLetters.isEmpty) {
          return Center(
              child: Text('没有未读信件', style: TextStyle(color: Colors.grey[500])));
        } else {
          return Stack(
            children: [
              ListView.separated(
                controller: _scrollController,
                padding: cardPadding,
                itemCount: _allLetters.length,
                separatorBuilder: (context, index) =>
                const SizedBox(height: 8.0),
                itemBuilder: (context, index) {
                  final letter = _allLetters[index];
                  return _buildLetterCard(context, letter);
                },
              ),
              if(_isLoadingMore)
                Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: const Center(child: CircularProgressIndicator())
                )
            ],
          );
        }
      },
    );
  }

  String _formatTime(String? time) {
    if (time == null) {
      return '未知时间';
    }
    DateTime? dateTime = DateTime.tryParse(time);
    if (dateTime == null) {
      return '未知时间';
    }
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return '未知时间';
    }
  }

  Widget _buildLetterCard(BuildContext context, Map<String, dynamic> letter) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final senderName =
        letter['is_anonymous'] == true ? '匿名朋友' : letter['sender_name'] ?? '未知发件人';
    final sendTime = _formatTime(letter['send_time']);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: cardColor,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => LetterDetailScreen(letter: letter, letterId: letter['id'])),
          );
        },
        child: Padding(
          padding: cardPadding,
          child: Row(
            children: [
              const Icon(Icons.mail_outline, size: 30, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(senderName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                      sendTime,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}