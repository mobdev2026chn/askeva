import 'api_client.dart';
import 'dto.dart';
import 'session.dart';

class NotificationsRepository {
  final ApiClient client;
  final Session session;
  NotificationsRepository(this.client, this.session);

  /// GET /v1/users/notifications?page={page}&limit={limit}&type={type}&isRead={isRead}
  Future<List<NotificationDto>> fetchNotifications({
    int page = 1,
    int limit = 200,
    String? type,
    bool? isRead,
  }) async {
    final Map<String, dynamic> query = {
      'page': page,
      'limit': limit,
    };
    if (type != null) query['type'] = type;
    if (isRead != null) query['isRead'] = isRead;

    final res = await client.get('/users/notifications', query: query);
    if (res is List) {
      return res.whereType<Map>().map((m) => NotificationDto.fromJson(m.cast<String, dynamic>())).toList();
    }
    if (res is Map) {
      final data = res['data'];
      if (data is List) {
        return data.whereType<Map>().map((m) => NotificationDto.fromJson(m.cast<String, dynamic>())).toList();
      }
    }
    return const [];
  }

  /// GET /v1/users/notifications/unread/count
  Future<int> fetchUnreadCount() async {
    final res = await client.get('/users/notifications/unread/count');
    if (res is Map) {
      final count = res['count'] ?? res['data']?['count'];
      if (count != null) {
        return int.tryParse(count.toString()) ?? 0;
      }
    }
    if (res is num) {
      return res.toInt();
    }
    return 0;
  }

  /// PATCH /v1/users/notifications/{id}/read
  Future<void> markAsRead(String id) async {
    await client.patch('/users/notifications/$id/read');
  }

  /// PATCH /v1/users/notifications/read-all
  Future<void> markAllAsRead() async {
    await client.patch('/users/notifications/read-all');
  }

  /// DELETE /v1/users/notifications/{id}
  Future<void> deleteNotification(String id) async {
    await client.delete('/users/notifications/$id');
  }

  /// DELETE /v1/users/notifications
  Future<void> clearAllNotifications() async {
    await client.delete('/users/notifications');
  }
}
