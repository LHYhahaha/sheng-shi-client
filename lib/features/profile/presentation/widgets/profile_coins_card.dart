import 'package:flutter/material.dart';

import '../../application/profile_controller.dart';

class ProfileCoinsCard extends StatelessWidget {
  const ProfileCoinsCard({required this.coins, required this.onTap, super.key});

  final ProfileCoinsState coins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: coins.topUpEnabled ? onTap : null,
      child: Image.asset(
        'assets/images/profile/coins_block_figma.png',
        height: 78,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
