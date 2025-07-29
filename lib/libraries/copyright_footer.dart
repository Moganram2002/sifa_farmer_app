import 'package:flutter/material.dart';
import '../services/app_config_service.dart'; 

class CopyrightFooter extends StatelessWidget {
  const CopyrightFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 93, 213, 97),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      alignment: Alignment.center,
      child: ValueListenableBuilder<String>(
        valueListenable: AppConfigService.copyrightNotifier,
        builder: (context, copyrightText, child) {
        
          return Text(
            copyrightText,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
    );
  }
}
