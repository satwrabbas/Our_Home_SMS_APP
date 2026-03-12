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
}