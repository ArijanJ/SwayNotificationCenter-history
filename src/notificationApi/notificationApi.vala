namespace SwayNotificationCenter {
    [DBus (name = "org.freedesktop.Notifications")]
    public class NotificationApi : Object {
        private DatabaseManager db_manager;

        public NotificationApi() {
            db_manager = DatabaseManager.get_instance();
        }

        /**
         * Get a list of notifications
         * @param limit Maximum number of notifications to return
         * @param offset Offset for pagination
         * @return Array of notification IDs
         */
        public uint32[] get_notifications(int limit = 100, int offset = 0) throws DBusError, IOError {
            var notifications = db_manager.get_notifications(limit, offset);
            var ids = new uint32[notifications.length()];

            int i = 0;
            foreach (var noti in notifications) {
                ids[i++] = noti.applied_id;
            }

            return ids;
        }

        /**
         * Get notification details by ID
         * @param id Notification ID
         * @return Dictionary containing notification details
         */
        public HashTable<string, Variant> get_notification_details(uint32 id) throws DBusError, IOError {
            var notifications = db_manager.get_notifications(1, 0);
            foreach (var noti in notifications) {
                if (noti.applied_id == id) {
                    var details = new HashTable<string, Variant>(str_hash, str_equal);
                    details["app_name"] = noti.app_name;
                    details["summary"] = noti.summary;
                    details["body"] = noti.body;
                    details["icon"] = noti.app_icon;
                    details["urgency"] = noti.urgency;
                    details["category"] = noti.category;
                    details["desktop_entry"] = noti.desktop_entry ?? "";
                    details["timestamp"] = noti.time;

                    return details;
                }
            }

            throw new DBusError.FAILED("Notification not found");
        }

        /**
         * Delete a notification by ID
         * @param id Notification ID
         */
        public void delete_notification(uint32 id) throws DBusError, IOError {
            db_manager.delete_notification(id);
        }

        /**
         * Mark a notification as read
         * @param id Notification ID
         */
        public void mark_as_read(uint32 id) throws DBusError, IOError {
            db_manager.mark_as_read(id);
        }

        /**
         * Get the number of unread notifications
         * @return Number of unread notifications
         */
        public int get_unread_count() throws DBusError, IOError {
            int count = db_manager.get_unread_count();
            return count;
        }
    }
}