import 'package:flutter/widgets.dart';

import 'agents_repository.dart';
import 'api_client.dart';
import 'appointments_repository.dart';
import 'auth_repository.dart';
import 'chat_repository.dart';
import 'commerce_repository.dart';
import 'compose_repository.dart';
import 'contacts_repository.dart';
import 'leads_repository.dart';
import 'notifications_repository.dart';
import 'payments_repository.dart';
import 'reports_repository.dart';
import 'session.dart';
import 'ticketing_repository.dart';
import 'whatsapp_flows_repository.dart';

/// Bundles the session + all repositories and exposes them to the widget tree.
class AppServices {
  final Session session;
  late final ApiClient client;
  late final AuthRepository auth;
  late final LeadsRepository leads;
  late final ChatRepository chat;
  late final ComposeRepository compose;
  late final CommerceRepository commerce;
  late final TicketingRepository ticketing;
  late final AppointmentsRepository appointments;
  late final AgentsRepository agents;
  late final ContactsRepository contacts;
  late final PaymentsRepository payments;
  late final NotificationsRepository notifications;
  late final ReportsRepository reports;
  late final WhatsAppFlowsRepository whatsappFlows;

  AppServices(this.session) {
    client = ApiClient(session);
    auth = AuthRepository(client, session);
    leads = LeadsRepository(client, session);
    chat = ChatRepository(client, session);
    compose = ComposeRepository(client, session);
    commerce = CommerceRepository(client, session);
    ticketing = TicketingRepository(client, session);
    appointments = AppointmentsRepository(client, session);
    agents = AgentsRepository(client, session);
    contacts = ContactsRepository(client, session);
    payments = PaymentsRepository(client, session);
    notifications = NotificationsRepository(client, session);
    reports = ReportsRepository(client, session);
    whatsappFlows = WhatsAppFlowsRepository(client, session);
  }
}

class AppScope extends InheritedNotifier<Session> {
  final AppServices services;

  AppScope({super.key, required this.services, required super.child}) : super(notifier: services.session);

  /// Repository/services accessor. Uses a NON-subscribing lookup so it is safe
  /// to call from initState() — the services are immutable for the app's life,
  /// so there is nothing to rebuild on. (dependOnInheritedWidgetOfExactType is
  /// illegal before the first build and would throw inside initState.)
  static AppServices of(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    assert(element != null, 'AppScope not found in context');
    return (element!.widget as AppScope).services;
  }

  /// Reactive session accessor — subscribes so the caller rebuilds when the
  /// session (token / profile) changes. Use this in build(), not initState().
  static Session sessionOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.services.session;
  }
}
