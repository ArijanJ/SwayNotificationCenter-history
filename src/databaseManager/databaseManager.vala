namespace SwayNotificationCenter {
    using SwayNotificationCenter;

    public class DatabaseManager : Object {
        private Sqlite.Database db;
        private static DatabaseManager? instance = null;

        public static DatabaseManager get_instance() {
            if (instance == null) {
                instance = new DatabaseManager();
            }
            return instance;
        }

        private DatabaseManager() {
            string db_path = Path.build_filename(Environment.get_user_data_dir(), "swaync", "notifications.db");
            DirUtils.create_with_parents(Path.get_dirname(db_path), 0755);

            int rc = Sqlite.Database.open(db_path, out db);
            if (rc != Sqlite.OK) {
                error("Can't open database: %d: %s\n", rc, db.errmsg());
            }

            create_tables();
        }

        private void create_tables() {
            string query = """
                CREATE TABLE IF NOT EXISTS notifications (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    app_name TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    body TEXT,
                    icon TEXT,
                    urgency INTEGER NOT NULL,
                    category TEXT,
                    desktop_entry TEXT,
                    timestamp INTEGER NOT NULL,
                    is_read BOOLEAN DEFAULT 0
                );
            """;

            string errmsg;
            int rc = db.exec(query, null, out errmsg);
            if (rc != Sqlite.OK) {
                error("Error creating table: %s\n", errmsg);
            }
        }

        public void log_notification(NotifyParams param) {
            string query = """
                INSERT INTO notifications (
                    app_name, summary, body, icon, urgency,
                    category, desktop_entry, timestamp
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """;

            Sqlite.Statement stmt;
            int rc = db.prepare_v2(query, -1, out stmt);
            if (rc != Sqlite.OK) {
                error("Error preparing statement: %d: %s\n", rc, db.errmsg());
            }

            stmt.bind_text(1, param.app_name);
            stmt.bind_text(2, param.summary);
            stmt.bind_text(3, param.body);
            stmt.bind_text(4, param.app_icon);
            stmt.bind_int(5, param.urgency);
            stmt.bind_text(6, param.category);
            stmt.bind_text(7, param.desktop_entry ?? "");
            stmt.bind_int64(8, param.time);

            rc = stmt.step();
            if (rc != Sqlite.DONE) {
                error("Error inserting notification: %d: %s\n", rc, db.errmsg());
            }

            stmt.reset();
        }

        public List<NotifyParams> get_notifications(int limit = 100, int offset = 0) {
            var notifications = new List<NotifyParams>();
            string query = """
                SELECT * FROM notifications
                ORDER BY timestamp DESC
                LIMIT ? OFFSET ?;
            """;

            Sqlite.Statement stmt;
            int rc = db.prepare_v2(query, -1, out stmt);
            if (rc != Sqlite.OK) {
                error("Error preparing statement: %d: %s\n", rc, db.errmsg());
            }

            stmt.bind_int(1, limit);
            stmt.bind_int(2, offset);

            while (stmt.step() == Sqlite.ROW) {
                var param = new NotifyParams(
                    (uint32)stmt.column_int64(0),  // id
                    stmt.column_text(1),           // app_name
                    0,                             // replaces_id
                    stmt.column_text(4),           // app_icon
                    stmt.column_text(2),           // summary
                    stmt.column_text(3),           // body
                    new string[0],                 // actions
                    new HashTable<string, Variant>(str_hash, str_equal), // hints
                    -1                             // expire_timeout
                );
                param.time = stmt.column_int64(8); // timestamp
                param.urgency = (uint8)stmt.column_int(5); // urgency
                param.category = stmt.column_text(6); // category
                param.desktop_entry = stmt.column_text(7); // desktop_entry

                notifications.append(param);
            }

            stmt.reset();

            return notifications;
        }

        public void delete_notification(uint32 id) {
            string query = "DELETE FROM notifications WHERE id = ?;";

            Sqlite.Statement stmt;
            int rc = db.prepare_v2(query, -1, out stmt);
            if (rc != Sqlite.OK) {
                error("Error preparing statement: %d: %s\n", rc, db.errmsg());
            }

            stmt.bind_int64(1, id);

            rc = stmt.step();
            if (rc != Sqlite.DONE) {
                error("Error deleting notification: %d: %s\n", rc, db.errmsg());
            }

            stmt.reset();
        }

        public void mark_as_read(uint32 id) {
            string query = "UPDATE notifications SET is_read = 1 WHERE id = ?;";

            Sqlite.Statement stmt;
            int rc = db.prepare_v2(query, -1, out stmt);
            if (rc != Sqlite.OK) {
                error("Error preparing statement: %d: %s\n", rc, db.errmsg());
            }

            stmt.bind_int64(1, id);

            rc = stmt.step();
            if (rc != Sqlite.DONE) {
                error("Error marking notification as read: %d: %s\n", rc, db.errmsg());
            }

            stmt.reset();
        }

        public int get_unread_count() {
            string query = "SELECT COUNT(*) FROM notifications WHERE is_read = 0;";

            Sqlite.Statement stmt;
            int rc = db.prepare_v2(query, -1, out stmt);
            if (rc != Sqlite.OK) {
                error("Error preparing statement: %d: %s\n", rc, db.errmsg());
            }

            int count = 0;
            if (stmt.step() == Sqlite.ROW) {
                count = stmt.column_int(0);
            }

            stmt.reset();

            return count;
        }
    }
}