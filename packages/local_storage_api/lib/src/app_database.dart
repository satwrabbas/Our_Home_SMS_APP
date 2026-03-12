import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get phone => text().unique()(); 
  IntColumn get groupId => integer().nullable().references(Groups, #id)();
}

class Schedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id)();
  TextColumn get message => text()();
  IntColumn get sendDay => integer()();
  DateTimeColumn get lastSentDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

// تم الاحتفاظ به ولكن كـ "سجل إرسال" ليعرض في لوحة التحكم
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get phone => text()();
  TextColumn get body => text()();
  TextColumn get type => text()(); // 'sent' أو 'failed'
  DateTimeColumn get messageDate => dateTime()();
}

@DriftDatabase(tables: [Groups, Contacts, Schedules, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1; // بدأنا من الإصدار 1 لأننا في مشروع جديد تماماً

  // --- استعلامات المجموعات ---
  Future<List<Group>> getAllGroups() => select(groups).get();
  Future<int> insertGroup(GroupsCompanion group) => into(groups).insert(group);

  // --- استعلامات جهات الاتصال ---
  Future<List<Contact>> getAllContacts() => select(contacts).get();
  Future<int> insertContact(ContactsCompanion contact) => into(contacts).insert(contact, mode: InsertMode.insertOrIgnore);  Future<int> deleteContact(Contact contact) => delete(contacts).delete(contact);

  // 🌟 الدالة الجديدة: تحديث صريح لحقل المجموعة فقط متجاهلة رقم الهاتف
  Future<int> updateContactGroupDB(int id, int? groupId) {
    return (update(contacts)..where((t) => t.id.equals(id))).write(
      ContactsCompanion(groupId: Value(groupId)),
    );
  }

  
  // --- استعلامات الجدولة والأتمتة ---
  Future<List<Schedule>> getAllSchedules() => select(schedules).get();
  Future<int> insertSchedule(SchedulesCompanion schedule) => into(schedules).insert(schedule);

  // --- استعلامات سجل الرسائل (للوحة التحكم) ---
  // قمنا بتعديل الاستعلام ليجلب الأحدث أولاً ليفيدنا في الإحصائيات
  Future<List<Message>> getAllMessages() => (select(messages)..orderBy([(t) => OrderingTerm.desc(t.messageDate)])).get();
  Future<int> insertMessage(MessagesCompanion msg) => into(messages).insert(msg);


}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'crm_auto_sms.sqlite')); // اسم قاعدة البيانات
    return NativeDatabase.createInBackground(file);
  });
}