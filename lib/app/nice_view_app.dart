import 'package:flutter/material.dart';

import '../features/random_image/presentation/random_image_page.dart';
import 'theme.dart';

class NiceViewApp extends StatelessWidget {
  const NiceViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nice View',
      theme: buildNiceViewTheme(),
      home: const RandomImagePage(),
    );
  }
}
