import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contact_detail_screen.dart';
import 'global_appbar.dart';

class RecentContactsScreen extends StatefulWidget {
  const RecentContactsScreen({super.key});

  @override
  _RecentContactsScreenState createState() => _RecentContactsScreenState();
}

class _RecentContactsScreenState extends State<RecentContactsScreen> {
  late Future<List<String>> _contactsFuture;

  @override
  void initState() {
    _contactsFuture = _fetchRecentContacts();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
       appBar:  const PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: GlobalAppBar(title: '最近联系人', showBackButton: true, actions: [],)),
      body: FutureBuilder<List<String>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(
                child: Text('Error', style: TextStyle(color: Colors.red)));
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 1,
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    color: Colors.grey[50],
                    child: InkWell(
                        onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) =>  ContactDetailScreen(contactName: snapshot.data![index])));
                        },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(snapshot.data![index],
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[700])),
                      ),
                    ),
                  );
                });
          } else {
            return const Center(
                child: Text('无常用联系人', style: TextStyle(color: Colors.grey)));
          }
        },
      ),
    );
  }

  Future<List<String>> _fetchRecentContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('current_user_id') ?? '';

      final response = await Supabase.instance.client
          .from('letters')
          .select('receiver_name')
          .eq('sender_id', currentUserId)
          .limit(5);

      List<String> names =
          response.map((e) => e['receiver_name'].toString()).toList();
      return names.toSet().toList();
    } on PostgrestException {
      return [];
    } catch (e) {
      return [];
    }
  }
}