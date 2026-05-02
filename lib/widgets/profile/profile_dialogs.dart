import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Profil ekranındaki tüm bilgilendirme dialog'ları.
class ProfileDialogs {
  ProfileDialogs._();

  static void showPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gizlilik ve Güvenlik'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoItem(
              icon: Icons.health_and_safety_outlined,
              title: 'Sağlık Verileriniz',
              desc: 'Sağlık verileriniz yalnızca size özel yapay zeka analizleri için kullanılır. Üçüncü taraflarla paylaşılmaz.',
            ),
            SizedBox(height: 16),
            _InfoItem(
              icon: Icons.lock_outlined,
              title: 'Şifreleme',
              desc: 'Tüm verileriniz Firebase güvenlik altyapısıyla şifrelenmiş olarak saklanır.',
            ),
            SizedBox(height: 16),
            _InfoItem(
              icon: Icons.delete_outline,
              title: 'Veri Silme',
              desc: 'Hesabınızı sildiğinizde tüm kişisel verileriniz kalıcı olarak silinir.',
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anladım')),
        ],
      ),
    );
  }

  static void showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yardım ve Destek'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoItem(
              icon: Icons.play_circle_outline,
              title: 'Nasıl kullanılır?',
              desc: 'Her gün veri girerek yapay zeka analizi alabilirsiniz. Sağlık → Veri Gir menüsünden başlayın.',
            ),
            SizedBox(height: 12),
            _InfoItem(
              icon: Icons.sync_outlined,
              title: 'Veri senkronizasyonu',
              desc: 'Health Connect destekli cihazlarda verileriniz otomatik alınabilir.',
            ),
            SizedBox(height: 12),
            _InfoItem(
              icon: Icons.mail_outline,
              title: 'İletişim',
              desc: 'Sorun yaşıyorsanız destek@aksa.app adresine yazabilirsiniz.',
            ),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
        ],
      ),
    );
  }

  static void showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanım Koşulları'),
        content: const SingleChildScrollView(
          child: Text(
            'Bu uygulama kişisel sağlık takibi amacıyla geliştirilmiştir. '
            'Uygulama tıbbi teşhis veya tedavi amaçlı kullanılamaz. '
            'Sağlık sorunlarınız için mutlaka bir sağlık profesyoneline danışın.\n\n'
            'Verileriniz güvenli şekilde saklanmakta olup üçüncü taraflarla '
            'paylaşılmamaktadır. Uygulamayı kullanarak bu koşulları kabul etmiş sayılırsınız.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anladım')),
        ],
      ),
    );
  }

  static void showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gizlilik Politikası'),
        content: const SingleChildScrollView(
          child: Text(
            'Topladığımız veriler: ad, e-posta, sağlık metrikleri (kan basıncı, adım sayısı, uyku süresi).\n\n'
            'Verileriniz Firebase altyapısında şifreli olarak tutulur. '
            'Yapay zeka analizleri yalnızca kendi sunucularımızda gerçekleştirilir.\n\n'
            'Hesabınızı sildiğinizde tüm verileriniz 30 gün içinde kalıcı olarak silinir.',
            style: TextStyle(height: 1.6),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anladım')),
        ],
      ),
    );
  }

  static void showDeleteAccount(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Sil?'),
        content: const Text(
          'Hesabınızı sildiğinizde tüm verileriniz kalıcı olarak silinecektir. '
          'Bu işlem geri alınamaz.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

/// İkon + başlık + açıklama satırı — dialog'larda kullanılır.
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _InfoItem({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
