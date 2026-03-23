import 'dart:ui'; // 🌟 1. استدعاء مكتبة الـ UI الضرورية لعمل الخلفية
import 'package:uuid/uuid.dart'; // 🌟 مكتبة توليد المعرفات
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
// 👻 دالة الاستيقاظ الصامت (النسخة المدرعة 🛡️)
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized(); 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 🌟 1. إيقاف تحذيرات Drift لكي لا ترتبك قاعدة البيانات عند فتح التطبيق
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  print("👻 إشارة صامتة وصلت من السحابة!");

  try {
    final data = message.data;
    final String? groupId = data['group_id']?.toString(); 
    final String? smsBody = data['message']?.toString();

    if (groupId == null || smsBody == null) return;

    final database = AppDatabase();
    final telephony = Telephony.instance;

    final allContacts = await database.getAllContacts();
    final targetContacts = allContacts.where((c) => c.groupId == groupId).toList();

    if (targetContacts.isEmpty) return;

    print("🚀 جاري إرسال[$smsBody] إلى ${targetContacts.length} عميل...");

    const uuid = Uuid(); // مولد الـ IDs

    for (var contact in targetContacts) {
      
      bool isSent = false;
      int retryCount = 0;

      // 🌟 2. حلقة الإرسال (مفصولة ومستقلة تماماً عن قاعدة البيانات)
      while (!isSent && retryCount < 3) {
        try {
          print("➤ محاولة إرسال SMS للرقم ${contact.phone}...");
          // نرسل الرسالة بدون await (أطلق وانسَ) لكي لا يتجمد الكود
          telephony.sendSms(to: contact.phone, message: smsBody);
          isSent = true; // إذا لم ينهار الكود هنا، فهذا يعني أن الأندرويد استلم الأمر!
        } catch (e) {
          retryCount++;
          print("⚠️ فشل الإرسال (المحاولة $retryCount من 3): $e");
          if (retryCount < 3) {
            // ننتظر 5 ثواني فقط لكي لا يقتلنا الأندرويد
            await Future.delayed(const Duration(seconds: 5)); 
          }
        }
      }

      // 🌟 3. محاولة الحفظ في قاعدة البيانات (في كتلة Try/Catch منفصلة لحماية الشبح)
      try {
        await database.insertMessage(MessagesCompanion(
          id: drift.Value(uuid.v4()),
          phone: drift.Value(contact.phone),
          // نكتب حالة الرسالة بناءً على نجاح حلقة الإرسال السابقة
          body: drift.Value(isSent ? smsBody : "❌ فشل الإرسال: $smsBody"),
          type: drift.Value(isSent ? 'sent_auto_fcm' : 'failed_auto_fcm'),
          messageDate: drift.Value(DateTime.now()),
        ));
        print("✅ تم كتابة السجل في قاعدة البيانات للرقم: ${contact.phone}");
      } catch (dbError) {
        // إذا فشل الحفظ بسبب (Database Lock) والتطبيق مفتوح، لن ينهار الشبح!
        print("⚠️ تم الإرسال ولكن تعذر الحفظ محلياً: $dbError");
      }

      // حماية الشريحة بين كل عميل وآخر
      await Future.delayed(const Duration(seconds: 1)); 
    }

    print("✅✅ تمت مهمة الشبح بالكامل بنجاح! العودة للنوم 💤");

  } catch (e) {
    print("❌ حدث خطأ جذري في مهمة الخلفية: $e");
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