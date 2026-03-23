import 'dart:ui'; 
import 'package:flutter/widgets.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; 
import 'package:crm_repository/crm_repository.dart'; // 🌟 السطر الذي كان مفقوداً!
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:my_pro_app/app/app.dart';
import 'package:my_pro_app/bootstrap.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:my_pro_app/firebase_options.dart';
import 'package:drift/drift.dart' as drift;
import 'package:telephony/telephony.dart';
import 'package:uuid/uuid.dart';

// ==========================================
// 👻 دالة الاستيقاظ الصامت (النسخة المدرعة 🛡️ + المزامنة السحابية ☁️)
// ==========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized(); 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 1. إيقاف تحذيرات Drift لكي لا ترتبك قاعدة البيانات عند فتح التطبيق
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 2. تهيئة Supabase في الخلفية
  await Supabase.initialize(
    url: 'https://trqowiapaafxxsvnmnwy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRycW93aWFwYWFmeHhzdm5tbnd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5OTY1MjEsImV4cCI6MjA4ODU3MjUyMX0.tni1GYt5QEyouSKGUhTpsLAS2Mmy1M2_c9ty72WslSY',
  );

  print("👻 إشارة صامتة وصلت من السحابة!");

  try {
    final data = message.data;
    final String? groupId = data['group_id']?.toString(); 
    final String? smsBody = data['message']?.toString();

    if (groupId == null || smsBody == null) return;

    // 3. تجهيز الأدوات (القاعدة المحلية + عميل السحابة + المدير + الـ SMS)
    final database = AppDatabase();
    final cloudClient = CloudStorageClient();
    final repository = CrmRepository(localStorage: database, cloudStorage: cloudClient);
    final telephony = Telephony.instance;

    final allContacts = await database.getAllContacts();
    final targetContacts = allContacts.where((c) => c.groupId == groupId).toList();

    if (targetContacts.isEmpty) return;

    print("🚀 جاري إرسال [$smsBody] إلى ${targetContacts.length} عميل...");

    const uuid = Uuid(); 

    for (var contact in targetContacts) {
      
      bool isSent = false;
      int retryCount = 0;
      const int maxRetries = 3; 

      // 🌟 حلقة الإرسال 
      while (!isSent && retryCount < maxRetries) {
        try {
          print("➤ محاولة إرسال SMS للرقم ${contact.phone}...");
          telephony.sendSms(to: contact.phone, message: smsBody);
          isSent = true; 
        } catch (e) {
          retryCount++;
          print("⚠️ فشل الإرسال (المحاولة $retryCount من $maxRetries): $e");
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(seconds: 5)); 
          }
        }
      }

      // 🌟 محاولة الحفظ في قاعدة البيانات المحلية
      try {
        await database.insertMessage(MessagesCompanion(
          id: drift.Value(uuid.v4()),
          phone: drift.Value(contact.phone),
          body: drift.Value(isSent ? smsBody : "❌ فشل الإرسال: $smsBody"),
          type: drift.Value(isSent ? 'sent_auto_fcm' : 'failed_auto_fcm'),
          messageDate: drift.Value(DateTime.now()),
        ));
        print("✅ تم كتابة السجل في قاعدة البيانات للرقم: ${contact.phone}");
      } catch (dbError) {
        print("⚠️ تم الإرسال ولكن تعذر الحفظ محلياً: $dbError");
      }

      await Future.delayed(const Duration(seconds: 1)); 
    }

    // 🌟 4. المزامنة الصامتة في الخلفية!
    print("☁️ جاري رفع سجلات الإرسال الجديدة إلى السحابة...");
    try {
      await repository.syncAllToCloud();
      print("✅ تم رفع السجلات للسحابة بنجاح!");
    } catch (syncError) {
      print("⚠️ تعذر الرفع للسحابة، سيتم الرفع لاحقاً عند فتح التطبيق: $syncError");
    }

    print("✅✅ تمت مهمة الشبح بالكامل بنجاح! العودة للنوم 💤");

  } catch (e) {
    print("❌ حدث خطأ جذري في مهمة الخلفية: $e");
  }
}

// ==========================================
// 🚀 نقطة انطلاق التطبيق (Main)
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة فايربيس
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. تسجيل دالة الاستماع في الخلفية (عند إغلاق التطبيق)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. تسجيل دالة الاستماع في الواجهة (والتطبيق مفتوح)
  FirebaseMessaging.onMessage.listen((message) {
    print('🔔 إشارة وصلت والتطبيق مفتوح!');
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