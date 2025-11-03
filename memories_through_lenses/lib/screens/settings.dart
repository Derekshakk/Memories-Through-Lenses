import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/providers/theme_provider.dart';
import 'package:memories_through_lenses/providers/user_provider.dart';
import 'package:memories_through_lenses/screens/change_password.dart';
import 'package:memories_through_lenses/screens/edit_profile.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Appearance Section

                // Account Section
                _buildSectionTitle(context, 'Account'),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.person_outline,
                      title: 'Edit Profile',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      context,
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                    // const Divider(height: 1),
                    // _buildActionTile(
                    //   context,
                    //   icon: Icons.logout,
                    //   title: 'Logout',
                    //   onTap: () {
                    //     _showLogoutDialog(context);
                    //   },
                    // ),
                  ],
                ),

                const SizedBox(height: 32),

                // Danger Zone
                _buildSectionTitle(context, 'Danger Zone', color: Colors.red),
                const SizedBox(height: 12),
                _buildSettingsCard(
                  context,
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.delete_forever,
                      title: 'Delete Account',
                      titleColor: Colors.red,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return const DeleteAccountPopup();
                          },
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title,
      {Color? color}) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? Theme.of(context).textTheme.headlineSmall?.color,
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context,
      {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(
        icon,
        color: titleColor ?? Theme.of(context).iconTheme.color,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: titleColor ?? Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            )
          : null,
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: Theme.of(context).iconTheme.color,
            )
          : null,
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Logout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Close dialog
                Navigator.of(dialogContext).pop();

                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                );

                try {
                  // Clear provider data first
                  final provider =
                      Provider.of<UserProvider>(context, listen: false);
                  provider.clear();

                  // Then logout - StreamBuilder will handle navigation
                  await Auth().logout();
                } catch (e) {
                  print('Error during logout: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error logging out. Please try again.'),
                      ),
                    );
                  }
                }
              },
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class DeleteAccountPopup extends StatelessWidget {
  const DeleteAccountPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        "Delete Account",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.red,
        ),
      ),
      content: Text(
        "Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.",
        style: GoogleFonts.poppins(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "Cancel",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          onPressed: () {
            // Add delete account logic here
            Auth().deleteUser().then(
              (value) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (route) => false);
              },
            );
          },
          child: Text(
            "Delete",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}
