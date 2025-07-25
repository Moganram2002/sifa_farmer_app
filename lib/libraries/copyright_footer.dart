import 'package:flutter/material.dart';

class CopyrightFooter extends StatelessWidget {

  final Color? color;
  const CopyrightFooter({
    this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
    
      alignment: Alignment.bottomLeft,
      
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
      child: Text(
     
        "© CShiine Tech 2025",
        style: TextStyle(
          fontSize: 12,
          
          color: color ?? Colors.grey.shade600,
        ),
      ),
    );
  }
}