import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; // نحتاج هذا من أجل AuthState و Session

// استدعاء شاشاتنا
import 'package:my_pro_app/login/view/login_page.dart';
import 'package:my_pro_app/home/view/home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. جلب المدير
    final repository = context.read<CrmRepository>();

    // 2. الاستماع المستمر (Stream) لحالة السحابة
    return StreamBuilder<AuthState>(
      stream: repository.authStateChanges,
      builder: (context, snapshot) {
        // إذا كانت السحابة لا تزال تفكر (تحمل)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 3. التحقق من وجود جلسة (Session)
        final session = snapshot.hasData ? snapshot.data!.session : null;

        // 4. التوجيه التلقائي
        if (session != null) {
          return const HomePage(); // إذا كان مسجل دخول -> الرئيسية
        } else {
          return const LoginPage(); // إذا لم يكن مسجل -> تسجيل الدخول
        }
      },
    );
  }
}