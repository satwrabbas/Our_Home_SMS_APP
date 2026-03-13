import 'package:supabase_flutter/supabase_flutter.dart';

/// 🌟 الكلاس المحدث ليتعامل مع بيانات كل مستخدم على حدة
class CloudStorageClient {
  CloudStorageClient({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabaseClient;

  // ==========================================
  // قسم المصادقة (Authentication) - (بدون تغيير)
  // ==========================================

  Future<void> signIn({required String email, required String password}) async {
    await _supabaseClient.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await _supabaseClient.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _supabaseClient.auth.onAuthStateChange;
  
  Session? get currentSession => _supabaseClient.auth.currentSession;

  // ==========================================
  // 🌟 (جديد) دالة مساعدة لجلب رقم المستخدم الحالي
  // ==========================================
  String? get _currentUserId => _supabaseClient.auth.currentUser?.id;

  // ==========================================
  // قسم المزامنة (الرفع - Upload) - (تم تحديثه)
  // ==========================================

  Future<void> syncGroups(List<Map<String, dynamic>> groups) async {
    if (_currentUserId == null || groups.isEmpty) return;
    // إضافة user_id لكل صف قبل رفعه
    final data = groups.map((g) => {...g, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('groups').upsert(data);
  }

  Future<void> syncContacts(List<Map<String, dynamic>> contacts) async {
    if (_currentUserId == null || contacts.isEmpty) return;
    final data = contacts.map((c) => {...c, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('contacts').upsert(data);
  }

  Future<void> syncSchedules(List<Map<String, dynamic>> schedules) async {
    if (_currentUserId == null || schedules.isEmpty) return;
    final data = schedules.map((s) => {...s, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('schedules').upsert(data);
  }

  Future<void> syncMessages(List<Map<String, dynamic>> messages) async {
    if (_currentUserId == null || messages.isEmpty) return;
    final data = messages.map((m) => {...m, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('messages').upsert(data);
  }

  // ==========================================
  // قسم جلب البيانات (التنزيل - Download) - (تم تحديثه)
  // ==========================================

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    if (_currentUserId == null) return[];
    // لا تجلب إلا المجموعات الخاصة بهذا المستخدم فقط
    return await _supabaseClient.from('groups').select().eq('user_id', _currentUserId!);
  }
  
  Future<List<Map<String, dynamic>>> fetchContacts() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('contacts').select().eq('user_id', _currentUserId!);
  }
  
  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('schedules').select().eq('user_id', _currentUserId!);
  }
  
  Future<List<Map<String, dynamic>>> fetchMessages() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('messages').select().eq('user_id', _currentUserId!);
  }
}