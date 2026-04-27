import 'package:flutter/material.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPage();
}

class _LobbyPage extends State<LobbyPage> {
  DropdownButton(
    value: selectedOrg,
    items: [
      ...userOrgs.map
    ]
  );
}