import 'package:flutter/material.dart';

void showCustomNotification(BuildContext context, String message, {bool isError = false}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      // Auto-dismiss after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop();
      });

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isError ? const Color.fromARGB(255, 211, 47, 47) : const Color.fromARGB(255, 0, 96, 100),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
} 