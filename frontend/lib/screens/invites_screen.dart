import 'package:flutter/material.dart';

class InvitesScreen extends StatelessWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invites')),
      body: const Center(
        child: Text('Incoming & Outgoing Requests'),
      ),
    );
  }
}
