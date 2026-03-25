import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; // لجلب AuthException

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required CrmRepository repository})
      : _repository = repository,
        super(LoginInitial());

  final CrmRepository _repository;

  /// 🌟 دالة تسجيل الدخول
  Future<void> signIn({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signIn(email: email, password: password);
      emit(LoginSuccess());
    } on AuthException catch (e) {
      // 1. ترجمة أخطاء Supabase الشهيرة
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        emit(LoginError(message: 'البريد الإلكتروني أو كلمة المرور غير صحيحة ❌'));
      } else {
        emit(LoginError(message: e.message)); // أخطاء أخرى من السحابة
      }
    } catch (e) {
      // 2. معالجة أخطاء الإنترنت والأخطاء الغريبة
      _handleGenericError(e);
    }
  }

  /// 🌟 دالة إنشاء حساب جديد
  Future<void> signUp({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signUp(email: email, password: password);
      emit(LoginSuccess());
    } on AuthException catch (e) {
      // 1. ترجمة أخطاء إنشاء الحساب
      if (e.message.toLowerCase().contains('user already registered')) {
        emit(LoginError(message: 'هذا البريد الإلكتروني مسجل مسبقاً لدينا! 📧'));
      } else if (e.message.toLowerCase().contains('password should be at least')) {
        emit(LoginError(message: 'كلمة المرور ضعيفة، يجب أن تكون 6 أحرف على الأقل 🔐'));
      } else {
        emit(LoginError(message: e.message));
      }
    } catch (e) {
      // 2. معالجة أخطاء الإنترنت
      _handleGenericError(e);
    }
  }

  /// 🌟 الفلتر الذكي لاصطياد أخطاء الإنترنت وترجمتها
  void _handleGenericError(Object e) {
    final errorStr = e.toString().toLowerCase();
    
    // إذا كان الخطأ يحتوي على كلمات تدل على انقطاع الإنترنت
    if (errorStr.contains('socket') || 
        errorStr.contains('host lookup') || 
        errorStr.contains('network') || 
        errorStr.contains('connection')) {
      emit(LoginError(message: '❌ لا يوجد اتصال بالإنترنت! يرجى التحقق من الشبكة والمحاولة مجدداً.'));
    } else {
      // إذا كان خطأً آخر غير معروف
      emit(LoginError(message: 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.'));
    }
  }
}