import 'package:flutter/material.dart';

import '../../application/profile_controller.dart';

class ProfileMembershipCard extends StatelessWidget {
  const ProfileMembershipCard({
    required this.membership,
    required this.onTap,
    super.key,
  });

  final ProfileMembershipState membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 143,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: membership.entryEnabled ? onTap : null,
        child: Image.asset(
          'assets/images/profile/membership_block_figma.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
