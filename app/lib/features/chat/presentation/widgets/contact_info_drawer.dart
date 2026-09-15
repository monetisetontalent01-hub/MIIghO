import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/miigho_avatar.dart';
import '../../models/chat_models.dart';
import '../bloc/chat_bloc.dart';

class ContactInfoDrawer extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final bool isGroup;
  final bool isOnline;
  final String? conversationId;

  const ContactInfoDrawer({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.isGroup = false,
    this.isOnline = false,
    this.conversationId,
  });

  @override
  State<ContactInfoDrawer> createState() => _ContactInfoDrawerState();
}

class _ContactInfoDrawerState extends State<ContactInfoDrawer> {
  List<ConversationMemberDetail> _members = [];
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    if (widget.isGroup && widget.conversationId != null) {
      _loadMembers();
    }
  }

  @override
  void didUpdateWidget(covariant ContactInfoDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId &&
        widget.isGroup &&
        widget.conversationId != null) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await context
          .read<ChatBloc>()
          .chatRepository
          .getConversationMembers(widget.conversationId!);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: isDark ? MiighoColors.surface1 : MiighoColors.lightSurface1,
        border: Border(
          left: BorderSide(
            color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          AppBar(
            title: Text(widget.isGroup ? 'Infos du groupe' : 'Infos du contact'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: MiighoAvatar(
                    name: widget.title,
                    avatarUrl: widget.avatarUrl,
                    size: MiighoAvatarSize.xl,
                    isOnline: widget.isOnline,
                    showPresenceIndicator: !widget.isGroup,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    widget.isGroup
                        ? (_members.isNotEmpty
                            ? '${_members.length} membres'
                            : 'Groupe de discussion MÏÏghO')
                        : (widget.isOnline ? 'En ligne actuellement' : 'Hors ligne'),
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isOnline
                          ? const Color(0xFF10B981)
                          : (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Raccourcis d'actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickAction(
                      context,
                      icon: Icons.call_outlined,
                      label: 'Appel Audio',
                      isDark: isDark,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Appels audio P2P (Phase suivante)')),
                        );
                      },
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.videocam_outlined,
                      label: 'Appel Vidéo',
                      isDark: isDark,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Appels vidéo WebRTC (Phase suivante)')),
                        );
                      },
                    ),
                    _buildQuickAction(
                      context,
                      icon: Icons.search_rounded,
                      label: 'Recherche',
                      isDark: isDark,
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Membres du groupe (si groupe)
                if (widget.isGroup) ...[
                  _buildSectionHeader('MEMBRES DU GROUPE (${_members.length})'),
                  if (_isLoadingMembers)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun membre disponible',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                        ),
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          return ListTile(
                            dense: true,
                            leading: MiighoAvatar(
                              name: member.displayName,
                              avatarUrl: member.avatarUrl.isNotEmpty ? member.avatarUrl : null,
                              size: MiighoAvatarSize.sm,
                            ),
                            title: Text(
                              member.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary,
                              ),
                            ),
                            subtitle: member.miighoId.isNotEmpty
                                ? Text(
                                    '@${member.miighoId}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
                                    ),
                                  )
                                : null,
                            trailing: member.isAdmin
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MiighoColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: MiighoColors.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: const Text(
                                      'Admin',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: MiighoColors.primary,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],

                // Chiffrement de bout en bout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? MiighoColors.borderSubtle : MiighoColors.lightBorderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chiffrement de bout en bout',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                            Text(
                              'Vos messages et fichiers sont sécurisés (Signal Protocol).',
                              style: TextStyle(fontSize: 11, color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Médias & Liens partagés
                _buildSectionHeader('MÉDIAS & FICHIERS PARTAGÉS'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? MiighoColors.surface2 : MiighoColors.lightSurface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, color: MiighoColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '12 photos, 3 documents partagés',
                          style: TextStyle(fontSize: 12, color: isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? MiighoColors.textMuted : MiighoColors.lightTextMuted),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Paramètres de conversation
                _buildSectionHeader('OPTIONS'),
                _buildOptionTile(
                  icon: Icons.notifications_off_outlined,
                  title: 'Mettre en sourdine',
                  isDark: isDark,
                  onTap: () {},
                ),
                _buildOptionTile(
                  icon: Icons.block_flipped,
                  title: widget.isGroup ? 'Quitter le groupe' : 'Bloquer le contact',
                  color: MiighoColors.error,
                  isDark: isDark,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: MiighoColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: MiighoColors.primaryAlpha,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: MiighoColors.primaryLight, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required bool isDark,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color ?? (isDark ? MiighoColors.textSecondary : MiighoColors.lightTextSecondary), size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color ?? (isDark ? MiighoColors.textPrimary : MiighoColors.lightTextPrimary),
        ),
      ),
      onTap: onTap,
    );
  }
}
