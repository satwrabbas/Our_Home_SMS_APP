import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; 
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // 🌟 مكتبة الـ JSON

class CrmRepository {
  const CrmRepository({
    required AppDatabase localStorage,
    required CloudStorageClient cloudStorage,
  })  : _localStorage = localStorage,
        _cloudStorage = cloudStorage;

  final AppDatabase _localStorage;
  final CloudStorageClient _cloudStorage;

  // ==========================================
  // 1. قسم المصادقة والأجهزة ☁️📱
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
    // 0. مسح الجهاز من السحابة قبل الخروج
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('registered_device_id');
    if (deviceId != null) {
      await _cloudStorage.removeDevice(deviceId);
      await prefs.remove('registered_device_id');
    }
    
    // 1. مسح البيانات المحلية
    await _localStorage.clearAllData();
    // 2. تسجيل الخروج
    await _cloudStorage.signOut();
  }

  /// 🌟 تسجيل الجهاز في السحابة
  Future<String?> registerDevice(String deviceName, String token, String hardwareId) async {
    return await _cloudStorage.registerDevice(deviceName: deviceName, fcmToken: token, hardwareId: hardwareId);
  }

  /// 🌟 فك ارتباط الجهاز
  Future<void> removeDevice(String deviceId) async {
    await _cloudStorage.removeDevice(deviceId);
  }

  // 🌟 الدالة العبقرية الجديدة (تخزين مؤقت للأجهزة)
  Future<List<Map<String, dynamic>>> getRegisteredDevices() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // 1. نحاول جلب الأجهزة من السحابة (لو فيه إنترنت)
      final devices = await _cloudStorage.fetchDevices();
      
      // 2. نحفظها كـ JSON في ذاكرة الهاتف لكي نستخدمها لاحقاً لو انقطع الإنترنت!
      await prefs.setString('cached_devices', jsonEncode(devices));
      
      return devices;
    } catch (e) {
      // 3. ✈️ حالة انقطاع الإنترنت: نقرأ الذاكرة المحفوظة!
      final cachedString = prefs.getString('cached_devices');
      if (cachedString != null) {
        final List<dynamic> decoded = jsonDecode(cachedString);
        // تحويلها لـ List<Map> ليفهمها التطبيق
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
      
      // 4. إذا لم يكن هناك إنترنت، ولم نفتح التطبيق سابقاً أبداً (حالة نادرة جداً)
      return[];
    }
  }

  // ==========================================
  // 2. قسم جهات الاتصال 💾
  // ==========================================

  /// 🌟 تعديل اسم ورقم العميل (مع الاحتفاظ بمجموعته ومعرفه)
  Future<void> updateContactInfo(Contact contact, String newName, String newPhone) async {
    final companion = ContactsCompanion(
      id: drift.Value(contact.id), // نحافظ على الـ ID
      name: drift.Value(newName),
      phone: drift.Value(newPhone),
      groupId: drift.Value(contact.groupId), // نحافظ على مجموعته الحالية
    );
    await _localStorage.upsertContact(companion); // نستخدم Upsert ليعمل كتحديث
  }
  Future<List<Contact>> getContacts() async {
    return await _localStorage.getAllContacts();
  }

  Future<void> saveSyncedContacts(List<Map<String, String>> phoneContacts) async {
    for (var contact in phoneContacts) {
      final companion = ContactsCompanion(
        name: drift.Value(contact['name'] ?? 'بدون اسم'),
        phone: drift.Value(contact['phone'] ?? ''),
      );
      await _localStorage.upsertContact(companion);
    }
  }

  Future<int> deleteContact(Contact contact) async {
    return await _localStorage.deleteContact(contact);
  }

  Future<void> updateContactGroup(Contact contact, int? groupId) async {
    await _localStorage.updateContactGroupDB(contact.id, groupId); 
  }

  // ==========================================
  // 3. قسم المجموعات والحملات 📅
  // ==========================================
  Future<List<Group>> getGroups() async {
    return await _localStorage.getAllGroups();
  }

  Future<int> addGroup(String name) async {
    return await _localStorage.insertGroup(GroupsCompanion(name: drift.Value(name)));
  }

  Future<void> deleteGroup(Group group) async {
    await _localStorage.clearGroupFromContacts(group.id);
    await _localStorage.deleteGroup(group);
    await _cloudStorage.deleteGroup(group.id);
  }

  Future<void> updateGroup(Group group) async {
    await _localStorage.updateGroup(group);
  }

  Future<List<Schedule>> getSchedules() async {
    return await _localStorage.getAllSchedules();
  }

  /// 🌟 تمت إضافة targetDeviceId لدالة إنشاء الحملة
  Future<int> addSchedule({
    required int groupId, 
    required String message, 
    required int sendDay, 
    required int sendHour, 
    required int sendMinute,
    String? targetDeviceId, // 🌟
  }) async {
    final companion = SchedulesCompanion(
      groupId: drift.Value(groupId), 
      message: drift.Value(message), 
      sendDay: drift.Value(sendDay),
      sendHour: drift.Value(sendHour), 
      sendMinute: drift.Value(sendMinute),
      targetDeviceId: drift.Value(targetDeviceId), // 🌟
    );
    return await _localStorage.insertSchedule(companion);
  }

  Future<void> deleteSchedule(Schedule schedule) async {
    await _localStorage.deleteSchedule(schedule);
    await _cloudStorage.deleteSchedule(schedule.id);
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await _localStorage.updateSchedule(schedule);
  }

  // ==========================================
  // 4. قسم السجلات 📊
  // ==========================================
  Future<List<Message>> getMessageLogs() async {
    return await _localStorage.getAllMessages();
  }

  Future<int> addMessageLog({required String phone, required String body, required String type}) async {
    return await _localStorage.insertMessage(MessagesCompanion(
      phone: drift.Value(phone), body: drift.Value(body), type: drift.Value(type), messageDate: drift.Value(DateTime.now()), 
    ));
  }

  // ==========================================
  // 5. قسم المزامنة الشاملة ☁️
  // ==========================================
  Future<void> syncAllToCloud() async {
    final groups = await _localStorage.getAllGroups();
    final contacts = await _localStorage.getAllContacts();
    final schedules = await _localStorage.getAllSchedules();
    final messages = await _localStorage.getAllMessages(); 

    final groupsJson = groups.map((g) => {'id': g.id, 'name': g.name}).toList();
    final contactsJson = contacts.map((c) => {'id': c.id, 'name': c.name, 'phone': c.phone, 'group_id': c.groupId}).toList();
    
    // 🌟 تمت إضافة target_device_id للرفع
    final schedulesJson = schedules.map((s) => {
      'id': s.id,
      'group_id': s.groupId,
      'message': s.message,
      'send_day': s.sendDay,
      'send_hour': s.sendHour,
      'send_minute': s.sendMinute,
      'target_device_id': s.targetDeviceId, // 🌟
      'is_active': s.isActive,
    }).toList();

    final messagesJson = messages.map((m) => {'id': m.id, 'phone': m.phone, 'body': m.body, 'type': m.type, 'message_date': m.messageDate.toIso8601String()}).toList();

    await _cloudStorage.syncGroups(groupsJson);
    await _cloudStorage.syncContacts(contactsJson);
    await _cloudStorage.syncSchedules(schedulesJson);
    await _cloudStorage.syncMessages(messagesJson);

    await _cloudStorage.updateCloudSyncTime();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_sync_time', DateTime.now().toUtc().toIso8601String());
  }

  Future<void> downloadAllFromCloud() async {
    final cloudGroups = await _cloudStorage.fetchGroups();
    final cloudContacts = await _cloudStorage.fetchContacts();
    final cloudSchedules = await _cloudStorage.fetchSchedules();
    final cloudMessages = await _cloudStorage.fetchMessages();

    for (var row in cloudGroups) {
      try { await _localStorage.upsertGroup(GroupsCompanion(id: drift.Value(row['id']), name: drift.Value(row['name']))); } catch (_) {} 
    }

    for (var row in cloudContacts) {
      try { await _localStorage.upsertContact(ContactsCompanion(id: drift.Value(row['id']), name: drift.Value(row['name']), phone: drift.Value(row['phone']), groupId: drift.Value(row['group_id']))); } catch (_) {}
    }

    // 🌟 تمت إضافة target_device_id للتنزيل
    for (var row in cloudSchedules) {
      try {
        await _localStorage.upsertSchedule(SchedulesCompanion(
          id: drift.Value(row['id']),
          groupId: drift.Value(row['group_id']),
          message: drift.Value(row['message']),
          sendHour: drift.Value(row['send_hour'] ?? 9),
          sendMinute: drift.Value(row['send_minute'] ?? 0),
          sendDay: drift.Value(row['send_day']),
          targetDeviceId: drift.Value(row['target_device_id']), // 🌟
          lastSentDate: drift.Value(row['last_sent_date'] != null ? DateTime.parse(row['last_sent_date']) : null),
          isActive: drift.Value(row['is_active']),
        ));
      } catch (_) {}
    }

    for (var row in cloudMessages) {
      try { await _localStorage.upsertMessage(MessagesCompanion(id: drift.Value(row['id']), phone: drift.Value(row['phone']), body: drift.Value(row['body']), type: drift.Value(row['type']), messageDate: drift.Value(DateTime.parse(row['message_date'])))); } catch (_) {}
    }
  }

  Future<bool> downloadIfCloudIsNewer() async {
    final cloudTime = await _cloudStorage.getCloudSyncTime();
    if (cloudTime == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final localTimeString = prefs.getString('local_sync_time');
    DateTime? localTime;
    if (localTimeString != null) localTime = DateTime.parse(localTimeString);

    if (localTime == null || cloudTime.isAfter(localTime)) {
      await _localStorage.clearAllData();
      await downloadAllFromCloud();
      await prefs.setString('local_sync_time', cloudTime.toIso8601String());
      return true; 
    }
    return false; 
  }
}