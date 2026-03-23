import 'dart:ui'; // 🌟 1. استدعاء مكتبة الـ UI الضرورية لعمل الخلفية

import 'package:cloud_storage_api/cloud_storage_api.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:my_pro_app/app/app.dart';
import 'package:my_pro_app/bootstrap.dart';
import 'package:my_pro_app/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:telephony/telephony.dart';

// ==========================================
// 👻 دالة الاستيقاظ الصامت (نسخة الدبابة 🛡️ - لا تستسلم أبداً)
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized(); 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print("👻 إشارة صامتة وصلت من السحابة!");

  try {
    final data = message.data;
    final String? groupIdString = data['group_id']?.toString();
    final String? smsBody = data['message']?.toString();

    if (groupIdString == null || smsBody == null) return;

    final int groupId = int.parse(groupIdString);

    final database = AppDatabase();
    final telephony = Telephony.instance;

    final allContacts = await database.getAllContacts();
    final targetContacts = allContacts.where((c) => c.groupId == groupId).toList();

    if (targetContacts.isEmpty) return;

    print("🚀 جاري إرسال $smsBody إلى ${targetContacts.length} عميل...");

    for (var contact in targetContacts) {
      
      // 🌟 خوارزمية المحاولة المستميتة (Retry Logic)
      bool isSent = false;
      int retryCount = 0;
      const int maxRetries = 3; // سنحاول 3 مرات كحد أقصى

      while (!isSent && retryCount < maxRetries) {
        try {
          // 1. محاولة الإرسال
          telephony.sendSms(to: contact.phone, message: smsBody);
          isSent = true; // نجحنا! نكسر الحلقة
          
          // 2. الحفظ في قاعدة البيانات كـ (ناجح)
          await database.insertMessage(MessagesCompanion(
            phone: drift.Value(contact.phone),
            body: drift.Value(smsBody),
            type: const drift.Value('sent_auto_fcm'),
            messageDate: drift.Value(DateTime.now()),
          ));
          print("✅ تم إرسال وحفظ رسالة الرقم: ${contact.phone}");
          
        } catch (e) {
          retryCount++;
          print("⚠️ فشل الإرسال للرقم ${contact.phone}. المحاولة $retryCount من $maxRetries...");
          
          if (retryCount >= maxRetries) {
            // 3. استسلمنا بعد 3 محاولات، نحفظها في القاعدة كـ (فاشلة) ليعرف المستخدم
            await database.insertMessage(MessagesCompanion(
              phone: drift.Value(contact.phone),
              body: drift.Value("❌ فشل الإرسال: $smsBody"),
              type: const drift.Value('failed_auto_fcm'),
              messageDate: drift.Value(DateTime.now()),
            ));
            print("❌ استسلام. لم يتم الإرسال بسبب غياب شبكة الشريحة.");
          } else {
            // ⏱️ إذا فشلنا، ننتظر 30 ثانية قبل المحاولة التالية (لعل شبكة الهاتف تعود)
            await Future.delayed(const Duration(seconds: 30));
          }
        }
      }

      await Future.delayed(const Duration(seconds: 1)); // حماية الشريحة بين كل عميل وآخر
    }

    print("✅✅ تمت مهمة الشبح بالكامل بنجاح! العودة للنوم 💤");

  } catch (e) {
    print("❌ حدث خطأ في مهمة الخلفية: $e");
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة فايربيس
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🌟 2. تسجيل دالة الاستماع في الخلفية (عند إغلاق التطبيق)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🌟 3. تسجيل دالة الاستماع في الواجهة (والتطبيق مفتوح)
  FirebaseMessaging.onMessage.listen((message) {
    print('🔔 إشارة وصلت والتطبيق مفتوح!');
    // نقوم بتشغيل نفس دالة الشبح لترسل الرسائل فوراً
    _firebaseMessagingBackgroundHandler(message);
  });

  // 4. تهيئة Supabase
  await Supabase.initialize(
    url: 'https://trqowiapaafxxsvnmnwy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRycW93aWFwYWFmeHhzdm5tbnd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTY1MjEsImV4cCI6MjA4ODU3MjUyMX0.tni1GYt5QEyouSKGUhTpsLAS2Mmy1M2_c9ty72WslSY',
  );

  final database = AppDatabase();
  final cloudClient = CloudStorageClient();

  bootstrap(() => App(
    database: database,
    cloudClient: cloudClient, 
  ));
}