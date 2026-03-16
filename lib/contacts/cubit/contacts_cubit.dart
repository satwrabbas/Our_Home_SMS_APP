import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as phone_contacts;

part 'contacts_state.dart';

class ContactsCubit extends Cubit<ContactsState> {
  ContactsCubit({required CrmRepository repository})
      : _repository = repository,
        super(ContactsInitial());

  final CrmRepository _repository;

  /// جلب العملاء والمجموعات معاً
  Future<void> loadContacts() async {
    emit(ContactsLoading());
    try {
      final contacts = await _repository.getContacts();
      final groups = await _repository.getGroups(); // 🌟 جلبنا المجموعات أيضاً
      emit(ContactsLoaded(contacts: contacts, groups: groups));
    } catch (e) {
      emit(ContactsError(message: e.toString()));
    }
  }

  /// ربط العميل بالمجموعة
  Future<void> assignGroup(Contact contact, int? groupId) async {
    try {
      await _repository.updateContactGroup(contact, groupId);
      await loadContacts(); // تحديث الشاشة فوراً للمستخدم
      
      // 🌟 السحر هنا: نأمر التطبيق برفع التعديل للسحابة بصمت! (Fire and Forget)
      _repository.syncAllToCloud(); 
      
    } catch (e) {
      emit(ContactsError(message: 'خطأ في تعيين المجموعة: $e'));
    }
  }

  /// مزامنة الهاتف (كما أصلحناها سابقاً)
  Future<void> syncFromPhone() async {
    emit(ContactsSyncing());
    try {
      final status = await phone_contacts.FlutterContacts.permissions.request(
        phone_contacts.PermissionType.read,
      );

      if (status == phone_contacts.PermissionStatus.granted || status == phone_contacts.PermissionStatus.limited) {
        final contactsFromPhone = await phone_contacts.FlutterContacts.getAll(
          properties: {
            phone_contacts.ContactProperty.name,
            phone_contacts.ContactProperty.phone,
          },
        );

        final List<Map<String, String>> formattedContacts =[];
        for (var c in contactsFromPhone) {
          if (c.phones.isNotEmpty) {
            formattedContacts.add({
              'name': c.displayName ?? 'بدون اسم',
              'phone': c.phones.first.number,
            });
          }
        }

        await _repository.saveSyncedContacts(formattedContacts);
        await loadContacts();
      } else {
        emit(ContactsError(message: 'تم رفض صلاحية الوصول لجهات الاتصال'));
      }
    } catch (e) {
      emit(ContactsError(message: 'حدث خطأ أثناء المزامنة: $e'));
    }
  }
}