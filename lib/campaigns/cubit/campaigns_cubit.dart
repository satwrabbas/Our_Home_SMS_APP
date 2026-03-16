import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart'; // لجلب أنواع Group و Schedule

part 'campaigns_state.dart';

class CampaignsCubit extends Cubit<CampaignsState> {
  CampaignsCubit({required CrmRepository repository})
      : _repository = repository,
        super(CampaignsInitial());

  final CrmRepository _repository;

  /// جلب المجموعات والحملات معاً لعرضها في الشاشة
  Future<void> loadCampaignsData() async {
    emit(CampaignsLoading());
    try {
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      
      emit(CampaignsLoaded(groups: groups, schedules: schedules));
    } catch (e) {
      emit(CampaignsError(message: 'حدث خطأ في جلب البيانات: $e'));
    }
  }

  /// إنشاء مجموعة جديدة
  Future<void> createGroup(String name) async {
    try {
      await _repository.addGroup(name);
      await loadCampaignsData(); 
      
      _repository.syncAllToCloud(); // ☁️ مزامنة صامتة
    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء المجموعة: $e'));
    }
  }

  /// إنشاء حملة (مع دعم الساعة والدقيقة ⏰)
  Future<void> createSchedule({
    required int groupId, 
    required String message, 
    required int sendDay, 
    required int sendHour, 
    required int sendMinute
  }) async {
    try {
      await _repository.addSchedule(
        groupId: groupId, 
        message: message, 
        sendDay: sendDay, 
        sendHour: sendHour, 
        sendMinute: sendMinute
      );
      await loadCampaignsData(); 
      
      _repository.syncAllToCloud(); // ☁️ مزامنة صامتة
    } catch (e) {
      emit(CampaignsError(message: 'خطأ في إنشاء الحملة: $e'));
    }
  }

  // --- دوال الحذف والتعديل ---
  Future<void> deleteGroup(Group group) async {
    try {
      await _repository.deleteGroup(group);
      await loadCampaignsData(); 
      
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء الحذف: $e'));
    }
  }

  Future<void> editGroup(Group group, String newName) async {
    try {
      await _repository.updateGroup(group.copyWith(name: newName));
      await loadCampaignsData();
      
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء التعديل: $e'));
    }
  }

  Future<void> deleteSchedule(Schedule schedule) async {
    try {
      await _repository.deleteSchedule(schedule);
      await loadCampaignsData();
      
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء حذف الحملة: $e'));
    }
  }

  /// تعديل حملة (مع دعم الساعة والدقيقة ⏰)
  Future<void> editSchedule({
    required Schedule originalSchedule,
    required String newMessage,
    required int newSendDay,
    required int newSendHour,
    required int newSendMinute,
  }) async {
    try {
      await _repository.updateSchedule(
        originalSchedule.copyWith(
          message: newMessage, 
          sendDay: newSendDay, 
          sendHour: newSendHour, 
          sendMinute: newSendMinute
        ),
      );
      await loadCampaignsData();
      
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء تعديل الحملة: $e'));
    }
  }

  /// دالة لتبديل حالة تشغيل/إيقاف الحملة
  Future<void> toggleScheduleActive(Schedule schedule) async {
    try {
      await _repository.updateSchedule(schedule.copyWith(isActive: !schedule.isActive));
      await loadCampaignsData(); 
      
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(CampaignsError(message: 'خطأ أثناء تبديل حالة الحملة: $e'));
    }
  }
}