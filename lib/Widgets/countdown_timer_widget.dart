import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_elec/Screens/booked_orders_screen.dart'; // Để dùng AppColors

class CountdownTimerWidget extends StatefulWidget {
  final DateTime createdAt;
  final bool isDangerous;

  const CountdownTimerWidget({
    super.key,
    required this.createdAt,
    required this.isDangerous,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateRemainingTime();
      }
    });
  }

  void _calculateRemainingTime() {
    final timeoutMinutes = widget.isDangerous ? 15 : 10;
    final endTime = widget.createdAt.add(Duration(minutes: timeoutMinutes));
    final now = DateTime.now();
    
    if (now.isAfter(endTime) || now.isAtSameMomentAs(endTime)) {
      if (!_isFinished) {
        setState(() {
          _remainingTime = Duration.zero;
          _isFinished = true;
        });
        _timer?.cancel();
      }
    } else {
      setState(() {
        _remainingTime = endTime.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.kMutedGrey,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            "Đang xử lý hủy đơn...",
            style: TextStyle(
              color: AppColors.kMutedGrey,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          )
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time_filled_rounded, color: AppColors.kPrimaryOrange, size: 16),
        const SizedBox(width: 6),
        Text(
          "Đang tìm thợ... ${_formatDuration(_remainingTime)}",
          style: const TextStyle(
            color: AppColors.kPrimaryOrange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        )
      ],
    );
  }
}
