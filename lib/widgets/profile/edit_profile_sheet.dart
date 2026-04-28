import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

/// Profil düzenleme bottom sheet'i.
class EditProfileSheet extends StatelessWidget {
  final String fullName;
  final String bio;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final ValueChanged<ProfileUpdateResult> onSaved;

  const EditProfileSheet({
    super.key,
    required this.fullName,
    required this.bio,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.onSaved,
  });

  void show(BuildContext context) {
    final nameCtrl = TextEditingController(text: fullName);
    final bioCtrl = TextEditingController(text: bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileContent(
        nameCtrl: nameCtrl,
        bioCtrl: bioCtrl,
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        onSave: (name, bio, age, gender, height, weight) async {
          final u = FirebaseAuth.instance.currentUser;
          if (u == null) return;
          await u.updateDisplayName(name);
          await FirebaseFirestore.instance.collection('users').doc(u.uid).update({
            'fullName': name,
            'bio': bio,
            'age': age,
            'gender': gender,
            'height': height,
            'weight': weight,
          });

          await ApiService.fetchRiskScore(
            RiskApiRequest(age: age, gender: gender, height: height, weight: weight),
          );

          onSaved(ProfileUpdateResult(
            name: name, bio: bio, age: age, gender: gender, height: height, weight: weight,
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ProfileUpdateResult {
  final String name, bio, gender;
  final int age;
  final double height, weight;
  const ProfileUpdateResult({
    required this.name, required this.bio, required this.age,
    required this.gender, required this.height, required this.weight,
  });
}

class _EditProfileContent extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController bioCtrl;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final Future<void> Function(String, String, int, String, double, double) onSave;

  const _EditProfileContent({
    required this.nameCtrl,
    required this.bioCtrl,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ageCtrl = TextEditingController(text: age.toString());
    final heightCtrl = TextEditingController(text: height.toString());
    String selectedGender = gender;
    double selectedWeight = weight;

    return StatefulBuilder(
      builder: (context, setInternalState) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Profili Düzenle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Yaş',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Boy (cm)',
                        prefixIcon: const Icon(Icons.height),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: selectedWeight.toString()),
                keyboardType: TextInputType.number,
                onChanged: (v) => setInternalState(() => selectedWeight = double.tryParse(v) ?? selectedWeight),
                decoration: InputDecoration(
                  labelText: 'Kilo (kg)',
                  prefixIcon: const Icon(Icons.monitor_weight_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedGender,
                decoration: InputDecoration(
                  labelText: 'Cinsiyet',
                  prefixIcon: const Icon(Icons.wc),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Erkek')),
                  DropdownMenuItem(value: 'F', child: Text('Kadın')),
                ],
                onChanged: (v) {
                  if (v != null) setInternalState(() => selectedGender = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioCtrl,
                maxLines: 2,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Hakkımda',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final ageVal = int.tryParse(ageCtrl.text) ?? 30;
                    final heightVal = double.tryParse(heightCtrl.text) ?? 170.0;
                    await onSave(nameCtrl.text.trim(), bioCtrl.text.trim(), ageVal, selectedGender, heightVal, selectedWeight);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kaydet', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
