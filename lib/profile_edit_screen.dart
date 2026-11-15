
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _avatarController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _userId = '';
  String? _error;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
      _bioController.text = profile['bio']?.toString() ?? '';
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Login session उपलब्ध नहीं है।');
      }

      await supabase.from('profiles').update({
        'display_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'country': _countryController.text.trim(),
        'avatar_url': _avatarController.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);

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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!),
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_avatarController.text.trim().isNotEmpty)
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage:
                        NetworkImage(_avatarController.text.trim()),
                  ),
                ),
              const SizedBox(height: 20),

              const Text('ZOONL User ID'),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: _userId,
                readOnly: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),
              const Text('Display Name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: 'अपना नाम लिखें',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'नाम जरूरी है।';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),
              const Text('Country'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  hintText: 'अपना देश लिखें',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),
              const Text('Bio'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioController,
                maxLength: 300,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'अपने बारे में लिखें',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),
              const Text('Profile Photo URL'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _avatarController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
