import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum LeadStatus { hot, warm, newLead, converted, cold }

extension LeadStatusX on LeadStatus {
  String get label => switch (this) {
        LeadStatus.hot => 'Hot',
        LeadStatus.warm => 'Warm',
        LeadStatus.newLead => 'New',
        LeadStatus.converted => 'Customer',
        LeadStatus.cold => 'Cold',
      };

  Color get fg => switch (this) {
        LeadStatus.hot => AppColors.hotFg,
        LeadStatus.warm => AppColors.warmFg,
        LeadStatus.newLead => AppColors.newFg,
        LeadStatus.converted => AppColors.convertedFg,
        LeadStatus.cold => AppColors.coldFg,
      };

  Color get bg => switch (this) {
        LeadStatus.hot => AppColors.hotBg,
        LeadStatus.warm => AppColors.warmBg,
        LeadStatus.newLead => AppColors.newBg,
        LeadStatus.converted => AppColors.convertedBg,
        LeadStatus.cold => AppColors.coldBg,
      };
}

class Lead {
  final String name;
  final String meta; // e.g. "Acme Corp · +91 98xxxx"
  final String phone;
  final LeadStatus status;
  final Color avatarColor;
  final String source; // Business / Website / Referral / Social

  const Lead({
    required this.name,
    required this.meta,
    required this.phone,
    required this.status,
    required this.avatarColor,
    required this.source,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class Company {
  final String name;
  final String email;
  final int leadCount;
  final Color color;
  final String shortName;

  const Company({
    required this.name,
    required this.email,
    required this.leadCount,
    required this.color,
    required this.shortName,
  });
}

class Agent {
  final String name;
  final String email;
  final String role; // Super Admin / Admin / Agent
  final String dept;
  final Color color;
  final bool active;

  const Agent({
    required this.name,
    required this.email,
    required this.role,
    required this.dept,
    required this.color,
    this.active = true,
  });

  String get initial => name.characters.first.toUpperCase();
}

class ChatThread {
  final String name;
  final String preview;
  final String time;
  final int unread;
  final Color color;
  final bool online;

  const ChatThread({
    required this.name,
    required this.preview,
    required this.time,
    this.unread = 0,
    required this.color,
    this.online = false,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class Ticket {
  final String id;
  final String subject;
  final String customer;
  final String status; // open / pending / resolved
  final String priority; // high / med / low
  final String time;

  const Ticket({
    required this.id,
    required this.subject,
    required this.customer,
    required this.status,
    required this.priority,
    required this.time,
  });
}

class Appointment {
  final String title;
  final String person;
  final String time;
  final String type; // booking type
  final Color color;
  final String group; // today / upcoming / past

  const Appointment({
    required this.title,
    required this.person,
    required this.time,
    required this.type,
    required this.color,
    required this.group,
  });
}
