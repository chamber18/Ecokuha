import 'package:flutter/material.dart';

class MessageSettingsScreen extends StatefulWidget {
  const MessageSettingsScreen({super.key});

  @override
  State<MessageSettingsScreen> createState() => _MessageSettingsScreenState();
}

class _MessageSettingsScreenState extends State<MessageSettingsScreen> {
  bool _readReceipts = true;
  bool _notifyNewMessages = true;
  bool _showPreviews = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Read Receipts'),
            subtitle: const Text('Allow others to see when you read messages'),
            value: _readReceipts,
            onChanged: (v) => setState(() => _readReceipts = v),
          ),
          SwitchListTile(
            title: const Text('New Message Notifications'),
            subtitle: const Text('Receive notifications for new messages'),
            value: _notifyNewMessages,
            onChanged: (v) => setState(() => _notifyNewMessages = v),
          ),
          SwitchListTile(
            title: const Text('Show Message Previews'),
            subtitle: const Text('Display message previews in notifications'),
            value: _showPreviews,
            onChanged: (v) => setState(() => _showPreviews = v),
          ),
        ],
      ),
    );
  }
}
