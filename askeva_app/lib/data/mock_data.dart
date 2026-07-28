import 'package:flutter/material.dart';

import 'models.dart';

/// Static sample content matching the design's demo data. No backend wiring.
class MockData {
  MockData._();

  static const String userName = 'Eshan';
  static const String userEmail = 'eshan@tunepath.com';

  static const List<Lead> leads = [
    Lead(
      name: 'Rohan Mehta',
      meta: 'Acme Corp · +91 98220 11234',
      phone: '+91 98220 11234',
      status: LeadStatus.hot,
      avatarColor: Color(0xFFF2542D),
      source: 'Business',
    ),
    Lead(
      name: 'Priya Sharma',
      meta: 'Website enquiry · 2h ago',
      phone: '+91 90011 22890',
      status: LeadStatus.newLead,
      avatarColor: Color(0xFF3B82F6),
      source: 'Website',
    ),
    Lead(
      name: 'Arjun Nair',
      meta: 'Tunepath · +91 99887 65540',
      phone: '+91 99887 65540',
      status: LeadStatus.warm,
      avatarColor: Color(0xFFE0A106),
      source: 'Referral',
    ),
    Lead(
      name: 'Sneha Iyer',
      meta: 'Instagram DM · 1d ago',
      phone: '+91 97000 33221',
      status: LeadStatus.cold,
      avatarColor: Color(0xFF3BA4DD),
      source: 'Social',
    ),
    Lead(
      name: 'Vikram Rao',
      meta: 'Closed · ₹84,000 deal',
      phone: '+91 90909 80808',
      status: LeadStatus.converted,
      avatarColor: Color(0xFF2BA84A),
      source: 'Business',
    ),
    Lead(
      name: 'Meera Joshi',
      meta: 'Acme Corp · +91 98765 43210',
      phone: '+91 98765 43210',
      status: LeadStatus.warm,
      avatarColor: Color(0xFF7C5CFF),
      source: 'Website',
    ),
  ];

  static const List<Company> companies = [
    Company(
      name: 'Acme Corp',
      email: 'hello@acme.co',
      leadCount: 42,
      color: Color(0xFF7C5CFF),
      shortName: 'AC',
    ),
    Company(
      name: 'Tunepath',
      email: 'team@tunepath.com',
      leadCount: 27,
      color: Color(0xFF2BA84A),
      shortName: 'TP',
    ),
  ];

  static const List<Agent> agents = [
    Agent(
      name: 'Eshan',
      email: 'eshan@tunepath.com',
      role: 'Super Admin',
      dept: 'Founder',
      color: Color(0xFF2BA84A),
    ),
    Agent(
      name: 'Kavya Reddy',
      email: 'kavya@tunepath.com',
      role: 'Admin',
      dept: 'Sales',
      color: Color(0xFF22B0E8),
    ),
    Agent(
      name: 'Dev Patel',
      email: 'dev@tunepath.com',
      role: 'Agent',
      dept: 'Support',
      color: Color(0xFFFF9416),
    ),
    Agent(
      name: 'Ananya Bose',
      email: 'ananya@tunepath.com',
      role: 'Agent',
      dept: 'Sales',
      color: Color(0xFFE5499A),
    ),
  ];

  static const List<ChatThread> chats = [
    ChatThread(
      name: 'Rohan Mehta',
      preview: 'Yes, can we schedule a demo this week?',
      time: '09:42',
      unread: 2,
      color: Color(0xFFF2542D),
      online: true,
    ),
    ChatThread(
      name: 'Priya Sharma',
      preview: 'Thanks for the quick reply 🙏',
      time: '08:15',
      color: Color(0xFF3B82F6),
    ),
    ChatThread(
      name: 'Acme Corp',
      preview: 'Eva: Your invoice has been shared.',
      time: 'Yesterday',
      unread: 1,
      color: Color(0xFF7C5CFF),
    ),
    ChatThread(
      name: 'Arjun Nair',
      preview: 'Voice message · 0:24',
      time: 'Yesterday',
      color: Color(0xFFE0A106),
      online: true,
    ),
    ChatThread(
      name: 'Sneha Iyer',
      preview: 'Okay, I will check and confirm.',
      time: 'Mon',
      color: Color(0xFF3BA4DD),
    ),
  ];

  static const List<Ticket> tickets = [
    Ticket(
      id: 'TK-2041',
      subject: 'Payment not reflecting after UPI',
      customer: 'Rohan Mehta',
      status: 'open',
      priority: 'high',
      time: '12m ago',
    ),
    Ticket(
      id: 'TK-2040',
      subject: 'Need GST invoice for March',
      customer: 'Acme Corp',
      status: 'open',
      priority: 'med',
      time: '1h ago',
    ),
    Ticket(
      id: 'TK-2038',
      subject: 'Reschedule onboarding call',
      customer: 'Priya Sharma',
      status: 'pending',
      priority: 'low',
      time: '3h ago',
    ),
    Ticket(
      id: 'TK-2032',
      subject: 'Refund processed successfully',
      customer: 'Vikram Rao',
      status: 'resolved',
      priority: 'med',
      time: 'Yesterday',
    ),
  ];

  static const List<Appointment> appointments = [
    Appointment(
      title: 'Product demo',
      person: 'Rohan Mehta',
      time: 'Today · 11:30 AM',
      type: 'Video call',
      color: Color(0xFF3DC838),
      group: 'today',
    ),
    Appointment(
      title: 'Pricing discussion',
      person: 'Acme Corp',
      time: 'Today · 04:00 PM',
      type: 'Phone call',
      color: Color(0xFF7C5CFF),
      group: 'today',
    ),
    Appointment(
      title: 'Onboarding session',
      person: 'Priya Sharma',
      time: 'Tomorrow · 10:00 AM',
      type: 'In-person',
      color: Color(0xFF22B0E8),
      group: 'upcoming',
    ),
    Appointment(
      title: 'Contract signing',
      person: 'Vikram Rao',
      time: 'Jun 18 · 02:30 PM',
      type: 'Video call',
      color: Color(0xFFE0A106),
      group: 'upcoming',
    ),
  ];
}
