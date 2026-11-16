
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _countryController = TextEditingController();
  final _avatarController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;

  String _userId = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _avatarController.addListener(_onAvatarChanged);
  }

  void _onAvatarChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('कृपया पहले Login करें।');
      }

      final profile = await supabase
          .from('profiles')
          .select(
            'username, display_name, bio, country, avatar_url',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception('आपकी Profile अभी उपलब्ध नहीं है।');
      }

      _userId = profile['username']?.toString() ?? '';

      _nameController.text =
          profile['display_name']?.toString() ?? '';

      _bioController.text =
          profile['bio']?.toString() ?? '';

      _countryController.text =
          profile['country']?.toString() ?? '';

      _avatarController.text =
          profile['avatar_url']?.toString() ?? '';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isValidImageUrl(String value) {
    if (value.isEmpty) return true;

    final uri = Uri.tryParse(value);

    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<void> _saveProfile() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Login session उपलब्ध नहीं है।');
      }

      final updatedProfile = await supabase
          .from('profiles')
          .update({
            'display_name': _nameController.text.trim(),
            'bio': _bioController.text.trim(),
            'country': _countryController.text.trim(),
            'avatar_url': _avatarController.text.trim(),
            'updated_at':
                DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id)
          .select('id')
          .maybeSingle();

      if (updatedProfile == null) {
        throw Exception(
          'Profile अपडेट नहीं हुई। कृपया दोबारा प्रयास करें।',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile सफलतापूर्वक सेव हुई।'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('सेव नहीं हुआ: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildProfilePhoto() {
    final imageUrl = _avatarController.text.trim();

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage: _isValidImageUrl(imageUrl) &&
                    imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: !_isValidImageUrl(imageUrl) ||
                    imageUrl.isEmpty
                ? const Icon(
                    Icons.person,
                    size: 55,
                    color: Colors.deepPurple,
                  )
                : null,
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(height: 10),
          Text(
            'Profile Photo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'नीचे Photo URL बदलकर अपनी Profile Photo अपडेट करें।',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            enabledBorder: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _avatarController.removeListener(_onAvatarChanged);

    _nameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _avatarController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_error!),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildProfilePhoto(),

              const SizedBox(height: 25),

              _buildField(
                label: 'ZOONL User ID',
                controller: TextEditingController(
                  text: _userId,
                ),
                readOnly: true,
              ),

              const SizedBox(height: 16),

              _buildField(
                label: 'Display Name',
                controller: _nameController,
                hint: 'अपना नाम लिखें',
                maxLength: 40,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'नाम जरूरी है।';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              _buildField(
                label: 'Country',
                controller: _countryController,
                hint: 'अपना देश लिखें',
                maxLength: 80,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Country जरूरी है।';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              _buildField(
                label: 'Bio',
                controller: _bioController,
                hint: 'अपने बारे में लिखें',
                maxLength: 300,
                maxLines: 4,
              ),

              const SizedBox(height: 12),

              _buildField(
                label: 'Profile Photo URL',
                controller: _avatarController,
                hint: 'https://...',
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (!_isValidImageUrl(
                    value?.trim() ?? '',
                  )) {
                    return 'सही Image URL डालें।';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: _saving
                      ? const SizedBox(
                          height: 23,
                          width: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
