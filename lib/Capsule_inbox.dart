import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_data.dart';
import 'package:provider/provider.dart';
// 引入 foundation 包
import 'package:shared_preferences/shared_preferences.dart'; // 引入 SharedPreferences

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<MailItem> _mails = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user data in initState
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? currentUserId = prefs.getString('current_user_id');
    final String? rememberedId = prefs.getString('rememberedId');
    final String? rememberedName = prefs.getString('rememberedName');

    if (currentUserId == null || rememberedId == null || rememberedName == null) {
      print('Error: current_user_id is null in SharedPreferences (InboxPage)');
      // Optionally, you could redirect to login here if user data is missing
      // _redirectToLogin(); // Implement _redirectToLogin if needed
      setState(() {
        _isLoading = false; // Stop loading even if user data is missing
        _hasError = false; // Reset error flag in case it was set previously
      });
      return; // Stop further loading if user data is missing
    }

    final userData = Provider.of<UserData>(context, listen: false);
    userData.setUserData(currentUserId, rememberedId, rememberedName);
    _loadReceivedMails(userData); // Proceed to load mails after setting user data
  }


  Future<void> _loadReceivedMails(UserData userData) async {
    try {
      final userId = userData.currentUserId;

      if (userId == null) {
        throw '用户未登录'; // This should ideally not happen after _loadUserData
      }

      final response = await _supabase
          .from('Letters') // Changed to 'Letters' (Capital 'L')
          .select('''
            id,
            sender_id,
            receiver_id,
            message,
            delivery_date,
            status,
            created_at,
            temp_receiver,
            attachment_url,
            Profiles!letters_sender_id_fkey(school, grade, class_number) // Changed to 'Profiles' (Capital 'P')
          ''')
          .or('receiver_id.eq.$userId, temp_receiver->>email.eq.${userData.email}')
          .order('delivery_date', ascending: false);

      setState(() {
        _mails = response
            .map((item) => MailItem.fromJson(item))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载邮件失败: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserData>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('时间胶囊收件箱'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadReceivedMails(userData),
          ),
        ],
      ),
      body: _buildContent(userData),
    );
  }

  Widget _buildContent(UserData userData) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('加载失败，请重试'),
            ElevatedButton(
              onPressed: () => _loadReceivedMails(userData),
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    if (userData.currentUserId == null) {
      return const Center(child: Text('用户未登录，请重新登录'));
    }

    if (_mails.isEmpty) {
      return const Center(child: Text('暂无已送达的时间胶囊'));
    }

    return ListView.builder(
      itemCount: _mails.length,
      itemBuilder: (context, index) {
        final mail = _mails[index];
        return _MailListItem(
          mail: mail,
          onTap: () => _showMailDetail(mail),
        );
      },
    );
  }

  void _showMailDetail(MailItem mail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MailDetailPage(mail: mail),
      ),
    );
  }
}

class _MailListItem extends StatelessWidget {
  final MailItem mail;
  final VoidCallback onTap;

  const _MailListItem({required this.mail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: _buildStatusIcon(),
        title: Text(
          mail.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发件人: ${mail.senderInfo}'),
            Text('送达时间: ${mail.formattedDeliveryDate}'),
          ],
        ),
        trailing: mail.hasAttachment ? const Icon(Icons.attachment) : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatusIcon() {
    return Icon(
      mail.status == 'delivered' ? Icons.mark_email_read : Icons.schedule,
      color: mail.status == 'delivered' ? Colors.green : Colors.orange,
    );
  }
}

class MailDetailPage extends StatelessWidget {
  final MailItem mail;

  const MailDetailPage({super.key, required this.mail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(mail.subject)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('发件人', mail.senderInfo),
            _buildDetailRow('收件人', mail.receiverInfo),
            _buildDetailRow('发送时间', mail.formattedCreateDate),
            _buildDetailRow('送达时间', mail.formattedDeliveryDate),
            const SizedBox(height: 24),
            Text(mail.content, style: const TextStyle(fontSize: 16)),
            if (mail.hasAttachment) _buildAttachment(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black),
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('附件：', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Image.network(mail.attachmentUrl!),
      ],
    );
  }
}

class MailItem {
  final String id;
  final String subject;
  final String content;
  final String senderInfo;
  final String receiverInfo;
  final DateTime deliveryDate;
  final DateTime createDate;
  final String status;
  final String? attachmentUrl;

  MailItem({
    required this.id,
    required this.subject,
    required this.content,
    required this.senderInfo,
    required this.receiverInfo,
    required this.deliveryDate,
    required this.createDate,
    required this.status,
    this.attachmentUrl,
  });

  factory MailItem.fromJson(Map<String, dynamic> json) {
    final sender = json['profiles'] ?? {};
    final receiver = json['temp_receiver'] ?? {};

    return MailItem(
      id: json['id'],
      subject: _getSubject(json['message']),
      content: json['message'],
      senderInfo: sender.isNotEmpty
          ? '${sender['school']} ${sender['grade']}年${sender['class_number']}班'
          : '未知发件人',
      receiverInfo: receiver.isNotEmpty
          ? '${receiver['school']} ${receiver['grade']}年${receiver['class_number']}班'
          : '未知收件人',
      deliveryDate: DateTime.parse(json['delivery_date']),
      createDate: DateTime.parse(json['created_at']),
      status: json['status'],
      attachmentUrl: json['attachment_url'],
    );
  }

  static String _getSubject(String content) {
    return content.length > 20 ? '${content.substring(0, 20)}...' : content;
  }

    String get formattedDeliveryDate => DateFormat('yyyy-MM-dd HH:mm').format(deliveryDate);
    String get formattedCreateDate => DateFormat('yyyy-MM-dd HH:mm').format(createDate);
    bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  }