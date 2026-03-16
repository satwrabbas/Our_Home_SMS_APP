import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import '../cubit/campaigns_cubit.dart';

class CampaignsPage extends StatelessWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CampaignsCubit(
        repository: context.read<CrmRepository>(),
      )..loadCampaignsData(),
      child: const CampaignsView(),
    );
  }
}

class CampaignsView extends StatelessWidget {
  const CampaignsView({super.key});

  // ==========================================
  // نافذة الإضافة والتعديل للمجموعات
  // ==========================================
  void _showGroupDialog(BuildContext context, {Group? group}) {
    final isEditing = group != null;
    final nameController = TextEditingController(text: isEditing ? group.name : '');
    final cubit = context.read<CampaignsCubit>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'تعديل المجموعة' : 'مجموعة جديدة'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم المجموعة (مثال: عملاء VIP)'),
        ),
        actions:[
          if (isEditing)
            TextButton(
              onPressed: () {
                cubit.deleteGroup(group);
                Navigator.pop(context);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('إلغاء')
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                isEditing
                    ? cubit.editGroup(group, nameController.text.trim())
                    : cubit.createGroup(nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // نافذة الإضافة والتعديل للحملات (مع منتقي الوقت ⏰)
  // ==========================================
  void _showScheduleDialog(BuildContext context, List<Group> groups, {Schedule? schedule}) {
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إنشاء مجموعة أولاً!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final isEditing = schedule != null;
    final messageController = TextEditingController(text: isEditing ? schedule.message : '');
    final dayController = TextEditingController(text: isEditing ? schedule.sendDay.toString() : '');
    
    Group? selectedGroup = isEditing 
        ? groups.firstWhere((g) => g.id == schedule.groupId, orElse: () => groups.first) 
        : groups.first; 

    // 🌟 جلب الوقت السابق إذا كنا نعدل، أو تعيين 9 صباحاً كافتراضي
    TimeOfDay selectedTime = isEditing 
        ? TimeOfDay(hour: schedule.sendHour, minute: schedule.sendMinute) 
        : const TimeOfDay(hour: 9, minute: 0);

    final cubit = context.read<CampaignsCubit>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'تعديل الحملة 🚀' : 'حملة أتمتة جديدة 🚀'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                DropdownButtonFormField<Group>(
                  value: selectedGroup,
                  decoration: const InputDecoration(labelText: 'اختر المجموعة'),
                  items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                  onChanged: (val) => setState(() => selectedGroup = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'نص الرسالة (SMS)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'يوم الإرسال في الشهر (1 - 31)'),
                ),
                const SizedBox(height: 16),
                
                // 🌟 زر اختيار الوقت
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.teal),
                    title: const Text('وقت الإرسال', style: TextStyle(fontSize: 14)),
                    // format يعرض الوقت بشكل جميل حسب لغة هاتف المستخدم (AM/PM)
                    subtitle: Text(selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    trailing: const Icon(Icons.edit, size: 20),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context, 
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions:[
            if (isEditing) 
              TextButton(
                onPressed: () {
                  cubit.deleteSchedule(schedule);
                  Navigator.pop(context);
                },
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('إلغاء')
            ),
            ElevatedButton(
              onPressed: () {
                final day = int.tryParse(dayController.text);
                if (messageController.text.isNotEmpty && day != null && day >= 1 && day <= 31 && selectedGroup != null) {
                  isEditing
                      ? cubit.editSchedule(
                          originalSchedule: schedule, 
                          newMessage: messageController.text.trim(), 
                          newSendDay: day, 
                          newSendHour: selectedTime.hour, 
                          newSendMinute: selectedTime.minute, // 🌟 نرسل الوقت الجديد
                        )
                      : cubit.createSchedule(
                          groupId: selectedGroup!.id, 
                          message: messageController.text.trim(), 
                          sendDay: day, 
                          sendHour: selectedTime.hour, 
                          sendMinute: selectedTime.minute, // 🌟 نرسل الوقت الجديد
                        );
                  Navigator.pop(context);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // بناء الشاشة الرئيسية (التبويبات)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحملات والمجموعات'),
          bottom: const TabBar(
            tabs:[
              Tab(icon: Icon(Icons.rocket_launch), text: 'الحملات'),
              Tab(icon: Icon(Icons.group), text: 'المجموعات'),
            ],
          ),
        ),
        body: BlocBuilder<CampaignsCubit, CampaignsState>(
          builder: (context, state) {
            if (state is CampaignsLoading) {
              return const Center(child: CircularProgressIndicator());
            } 
            else if (state is CampaignsError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
            } 
            else if (state is CampaignsLoaded) {
              final groups = state.groups;
              final schedules = state.schedules;

              return TabBarView(
                children:[
                  // ----------------------------------------
                  // التبويب الأول: الحملات المجدولة
                  // ----------------------------------------
                  Scaffold(
                    body: schedules.isEmpty
                        ? const Center(child: Text('لا توجد حملات أتمتة بعد. قم بإنشاء حملة.'))
                        : ListView.builder(
                            itemCount: schedules.length,
                            itemBuilder: (context, i) {
                              final schedule = schedules[i];
                              final groupName = groups.firstWhere((g) => g.id == schedule.groupId, orElse: () => const Group(id: -1, name: 'محذوفة')).name;
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.sms, color: Colors.white)),
                                  title: Text('لمجموعة: $groupName', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children:[
                                      Text('رسالة: ${schedule.message}'),
                                      const SizedBox(height: 4),
                                      // 🌟 عرض الوقت الجميل
                                      Text(
                                        '⌚ الإرسال: يوم ${schedule.sendDay}، الساعة ${TimeOfDay(hour: schedule.sendHour, minute: schedule.sendMinute).format(context)}', 
                                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  // 🌟 زر التشغيل والإيقاف للحملة
                                  trailing: Switch(
                                    value: schedule.isActive,
                                    activeColor: Colors.green,
                                    onChanged: (val) {
                                      context.read<CampaignsCubit>().toggleScheduleActive(schedule);
                                    },
                                  ),
                                  // عند الضغط على الكرت نفتح نافذة التعديل
                                  onTap: () => _showScheduleDialog(context, groups, schedule: schedule),
                                ),
                              );
                            },
                          ),
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _showScheduleDialog(context, groups),
                      icon: const Icon(Icons.add),
                      label: const Text('حملة جديدة'),
                    ),
                  ),

                  // ----------------------------------------
                  // التبويب الثاني: المجموعات
                  // ----------------------------------------
                  Scaffold(
                    body: groups.isEmpty
                        ? const Center(child: Text('لا توجد مجموعات بعد. قم بإنشاء مجموعة.'))
                        : ListView.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, i) {
                              final group = groups[i];
                              return ListTile(
                                leading: const Icon(Icons.folder, color: Colors.amber),
                                title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.grey),
                                  onPressed: () => _showGroupDialog(context, group: group),
                                ),
                              );
                            },
                          ),
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _showGroupDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('مجموعة جديدة'),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}