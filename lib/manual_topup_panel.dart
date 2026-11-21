import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManualTopupPanel extends StatefulWidget {
  const ManualTopupPanel({super.key, required this.userId});
  final String userId;
  @override
  State<ManualTopupPanel> createState() => _ManualTopupPanelState();
}

class _ManualTopupPanelState extends State<ManualTopupPanel> {
  final _db = Supabase.instance.client;
  final _picker = ImagePicker();
  final _reference = TextEditingController();
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _requests = [];
  String? _channelId;
  String? _receiptPath;
  int _amount = 10;
  bool _loading = true, _uploading = false, _submitting = false;
  String? _error, _message;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final channels = await _db.from('manual_topup_payment_channels')
          .select('id,label,country,payment_method,account_name,account_number,whatsapp_number,instructions,agency_name,agency_code,agency_zoonl_id')
          .eq('is_active', true).order('created_at');
      final requests = await _db.from('manual_topup_requests')
          .select('id,amount_usd,coins,request_status,payment_reference,created_at,review_note')
          .eq('user_id', widget.userId).order('created_at', ascending: false).limit(15);
      if (!mounted) return;
      setState(() {
        _channels = (channels as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _requests = (requests as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (_channelId == null && _channels.isNotEmpty) _channelId = _channels.first['id'].toString();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickReceipt() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (picked == null) return;
      final file = File(picked.path);
      if (await file.length() > 15 * 1024 * 1024) throw Exception('Receipt image must be smaller than 15 MB.');
      setState(() { _uploading = true; _error = null; _message = null; });
      final path = '${widget.userId}/manual-topup/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await _db.storage.from('topup-receipts-private').upload(path, file,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
      if (mounted) setState(() => _receiptPath = path);
    } catch (e) {
      if (mounted) setState(() => _error = 'Receipt upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _uploading) return;
    if (_channelId == null || _receiptPath == null || _reference.text.trim().length < 3) {
      setState(() => _error = 'Select a payment channel, upload the receipt and enter the payment reference.');
      return;
    }
    setState(() { _submitting = true; _error = null; _message = null; });
    try {
      final result = await _db.rpc('submit_manual_topup_request', params: {
        'p_payment_channel_id': _channelId,
        'p_amount_usd': _amount,
        'p_payment_reference': _reference.text.trim(),
        'p_receipt_path': _receiptPath,
      });
      if (!mounted) return;
      final coins = result is Map ? result['coins'] : _amount * 4500;
      setState(() { _message = 'Request submitted. $coins coins are pending review, not credited yet.'; _receiptPath = null; _reference.clear(); });
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = 'Top-up request failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() { _reference.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? channel;
    for (final item in _channels) {
      if (item['id'].toString() == _channelId) { channel = item; break; }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF17232E), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6B46A).withOpacity(.45))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('MANUAL TOP-UP PAYMENT', style: TextStyle(color: Color(0xFFD6B46A), fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('Choose an official payment channel, pay outside the app, then submit the receipt. Coins are credited only after an authorized review.',
          style: TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 12),
        if (_loading) const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (_channels.isEmpty)
          Text(_error == null ? 'No official payment channel has been configured by the Owner yet. Top-up submission is unavailable until an official channel is added.' : 'Payment channels could not load: $_error',
            style: const TextStyle(color: Colors.white70, fontSize: 12))
        else ...[
          DropdownButtonFormField<String>(
            value: _channelId,
            decoration: const InputDecoration(labelText: 'Official payment channel'),
            items: _channels.map((item) => DropdownMenuItem<String>(
              value: item['id'].toString(),
              child: Text(item['label'].toString() + ' • ' + item['country'].toString(), overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) => setState(() => _channelId = v),
          ),
          if (channel != null) ...[
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF211735), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((channel['account_name'] ?? '').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                SelectableText((channel['account_number'] ?? '').toString(),
                  style: const TextStyle(color: Color(0xFFD6B46A), fontSize: 18, fontWeight: FontWeight.bold)),
                Text(channel['payment_method'].toString() + ' • ' + channel['country'].toString(),
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
                if ((channel['whatsapp_number'] ?? '').toString().isNotEmpty)
                  Text('WhatsApp: ' + channel['whatsapp_number'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                if ((channel['agency_name'] ?? '').toString().isNotEmpty) ...[
                  const Divider(color: Color(0xFF354653)),
                  Text('OFFICIAL AGENCY: ' + channel['agency_name'].toString(),
                    style: const TextStyle(color: Color(0xFFD6B46A), fontWeight: FontWeight.bold)),
                  Text('Agency ID: ' + (channel['agency_zoonl_id'] ?? 'Pending').toString() + ' • Code: ' + (channel['agency_code'] ?? 'Pending').toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
                if ((channel['instructions'] ?? '').toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(channel['instructions'].toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _amount,
            decoration: const InputDecoration(labelText: 'Top-up amount'),
            items: List<int>.generate(10, (i) => (i + 1) * 10).map((v) =>
              DropdownMenuItem<int>(value: v, child: Text(r'$' + v.toString() + ' USD • ' + (v * 4500).toString() + ' coins'))).toList(),
            onChanged: (v) => setState(() => _amount = v ?? 10),
          ),
          const SizedBox(height: 10),
          TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Payment reference / transaction ID')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickReceipt,
            icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_library_outlined),
            label: Text(_receiptPath == null ? 'UPLOAD PAYMENT RECEIPT FROM GALLERY' : 'RECEIPT UPLOADED ✓'),
          ),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _submitting || _uploading ? null : _submit,
            icon: const Icon(Icons.receipt_long),
            label: Text(_submitting ? 'SUBMITTING...' : 'SUBMIT FOR VERIFICATION'),
          )),
        ],
        if (_error != null && _channels.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11))),
        if (_message != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: const TextStyle(color: Colors.greenAccent, fontSize: 11))),
        const Divider(color: Color(0xFF354653), height: 24),
        const Text('MY TOP-UP REQUESTS', style: TextStyle(color: Color(0xFFD6B46A), fontWeight: FontWeight.bold)),
        if (_requests.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('No manual top-up requests yet.', style: TextStyle(color: Colors.white60, fontSize: 11)))
        else
          ..._requests.map((r) {
            final status = r['request_status'].toString();
            final color = status == 'approved' ? Colors.greenAccent : status == 'rejected' ? Colors.redAccent : Colors.amber;
            return ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: Icon(status == 'approved' ? Icons.check_circle : status == 'rejected' ? Icons.cancel_outlined : Icons.hourglass_top, color: color),
              title: Text(r'$' + r['amount_usd'].toString() + ' • ' + r['coins'].toString() + ' coins',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(status + ' • ' + r['payment_reference'].toString(), style: const TextStyle(color: Colors.white60, fontSize: 10)),
            );
          }),
        TextButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), label: const Text('REFRESH TOP-UP HISTORY')),
      ]),
    );
  }
}
