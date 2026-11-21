import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/zoonl_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _countryController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _countries = [
    'United Arab Emirates', 'Saudi Arabia', 'Qatar', 'Kuwait', 'Bahrain',
    'Oman', 'India', 'Pakistan', 'Bangladesh', 'Nepal', 'Sri Lanka',
    'United Kingdom', 'United States', 'Canada', 'Australia', 'Germany',
    'France', 'Turkey', 'Egypt', 'Jordan', 'Other',
  ];

  bool _loading = true;
  bool _saving = false;
  bool _avatarUploading = false;
  bool _backgroundUploading = false;
  String _userId = '';
  String? _error;
  String? _avatarUrl;
  String? _backgroundUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('कृपया पहले Login करें।');

      final profile = await supabase.from('profiles')
          .select('display_name,bio,country,avatar_url,profile_background_url')
          .eq('id', user.id).maybeSingle();
      if (profile == null) throw Exception('आपकी Profile अभी उपलब्ध नहीं है।');

      final publicProfile = await supabase.from('user_public_profiles')
          .select('zoonl_id').eq('user_id', user.id).maybeSingle();

      _userId = publicProfile?['zoonl_id']?.toString() ?? 'Not available';
      _nameController.text = profile['display_name']?.toString() ?? '';
      _bioController.text = profile['bio']?.toString() ?? '';
      _countryController.text = profile['country']?.toString() ?? '';
      _avatarUrl = profile['avatar_url']?.toString();
      _backgroundUrl = profile['profile_background_url']?.toString();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadImage({required bool background}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (background ? _backgroundUploading : _avatarUploading) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: background ? 2200 : 1200,
      );
      if (picked == null) return;

      setState(() {
        if (background) {
          _backgroundUploading = true;
        } else {
          _avatarUploading = true;
        }
      });

      final file = File(picked.path);
      final size = await file.length();
      if (size > 15 * 1024 * 1024) {
        throw Exception('Image 15 MB से छोटी होनी चाहिए।');
      }

      final extension = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
      final kind = background ? 'profile-background' : 'avatar';
      final path = '${user.id}/$kind/${DateTime.now().microsecondsSinceEpoch}.$extension';

      await supabase.storage.from('avatars').upload(
        path,
        file,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

      if (background) {
        _backgroundUrl = publicUrl;
      } else {
        _avatarUrl = publicUrl;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload नहीं हुआ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _avatarUploading = false;
          _backgroundUploading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Login session उपलब्ध नहीं है।');

      final updated = await supabase.from('profiles').update({
        'display_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'country': _countryController.text.trim(),
        'avatar_url': _avatarUrl,
        'profile_background_url': _backgroundUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id).select('id').maybeSingle();

      if (updated == null) throw Exception('Profile update नहीं हुई।');

      await supabase.from('user_public_profiles').update({
        'avatar_url': _avatarUrl,
        'bio': _bioController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile सफलतापूर्वक सेव हुई।')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('सेव नहीं हुआ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _imageCard({
    required String title,
    required String subtitle,
    required String? url,
    required bool uploading,
    required VoidCallback onPick,
    required bool circular,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZoonlTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZoonlTheme.champagne.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(circular ? 100 : 14),
              child: Container(
                width: circular ? 112 : double.infinity,
                height: circular ? 112 : 116,
                color: const Color(0xFF211735),
                child: url == null || url.isEmpty
                    ? Icon(circular ? Icons.person : Icons.wallpaper,
                        size: circular ? 56 : 44, color: ZoonlTheme.champagne)
                    : Image.network(url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          circular ? Icons.person : Icons.wallpaper,
                          color: ZoonlTheme.champagne, size: 42)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: uploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_library_outlined),
              label: Text(uploading ? 'Uploading...' : 'Choose from phone gallery'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(20), child: Text(_error!))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _imageCard(
                title: 'PROFILE PHOTO',
                subtitle: 'अपने मोबाइल की Gallery से कोई भी उपयुक्त DP चुनें।',
                url: _avatarUrl,
                uploading: _avatarUploading,
                onPick: () => _pickAndUploadImage(background: false),
                circular: true,
              ),
              const SizedBox(height: 14),
              _imageCard(
                title: 'PROFILE BACKGROUND',
                subtitle: 'अपनी Profile के पीछे लगाने के लिए Gallery से Background चुनें।',
                url: _backgroundUrl,
                uploading: _backgroundUploading,
                onPick: () => _pickAndUploadImage(background: true),
                circular: false,
              ),
              const SizedBox(height: 20),
              _field(label: 'ZOONL User ID', controller: TextEditingController(text: _userId)),
              const SizedBox(height: 14),
              _field(
                label: 'Display Name',
                controller: _nameController,
                hint: 'अपना नाम लिखें',
                maxLength: 40,
                validator: (v) => v == null || v.trim().isEmpty ? 'नाम जरूरी है।' : null,
              ),
              const SizedBox(height: 14),
              const Text('Country', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                value: _countries.contains(_countryController.text)
                    ? _countryController.text : null,
                decoration: const InputDecoration(
                  hintText: 'देश चुनें',
                  border: OutlineInputBorder(),
                ),
                items: _countries.map((country) => DropdownMenuItem(
                  value: country, child: Text(country))).toList(),
                onChanged: (value) {
                  if (value != null) _countryController.text = value;
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Country चुनें।' : null,
              ),
              const SizedBox(height: 14),
              _field(label: 'Bio', controller: _bioController,
                hint: 'अपने बारे में लिखें', maxLength: 300, maxLines: 4),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving || _avatarUploading || _backgroundUploading
                      ? null : _saveProfile,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('SAVE PROFILE',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
