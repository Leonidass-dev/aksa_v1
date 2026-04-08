import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/user_profile_service.dart';
import '../services/image_upload_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _gender = 'M';

  File? _pickedImage;
  UserProfile? _user;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final profile = await UserProfileService.getProfile();

    if (profile != null) {
      _user = profile;
    } else {
      final u = FirebaseAuth.instance.currentUser!;
      _user = UserProfile(
        uid: u.uid,
        fullName: u.displayName ?? '',
        email: u.email ?? '',
        age: 25,
        height: 170.0,
        weight: 70.0,
        gender: 'M',
        photoUrl: u.photoURL ?? '',
      );
    }

    _nameCtrl.text = _user!.fullName;
    _bioCtrl.text = _user!.bio ?? '';
    _ageCtrl.text = _user!.age.toString();
    _heightCtrl.text = _user!.height.toString();
    _weightCtrl.text = _user!.weight.toString();
    _gender = _user!.gender;
    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Fotoğrafı Firestore 1MB sınırını aşmayacak şekilde küçültüyoruz.
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 400,
      maxHeight: 400,
    );
    if (xfile == null) return;
    setState(() => _pickedImage = File(xfile.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      String? photoUrlToSave = _user!.photoUrl;

      // Eğer yeni fotoğraf seçilmişse Base64'e çeviriyoruz
      if (_pickedImage != null) {
        final uploadService =
            Base64ImageUploadService(); // İleride buraya FirebaseStorageUploadService() verebilirsiniz.
        final url = await uploadService.uploadImage(_pickedImage!, _user!.uid);
        if (url != null) {
          photoUrlToSave = url;
        }
      }

      final updated = UserProfile(
        uid: _user!.uid,
        fullName: _nameCtrl.text.trim(),
        email: _user!.email,
        age: int.tryParse(_ageCtrl.text) ?? 25,
        height: double.tryParse(_heightCtrl.text) ?? 170.0,
        weight: double.tryParse(_weightCtrl.text) ?? 70.0,
        gender: _gender,
        bio: _bioCtrl.text.trim(),
        photoUrl: photoUrlToSave,
      );

      await UserProfileService.saveProfile(updated);

      setState(() {
        _user = updated;
        _pickedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla güncellendi ✓'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final photoWidget = _pickedImage != null
        ? FileImage(_pickedImage!)
        : ImageUtils.getPhotoProvider(_user!.photoUrl);

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profilim'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profil fotoğrafı
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundImage: photoWidget,
                      child: photoWidget == null
                          ? const Icon(Icons.person, size: 56)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _user!.email,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _nameCtrl,
                decoration: inputDecoration.copyWith(
                  labelText: 'Ad Soyad',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ad Soyad boş olamaz'
                    : null,
                onTapOutside: (event) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Yaş',
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 120) {
                          return 'Geçerli bir yaş girin';
                        }
                        return null;
                      },
                      onTapOutside: (event) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: inputDecoration.copyWith(
                        labelText: 'Cinsiyet',
                        prefixIcon: const Icon(Icons.transgender),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Erkek')),
                        DropdownMenuItem(value: 'F', child: Text('Kadın')),
                        DropdownMenuItem(value: 'O', child: Text('Diğer')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: inputDecoration.copyWith(
                        labelText: 'Boy (cm)',
                        prefixIcon: const Icon(Icons.height),
                      ),
                      onTapOutside: (event) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: inputDecoration.copyWith(
                        labelText: 'Kilo (kg)',
                        prefixIcon: const Icon(Icons.monitor_weight_outlined),
                      ),
                      onTapOutside: (event) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: inputDecoration.copyWith(
                  labelText: 'Hakkımda',
                  prefixIcon: const Icon(Icons.edit_note),
                  alignLabelWithHint: true,
                ),
                onTapOutside: (event) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Değişiklikleri Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
