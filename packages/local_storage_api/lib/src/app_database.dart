import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Groups extends Table {
  TextColumn get id => text()(); // 🌟 يجب أن تكون text
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Contacts extends Table {
  TextColumn get id => text()(); // 🌟 text
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get phone => text().unique()(); 
  TextColumn get groupId => text().nullable().references(Groups, #id)(); // 🌟 text
  @override
  Set<Column> get primaryKey => {id};
}

class Schedules extends Table {
  TextColumn get id => text()(); // 🌟 text
  TextColumn get groupId => text().references(Groups, #id)(); // 🌟 text
  TextColumn get message => text()();
  IntColumn get sendDay => integer()();
  IntColumn get sendHour => integer().withDefault(const Constant(9))(); 
  IntColumn get sendMinute => integer().withDefault(const Constant(0))(); 
  TextColumn get targetDeviceId => text().nullable()(); 
  DateTimeColumn get lastSentDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()(); // 🌟 text
  TextColumn get phone => text()();
  TextColumn get body => text()();
  TextColumn get type => text()(); 
  DateTimeColumn get messageDate => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables:[Groups, Contacts, Schedules, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2; 

  Future<List<Group>> getAllGroups() => select(groups).get();
  Future<int> insertGroup(GroupsCompanion group) => into(groups).insert(group);
  Future<int> deleteGroup(Group group) => delete(groups).delete(group);
  Future<bool> updateGroup(Group group) => update(groups).replace(group);

  Future<List<Contact>> getAllContacts() => (select(contacts)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  Future<int> insertContact(ContactsCompanion contact) => into(contacts).insert(contact, mode: InsertMode.insertOrIgnore);  
  Future<int> deleteContact(Contact contact) => delete(contacts).delete(contact);
  
  Future<int> updateContactGroupDB(String id, String? groupId) {
    return (update(contacts)..where((t) => t.id.equals(id))).write(ContactsCompanion(groupId: Value(groupId)));
  }

  Future<List<Schedule>> getAllSchedules() => select(schedules).get();
  Future<int> insertSchedule(SchedulesCompanion schedule) => into(schedules).insert(schedule);
  Future<int> deleteSchedule(Schedule schedule) => delete(schedules).delete(schedule);
  Future<bool> updateSchedule(Schedule schedule) => update(schedules).replace(schedule);

  Future<void> clearGroupFromContacts(String groupId) {
    return (update(contacts)..where((t) => t.groupId.equals(groupId))).write(const ContactsCompanion(groupId: Value(null)));
  }

  Future<List<Message>> getAllMessages() => (select(messages)..orderBy([(t) => OrderingTerm.desc(t.messageDate)])).get();
  Future<int> insertMessage(MessagesCompanion msg) => into(messages).insert(msg);

  Future<void> clearAllData() {
    return transaction(() async {
      await delete(messages).go();
      await delete(schedules).go();
      await delete(contacts).go();
      await delete(groups).go();
    });
  }

  Future<void> upsertGroup(GroupsCompanion group) => into(groups).insertOnConflictUpdate(group);
  Future<void> upsertSchedule(SchedulesCompanion schedule) => into(schedules).insertOnConflictUpdate(schedule);
  Future<void> upsertMessage(MessagesCompanion msg) => into(messages).insertOnConflictUpdate(msg);
  Future<void> upsertContact(ContactsCompanion contact) => into(contacts).insert(contact, mode: InsertMode.insertOrReplace);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'crm_auto_sms_v2.sqlite')); 
    return NativeDatabase.createInBackground(file);
  });
}