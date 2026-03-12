import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; // ☁️
import 'package:drift/drift.dart' as drift;

/// المدير المسؤول عن إدارة بيانات التطبيق (محلياً وسحابياً)
class CrmRepository {
  const CrmRepository({
    required AppDatabase localStorage,
    required CloudStorageClient cloudStorage,
  })  : _localStorage = localStorage,
        _cloudStorage = cloudStorage;

  final AppDatabase _localStorage;
  final CloudStorageClient _cloudStorage;

  // ==========================================
  // 1. قسم المصادقة (Authentication) ☁️
  // ==========================================
  
  Stream<AuthState> get authStateChanges => _cloudStorage.authStateChanges;
  
  Session? get currentSession => _cloudStorage.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    await _cloudStorage.signIn(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await _cloudStorage.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _cloudStorage.signOut();
  }

  // ==========================================
  // 2. قسم جهات الاتصال (Contacts) 💾
  // ==========================================
  
  Future<List<Contact>> getContacts() async {
    return await _localStorage.getAllContacts();
  }

  Future<void> saveSyncedContacts(List<Map<String, String>> phoneContacts) async {
    for (var contact in phoneContacts) {
      final companion = ContactsCompanion(
        name: drift.Value(contact['name'] ?? 'بدون اسم'),
        phone: drift.Value(contact['phone'] ?? ''),
      );
      await _localStorage.insertContact(companion);
    }
  }

  Future<int> deleteContact(Contact contact) async {
    return await _localStorage.deleteContact(contact);
  }

  /// 🌟 الدالة المصححة والوحيدة لتحديث المجموعة
  Future<void> updateContactGroup(Contact contact, int? groupId) async {
    // نطلب من قاعدة البيانات التحديث المباشر للـ ID الخاص بالعميل لتجنب مشكلة الـ Unique
    await _localStorage.updateContactGroupDB(contact.id, groupId); 
  }

  // ==========================================
  // 3. قسم المجموعات والحملات (Groups & Campaigns) 📅
  // ==========================================

  Future<List<Group>> getGroups() async {
    return await _localStorage.getAllGroups();
  }

  Future<int> addGroup(String name) async {
    final companion = GroupsCompanion(
      name: drift.Value(name),
    );
    return await _localStorage.insertGroup(companion);
  }

  Future<List<Schedule>> getSchedules() async {
    return await _localStorage.getAllSchedules();
  }

  Future<int> addSchedule({
    required int groupId,
    required String message,
    required int sendDay,
  }) async {
    final companion = SchedulesCompanion(
      groupId: drift.Value(groupId),
      message: drift.Value(message),
      sendDay: drift.Value(sendDay),
    );
    return await _localStorage.insertSchedule(companion);
  }

  // ==========================================
  // 4. قسم السجلات (Logs) 📊
  // ==========================================

  Future<List<Message>> getMessageLogs() async {
    return await _localStorage.getAllMessages();
  }

  Future<int> addMessageLog({required String phone, required String body, required String type}) async {
    final companion = MessagesCompanion(
      phone: drift.Value(phone),
      body: drift.Value(body),
      type: drift.Value(type),
      messageDate: drift.Value(DateTime.now()), 
    );
    return await _localStorage.insertMessage(companion);
  }

// ==========================================
  // 5. قسم المزامنة الشاملة (Cloud Sync) ☁️
  // ==========================================

  /// رفع كل البيانات المحلية إلى Supabase
  Future<void> syncAllToCloud() async {
    // 1. جلب كل البيانات من الهاتف
    final groups = await _localStorage.getAllGroups();
    final contacts = await _localStorage.getAllContacts();
    final schedules = await _localStorage.getAllSchedules();
    
    // 🌟 التصحيح هنا: استخدمنا getAllMessages بدلاً من getMessageLogs
    final messages = await _localStorage.getAllMessages(); 

    // 2. تحويل المجموعات
    final groupsJson = groups.map((g) => {
      'id': g.id,
      'name': g.name,
    }).toList();

    // 3. تحويل جهات الاتصال
    final contactsJson = contacts.map((c) => {
      'id': c.id,
      'name': c.name,
      'phone': c.phone,
      'group_id': c.groupId, 
    }).toList();

    // 4. تحويل الحملات المجدولة
    final schedulesJson = schedules.map((s) => {
      'id': s.id,
      'group_id': s.groupId,
      'message': s.message,
      'send_day': s.sendDay,
      'last_sent_date': s.lastSentDate?.toIso8601String(),
      'is_active': s.isActive,
    }).toList();

    // 5. تحويل سجلات الرسائل
    final messagesJson = messages.map((m) => {
      'id': m.id,
      'phone': m.phone,
      'body': m.body,
      'type': m.type,
      'message_date': m.messageDate.toIso8601String(),
    }).toList();

    // 6. إرسالها إلى السحابة عبر العميل
    await _cloudStorage.syncGroups(groupsJson);
    await _cloudStorage.syncContacts(contactsJson);
    await _cloudStorage.syncSchedules(schedulesJson);
    await _cloudStorage.syncMessages(messagesJson);
  }

  /// 📥 تنزيل البيانات من السحابة وحفظها في الهاتف (Drift)
  Future<void> downloadAllFromCloud() async {
    // 1. جلب البيانات من السحابة
    final cloudGroups = await _cloudStorage.fetchGroups();
    final cloudContacts = await _cloudStorage.fetchContacts();
    final cloudSchedules = await _cloudStorage.fetchSchedules();
    final cloudMessages = await _cloudStorage.fetchMessages();

    // 2. حفظ المجموعات (نستخدم try-catch لتجاهل الخطأ إذا كانت المجموعة موجودة مسبقاً)
    for (var row in cloudGroups) {
      try {
        await _localStorage.insertGroup(GroupsCompanion(
          id: drift.Value(row['id']),
          name: drift.Value(row['name']),
        ));
      } catch (_) {} 
    }

    // 3. حفظ جهات الاتصال
    for (var row in cloudContacts) {
      try {
        await _localStorage.insertContact(ContactsCompanion(
          id: drift.Value(row['id']),
          name: drift.Value(row['name']),
          phone: drift.Value(row['phone']),
          groupId: drift.Value(row['group_id']),
        ));
      } catch (_) {}
    }

    // 4. حفظ الحملات المجدولة
    for (var row in cloudSchedules) {
      try {
        await _localStorage.insertSchedule(SchedulesCompanion(
          id: drift.Value(row['id']),
          groupId: drift.Value(row['group_id']),
          message: drift.Value(row['message']),
          sendDay: drift.Value(row['send_day']),
          lastSentDate: drift.Value(row['last_sent_date'] != null ? DateTime.parse(row['last_sent_date']) : null),
          isActive: drift.Value(row['is_active']),
        ));
      } catch (_) {}
    }

    // 5. حفظ سجلات الرسائل
    for (var row in cloudMessages) {
      try {
        await _localStorage.insertMessage(MessagesCompanion(
          id: drift.Value(row['id']),
          phone: drift.Value(row['phone']),
          body: drift.Value(row['body']),
          type: drift.Value(row['type']),
          messageDate: drift.Value(DateTime.parse(row['message_date'])),
        ));
      } catch (_) {}
    }
  }

  
}