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

  // ==========================================
  // قسم الحذف (Delete) - 🌟 محدث لنظام الـ UUID
  // ==========================================
  
  Future<void> deleteGroup(String id) async { // 🌟 String بدل int
    if (_currentUserId == null) return;
    await _supabaseClient.from('groups').delete().eq('id', id).eq('user_id', _currentUserId!);
  }

  Future<void> deleteSchedule(String id) async { // 🌟 String بدل int
    if (_currentUserId == null) return;
    await _supabaseClient.from('schedules').delete().eq('id', id).eq('user_id', _currentUserId!);
  }

  Future<void> deleteContact(String id) async { // 🌟 String بدل int (إذا لم تكن موجودة، أضفها)
    if (_currentUserId == null) return;
    await _supabaseClient.from('contacts').delete().eq('id', id).eq('user_id', _currentUserId!);
  }

  // ==========================================
  // 🌟 قسم إدارة الأجهزة (Device Management)
  // ==========================================

/// 🌟 تسجيل الجهاز أو استعادته من الموت باستخدام بصمة الأندرويد (Hardware ID)
  Future<String?> registerDevice({
    required String deviceName, 
    required String fcmToken, 
    required String hardwareId, // 🌟 البصمة الجديدة
  }) async {
    if (_currentUserId == null) return null;

    final data = {
      'user_id': _currentUserId,
      'device_name': deviceName,
      'fcm_token': fcmToken,
      'hardware_id': hardwareId, // 🌟 نحفظ البصمة
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      // 1. نسأل السحابة: هل يوجد جهاز يحمل نفس هذه البصمة لهذا المستخدم؟
      final existingDevice = await _supabaseClient
          .from('user_tokens')
          .select('device_id')
          .eq('user_id', _currentUserId!)
          .eq('hardware_id', hardwareId) // 🌟 البحث بالبصمة المستحيل تغييرها!
          .maybeSingle();

      if (existingDevice != null) {
        // 🌟 الهاتف عاد من الموت (حُذف وتمت إعادة تثبيته)!
        // نأخذ الـ ID القديم لكي لا تضيع الحملات المربوطة به، ونحدث الـ FCM Token فقط
        final oldId = existingDevice['device_id'];
        data['device_id'] = oldId;
        
        await _supabaseClient.from('user_tokens').upsert(data);
        return oldId as String; 
      } else {
        // 2. هاتف جديد كلياً
        final response = await _supabaseClient.from('user_tokens').insert(data).select().single();
        return response['device_id'] as String;
      }
    } catch (e) {
      throw 'حدث خطأ في تسجيل الجهاز: $e';
    }
  }
  /// حذف جهاز من السحابة (فك الارتباط)
  Future<void> removeDevice(String deviceId) async {
    if (_currentUserId == null) return;
    await _supabaseClient.from('user_tokens').delete().eq('device_id', deviceId);
  }

  /// جلب كل الأجهزة المربوطة بهذا الحساب (لنختار منها عند إنشاء حملة)
  Future<List<Map<String, dynamic>>> fetchDevices() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('user_tokens').select().eq('user_id', _currentUserId!);
  }
  // ==========================================
  // 🌟 قسم تتبع تاريخ التحديثات (Sync Metadata)
  // ==========================================

  /// 1. تسجيل لحظة التعديل: نحدث الوقت في السحابة ليصبح (الآن)
  Future<void> updateCloudSyncTime() async {
    if (_currentUserId == null) return;
    
    await _supabaseClient.from('sync_metadata').upsert({
      'user_id': _currentUserId,
      // نستخدم التوقيت العالمي (UTC) لتوحيد الوقت بين كل الأجهزة
      'last_updated_at': DateTime.now().toUtc().toIso8601String(), 
    });
  }

  /// 2. قراءة لحظة التعديل: نسأل السحابة متى كان آخر تحديث؟
  Future<DateTime?> getCloudSyncTime() async {
    if (_currentUserId == null) return null;
    
    final response = await _supabaseClient
        .from('sync_metadata')
        .select('last_updated_at')
        .eq('user_id', _currentUserId!)
        .maybeSingle(); // نجلب صفا واحداً فقط (أو null إذا لم يكن موجوداً)

    if (response != null && response['last_updated_at'] != null) {
      return DateTime.parse(response['last_updated_at']);
    }
    
    return null;
  }
}