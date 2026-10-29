import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../constants/asset_paths.dart';
import '../../constants/strings_tr.dart';
import '../widgets/ref_image.dart';
import 'designs_tab.dart';

/// "Anılar" sekmesi: albüm önerileri tanıtımı ve fotoğraf kitabına giriş.
class MemoriesTab extends StatelessWidget {
  const MemoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    const captions = ['Yolculuklar', 'Birlikte', 'Yılın Özeti'];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(S.memoriesTitle, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(S.memoriesBody, style: TextStyle(fontSize: 15, color: context.mutedText)),
          const SizedBox(height: 20),
          for (var i = 0; i < AssetPaths.memoriesExamples.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.4,
                      child: RefImage(AssetPaths.memoriesExamples[i], icon: Icons.auto_awesome_outlined),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          captions[i],
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textStrong),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => openProducts(context), child: const Text(S.createPhotoBook)),
        ],
      ),
    );
  }
}
