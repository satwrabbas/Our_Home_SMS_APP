import 'package:supabase_flutter/supabase_flutter.dart';

/// هذا الكلاس مسؤول عن التحدث مع Supabase فقط
class CloudStorageClient {
  // نقوم بتمرير الـ client للكلاس (هذا ممتاز من أجل الـ Testing لاحقاً)
  CloudStorageClient({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabaseClient;

  // ==========================================
  // قسم المصادقة (Authentication)
  // ==========================================

  /// تسجيل الدخول
  Future<void> signIn({required String email, required String password}) async {
    await _supabaseClient.auth.signInWithPassword(email: email, password: password);
  }

  /// إنشاء حساب جديد
  Future<void> signUp({required String email, required String password}) async {
    await _supabaseClient.auth.signUp(email: email, password: password);
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  /// مراقبة حالة المستخدم (هل هو مسجل دخول أم لا؟)
  Stream<AuthState> get authStateChanges => _supabaseClient.auth.onAuthStateChange;
  
  /// جلب بيانات المستخدم الحالي
  Session? get currentSession => _supabaseClient.auth.currentSession;

  // ==========================================
  // قسم المزامنة (Sync) 🔄
  // ==========================================

  Future<void> syncGroups(List<Map<String, dynamic>> groups) async {
    if (groups.isNotEmpty) await _supabaseClient.from('groups').upsert(groups);
  }

  Future<void> syncContacts(List<Map<String, dynamic>> contacts) async {
    // نعتمد على id كمفتاح أساسي لمنع التكرار
    if (contacts.isNotEmpty) await _supabaseClient.from('contacts').upsert(contacts);
  }

  Future<void> syncSchedules(List<Map<String, dynamic>> schedules) async {
    if (schedules.isNotEmpty) await _supabaseClient.from('schedules').upsert(schedules);
  }

  Future<void> syncMessages(List<Map<String, dynamic>> messages) async {
    if (messages.isNotEmpty) await _supabaseClient.from('messages').upsert(messages);
  }
  // سيتم إضافة دوال المزامنة (جلب المجموعات والرسائل) هنا لاحقاً!

  // ==========================================
  // قسم جلب البيانات (Fetch / Download) 📥
  // ==========================================

  Future<List<Map<String, dynamic>>> fetchGroups() async => await _supabaseClient.from('groups').select();
  
  Future<List<Map<String, dynamic>>> fetchContacts() async => await _supabaseClient.from('contacts').select();
  
  Future<List<Map<String, dynamic>>> fetchSchedules() async => await _supabaseClient.from('schedules').select();
  
  Future<List<Map<String, dynamic>>> fetchMessages() async => await _supabaseClient.from('messages').select();
}