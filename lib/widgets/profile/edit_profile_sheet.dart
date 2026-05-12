import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

enum EditMode { identity, metrics }

/// Profil düzenleme bottom sheet'i.
class EditProfileSheet extends StatelessWidget {
  final String fullName;
  final String bio;
  final int age;
  final String gender;
  final String bloodType;
  final String allergies;
  final String emergencyContact;
  final double height;
  final double weight;
  final EditMode mode;
  final ValueChanged<ProfileUpdateResult> onSaved;

  const EditProfileSheet({
    super.key,
    required this.fullName,
    required this.bio,
    required this.age,
    required this.gender,
    required this.bloodType,
    required this.allergies,
    required this.emergencyContact,
    required this.height,
    required this.weight,
    required this.onSaved,
    this.mode = EditMode.identity,
  });

  void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileContent(
        initialName: fullName,
        initialBio: bio,
        age: age,
        gender: gender,
        bloodType: bloodType,
        allergies: allergies,
        emergencyContact: emergencyContact,
        height: height,
        weight: weight,
        mode: mode,
        onSave: (name, bio, age, gender, bloodType, allergies, emergencyContact, height, weight) async {
          final u = FirebaseAuth.instance.currentUser;
          if (u == null) return;

          // Display name güncelle
          await u.updateDisplayName(name);

          // Firestore'a kaydet — set(merge:true) kullanarak doküman yoksa oluşturur, varsa günceller
          await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
            'fullName': name,
            'bio': bio,
            'age': age,
            'gender': gender,
            'bloodType': bloodType,
            'allergies': allergies,
            'emergencyContact': emergencyContact,
            'height': height,
            'weight': weight,
          }, SetOptions(merge: true));

          // Risk skoru opsiyonel — başarısız olması profil kaydını etkilememeli
          try {
            await ApiService.fetchRiskScore(
              RiskApiRequest(age: age, gender: gender, height: height, weight: weight),
            );
          } catch (e) {
            debugPrint('Profil güncelleme sonrası risk skoru hesaplanamadı: $e');
          }

          onSaved(ProfileUpdateResult(
            name: name, bio: bio, age: age, gender: gender, 
            bloodType: bloodType, allergies: allergies, 
            emergencyContact: emergencyContact, height: height, weight: weight,
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ProfileUpdateResult {
  final String name, bio, gender, bloodType, allergies, emergencyContact;
  final int age;
  final double height, weight;
  const ProfileUpdateResult({
    required this.name, required this.bio, required this.age,
    required this.gender, required this.bloodType, 
    required this.allergies, required this.emergencyContact,
    required this.height, required this.weight,
  });
}

class _EditProfileContent extends StatefulWidget {
  final String initialName;
  final String initialBio;
  final int age;
  final String gender;
  final String bloodType;
  final String allergies;
  final String emergencyContact;
  final double height;
  final double weight;
  final EditMode mode;
  final Future<void> Function(String, String, int, String, String, String, String, double, double) onSave;

  const _EditProfileContent({
    required this.initialName,
    required this.initialBio,
    required this.age,
    required this.gender,
    required this.bloodType,
    required this.allergies,
    required this.emergencyContact,
    required this.height,
    required this.weight,
    required this.mode,
    required this.onSave,
  });

  @override
  State<_EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends State<_EditProfileContent> {
  late TextEditingController nameCtrl;
  late TextEditingController bioCtrl;
  late TextEditingController ageCtrl;
  late TextEditingController heightCtrl;
  late TextEditingController weightCtrl;
  late String selectedGender;
  late String selectedBloodType;
  late TextEditingController allergyCtrl;
  late TextEditingController contactCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialName);
    bioCtrl = TextEditingController(text: widget.initialBio);
    ageCtrl = TextEditingController(text: widget.age.toString());
    heightCtrl = TextEditingController(text: widget.height.toString());
    weightCtrl = TextEditingController(text: widget.weight.toString());
    selectedGender = widget.gender;
    selectedBloodType = widget.bloodType.isEmpty ? 'A Rh+' : widget.bloodType;
    allergyCtrl = TextEditingController(text: widget.allergies);
    contactCtrl = TextEditingController(text: widget.emergencyContact);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    bioCtrl.dispose();
    ageCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    allergyCtrl.dispose();
    contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
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
              Text(
                widget.mode == EditMode.identity ? 'Kimlik Bilgilerini Düzenle' : 'Vücut Metriklerini Düzenle', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)
              ),
              const SizedBox(height: 20),
              if (widget.mode == EditMode.identity) ...[
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
                      child: DropdownButtonFormField<String>(
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
                          if (v != null) setState(() => selectedGender = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedBloodType.isEmpty ? null : (const [
                    'A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', 'AB Rh+', 'AB Rh-', '0 Rh+', '0 Rh-'
                  ].contains(selectedBloodType) ? selectedBloodType : null),
                  decoration: InputDecoration(
                    labelText: 'Kan Grubu',
                    prefixIcon: const Icon(Icons.bloodtype_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    'A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', 'AB Rh+', 'AB Rh-', '0 Rh+', '0 Rh-'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedBloodType = v);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: allergyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Alerjiler',
                    prefixIcon: const Icon(Icons.warning_amber_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactCtrl,
                  decoration: InputDecoration(
                    labelText: 'Acil Durum Kişisi & No',
                    prefixIcon: const Icon(Icons.contact_phone_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
              ],
              if (widget.mode == EditMode.metrics) ...[
                TextField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Boy (cm)',
                    prefixIcon: const Icon(Icons.height),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Kilo (kg)',
                    prefixIcon: const Icon(Icons.monitor_weight_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final ageVal = int.tryParse(ageCtrl.text) ?? 30;
                    final heightVal = double.tryParse(heightCtrl.text) ?? 170.0;
                    final weightVal = double.tryParse(weightCtrl.text) ?? 75.0;
                    try {
                      await widget.onSave(
                        nameCtrl.text.trim(), 
                        bioCtrl.text.trim(), 
                        ageVal, 
                        selectedGender, 
                        selectedBloodType, 
                        allergyCtrl.text.trim(),
                        contactCtrl.text.trim(),
                        heightVal, 
                        weightVal
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profil güncellendi. Planlarınız yeni verilerle optimize edilecek.'),
                            backgroundColor: AppColors.secondary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Profil kaydedilemedi: $e'),
                            backgroundColor: AppColors.destructive,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
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
    );
  }
}
