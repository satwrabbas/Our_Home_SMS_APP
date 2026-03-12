import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:telephony/telephony.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required CrmRepository repository})
      : _repository = repository,
        super(DashboardLoading());

  final CrmRepository _repository;
  final Telephony telephony = Telephony.instance;

  /// تحميل الإحصائيات لعرضها في الشاشة
  Future<void> loadDashboard() async {
    try {
      final contacts = await _repository.getContacts();
      final groups = await _repository.getGroups();
      final schedules = await _repository.getSchedules();
      final logs = await _repository.getMessageLogs();

      emit(DashboardLoaded(
        contactsCount: contacts.length,
        groupsCount: groups.length,
        schedulesCount: schedules.length,
        recentLogs: logs,
      ));
    } catch (e) {
      // تجاهل الأخطاء البسيطة في لوحة التحكم
    }
  }

  /// 🚀 المحرك الذكي للأتمتة (Automation Engine)
  Future<void> runAutomationEngine() async {
    // 1. تغيير الحالة لـ "جاري التشغيل" لندور أيقونة التحميل في الشاشة
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      emit(DashboardLoaded(
        contactsCount: currentState.contactsCount,
        groupsCount: currentState.groupsCount,
        schedulesCount: currentState.schedulesCount,
        recentLogs: currentState.recentLogs,
        isEngineRunning: true,
      ));
    }

    try {
      if (!Platform.isAndroid) throw 'ميزة إرسال الـ SMS متاحة للأندرويد فقط!';

      // 2. طلب صلاحية الـ SMS
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      if (permissionsGranted == null || !permissionsGranted) {
        throw 'لم يتم منح صلاحية الرسائل SMS';
      }

      // 3. جلب بيانات اليوم
      final int currentDay = DateTime.now().day;
      final schedules = await _repository.getSchedules();
      final contacts = await _repository.getContacts();

      int messagesSentCount = 0;

      // 4. تشغيل فلتر الذكاء: ابحث عن حملة مخصصة لليوم
      for (var schedule in schedules) {
        if (schedule.isActive && schedule.sendDay == currentDay) {
          
          // ابحث عن العملاء الذين ينتمون لمجموعة هذه الحملة
          final targetContacts = contacts.where((c) => c.groupId == schedule.groupId).toList();

          // إرسال الرسائل
          for (var contact in targetContacts) {
            await telephony.sendSms(to: contact.phone, message: schedule.message);
            messagesSentCount++;
            
            // حفظ في السجل
            await _repository.addMessageLog(
              phone: contact.phone, 
              body: schedule.message, 
              type: 'sent_auto'
            );
            
            // تأخير بسيط ثانية واحدة بين كل رسالة لتجنب حظر شريحة الاتصال (Spam)
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      // 5. الانتهاء وإعادة تحميل السجلات الجديدة
      await loadDashboard();
      
      final finalState = state as DashboardLoaded;
      emit(DashboardLoaded(
        contactsCount: finalState.contactsCount,
        groupsCount: finalState.groupsCount,
        schedulesCount: finalState.schedulesCount,
        recentLogs: finalState.recentLogs,
        isEngineRunning: false, // إيقاف دوران التحميل
        engineStatusMessage: messagesSentCount > 0 
            ? '🚀 تمت الأتمتة! أُرسلت $messagesSentCount رسالة بنجاح.' 
            : '✅ المحرك عمل، ولكن لا يوجد حملات مجدولة لتاريخ اليوم ($currentDay).',
      ));

    } catch (e) {
      await loadDashboard(); // العودة للحالة الطبيعية
      final errorState = state as DashboardLoaded;
      emit(DashboardLoaded(
        contactsCount: errorState.contactsCount,
        groupsCount: errorState.groupsCount,
        schedulesCount: errorState.schedulesCount,
        recentLogs: errorState.recentLogs,
        isEngineRunning: false,
        engineStatusMessage: '❌ خطأ: $e',
      ));
    }
  }



  /// 🔄 المزامنة الشاملة (رفع + تنزيل)
  Future<void> syncDataToCloud() async {
    if (state is DashboardLoaded) {
      final currentState = state as DashboardLoaded;
      
      emit(DashboardLoaded(
        contactsCount: currentState.contactsCount,
        groupsCount: currentState.groupsCount,
        schedulesCount: currentState.schedulesCount,
        recentLogs: currentState.recentLogs,
        isEngineRunning: true,
        engineStatusMessage: '🔄 جاري المزامنة الشاملة (رفع وتنزيل)...',
      ));

      try {
        // 1. رفع البيانات الجديدة من الهاتف للسحابة
        await _repository.syncAllToCloud();
        
        // 2. تنزيل البيانات الجديدة من السحابة للهاتف
        await _repository.downloadAllFromCloud();
        
        // 3. إعادة تحميل لوحة التحكم لتعكس الأرقام الجديدة
        await loadDashboard();
        
        final newState = state as DashboardLoaded;
        emit(DashboardLoaded(
          contactsCount: newState.contactsCount,
          groupsCount: newState.groupsCount,
          schedulesCount: newState.schedulesCount,
          recentLogs: newState.recentLogs,
          isEngineRunning: false,
          engineStatusMessage: '✅ تمت المزامنة بنجاح!',
        ));
      } catch (e) {
        emit(DashboardLoaded(
          contactsCount: currentState.contactsCount,
          groupsCount: currentState.groupsCount,
          schedulesCount: currentState.schedulesCount,
          recentLogs: currentState.recentLogs,
          isEngineRunning: false,
          engineStatusMessage: '❌ فشلت المزامنة: $e',
        ));
      }
    }
  } 
}