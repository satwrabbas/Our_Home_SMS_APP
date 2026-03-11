import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import '../cubit/contacts_cubit.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 🌟 تزويد الشاشة بالـ Cubit وإعطائه الـ Repository
    return BlocProvider(
      create: (context) => ContactsCubit(
        repository: context.read<CrmRepository>(),
      )..loadContacts(), // نأمره بجلب البيانات فور فتح الشاشة
      child: const ContactsView(),
    );
  }
}

class ContactsView extends StatelessWidget {
  const ContactsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جهات الاتصال (CRM)'),
        actions:[
          // زر سحب الأسماء من الهاتف
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'مزامنة من الهاتف',
            onPressed: () {
              context.read<ContactsCubit>().syncFromPhone();
            },
          ),
          // 🌟 زر تسجيل الخروج (للتجربة)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              // نطلب من المدير تسجيل الخروج، والبوابة ستطردنا تلقائياً!
              context.read<CrmRepository>().signOut(); 
            },
          ),
        ],
      ),
      // 🌟 البناء بناءً على الحالة (بدون setState)
      body: BlocBuilder<ContactsCubit, ContactsState>(
        builder: (context, state) {
          if (state is ContactsLoading) {
            return const Center(child: CircularProgressIndicator());
          } 
          else if (state is ContactsSyncing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('جاري سحب الأسماء من الهاتف...'),
                ],
              ),
            );
          } 
          else if (state is ContactsError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
          } 
          else if (state is ContactsLoaded) {
            final contacts = state.contacts;
            
            if (contacts.isEmpty) {
              return const Center(child: Text('لا يوجد جهات اتصال. اضغط على زر المزامنة بالأعلى.'));
            }

            return ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}