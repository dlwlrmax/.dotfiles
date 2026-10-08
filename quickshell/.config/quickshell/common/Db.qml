pragma Singleton
// Db — single SQLite store for all persistent Quickshell state.
// Backed by QtQuick.LocalStorage (Qt's bundled SQLite). One database,
// five tables: notifications, recent_apps, apps, cache, meta.
//
// Testing: never point a test run at the live DB. Isolate every test with
//   env XDG_DATA_HOME=/tmp/opencode/qs-test/data \
//       XDG_STATE_HOME=/tmp/opencode/qs-test/state \
//       XDG_CACHE_HOME=/tmp/opencode/qs-test/cache
// (mkdir -p those dirs first). The live DB lives under
// $XDG_DATA_HOME/quickshell/QML/OfflineStorage/Databases/.
import QtQuick
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Io

QtObject {
    id: dbRoot

    // LOCALSTORAGE_IDENTIFIER is fixed; Qt derives the file name from its MD5
    // (295c15b949ab0184dfc2580b74713178.sqlite under OfflineStorage/Databases).
    readonly property string _identifier: "quickshell_state"
    readonly property int _notifCap: 100
    readonly property int _recentCap: 30
    readonly property int _cacheTtlMs: 8000

    property var _db: null
    property bool _ready: false

    // Blocking file reader for the one-time JSON migration. A fresh FileView is
    // created per read: reusing one and swapping `path` returns stale text.
    property Component _readerComp: Component {
        FileView { blockLoading: true }
    }

    // LocalStorage runs every statement inside a transaction, so journal_mode
    // cannot be switched through it. Set WAL once from a separate sqlite3
    // connection; the mode is persisted in the database file.
    property Process _walProc: Process {
        command: ["bash", "-c",
            "d=\"${XDG_DATA_HOME:-$HOME/.local/share}/quickshell/QML/OfflineStorage/Databases\"; " +
            "h=$(printf %s quickshell_state | md5sum | cut -d' ' -f1); " +
            "command -v sqlite3 >/dev/null 2>&1 && sqlite3 \"$d/$h.sqlite\" 'PRAGMA journal_mode=WAL;' " +
            "|| true"]
        onExited: console.log("Db: WAL journal_mode ensured")
    }

    Component.onCompleted: {
        open()
        migrateFromJson()
    }

    // ── lifecycle ───────────────────────────────────────────

    function open() {
        if (_ready && _db) return _db
        _db = LocalStorage.openDatabaseSync(_identifier, "1.0", "Quickshell persistent state", 0)
        _db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS notifications ("
                + "id INTEGER PRIMARY KEY AUTOINCREMENT, appName TEXT, summary TEXT, body TEXT, "
                + "urgency INTEGER, appIcon TEXT, desktopEntry TEXT, expireTimeout INTEGER, "
                + "actions TEXT DEFAULT '[]', timestamp INTEGER)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS recent_apps ("
                + "id TEXT PRIMARY KEY, time INTEGER)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS apps ("
                + "id TEXT PRIMARY KEY, name TEXT, generic_name TEXT, icon TEXT, comment TEXT, "
                + "exec_ TEXT, categories TEXT, keywords TEXT, no_display INTEGER, terminal INTEGER)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS cache ("
                + "key TEXT PRIMARY KEY, json TEXT, updated_at INTEGER)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS meta ("
                + "key TEXT PRIMARY KEY, value TEXT)")
        })
        _migrateReadColumn()
        _ready = true
        _ensureWal()
        return _db
    }

    // Idempotent: add the persistent read-state column once. On the first
    // boot that introduces it, any pre-existing rows are treated as already
    // seen (read=1) so we don't flood the Unread group with old history.
    // Called only from open() after _db is set, so it must not call open().
    function _migrateReadColumn() {
        var added = false
        try {
            _db.transaction(function(tx) {
                tx.executeSql("ALTER TABLE notifications ADD COLUMN read INTEGER DEFAULT 0")
            })
            added = true
        } catch (e) {
            // Column already exists — the ALTER throws; nothing to do.
        }
        // Only on the boot that actually added the column: default is 0 (not
        // NULL), so a WHERE read IS NULL would match nothing. Mark every
        // existing row read=1 here, once, so legacy history starts as Read.
        if (added) {
            _db.transaction(function(tx) {
                tx.executeSql("UPDATE notifications SET read=1")
            })
        }
    }

    function _ensureWal() {
        var mode = "delete"
        try {
            _db.readTransaction(function(tx) {
                mode = tx.executeSql("SELECT * FROM pragma_journal_mode").rows.item(0).journal_mode
            })
        } catch (e) { /* fall through: try to set it */ }
        if (mode !== "wal" && !_walProc.running) _walProc.running = true
    }

    function _readFile(path) {
        var fv = _readerComp.createObject(dbRoot, { "path": path })
        if (!fv) return ""
        var text = fv.text()
        fv.destroy()
        return text
    }

    function _now() { return Math.floor(Date.now() / 1000) }

    function _getMeta(key) {
        open()
        var v = null
        _db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT value FROM meta WHERE key=?", [key])
            if (rs.rows.length > 0) v = rs.rows.item(0).value
        })
        return v
    }

    function _setMeta(key, value) {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO meta(key,value) VALUES(?,?)", [key, "" + value])
        })
    }

    // ── notifications ───────────────────────────────────────

    function insertNotification(entry) {
        var e = entry || {}
        var actions = JSON.stringify(e.actions || [])
        open()
        var id = -1
        _db.transaction(function(tx) {
            var rs = tx.executeSql("INSERT INTO notifications "
                + "(appName,summary,body,urgency,appIcon,desktopEntry,expireTimeout,actions,timestamp,read) "
                + "VALUES (?,?,?,?,?,?,?,?,?,?)",
                [e.appName || "", e.summary || "", e.body || "", e.urgency || 1,
                 e.appIcon || "", e.desktopEntry || "", e.expireTimeout || 0,
                 actions, e.timestamp || 0, 0])
            id = rs.insertId
            // 7-day TTL: drop stale rows so history cannot grow unbounded on
            // machines that rarely clear. timestamp is epoch seconds.
            tx.executeSql("DELETE FROM notifications WHERE timestamp < "
                + "CAST(strftime('%s','now','-7 days') AS INTEGER)")
            tx.executeSql("DELETE FROM notifications WHERE id NOT IN "
                + "(SELECT id FROM notifications ORDER BY id DESC LIMIT " + _notifCap + ")")
        })
        return id
    }

    function loadNotifications() {
        open()
        var out = []
        _db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT * FROM notifications ORDER BY id ASC")
            for (var i = 0; i < rs.rows.length; i++) {
                var r = rs.rows.item(i)
                var acts = []
                try { acts = JSON.parse(r.actions || "[]") } catch (e) { acts = [] }
                out.push({
                    appName: r.appName || "",
                    summary: r.summary || "",
                    body: r.body || "",
                    urgency: r.urgency || 1,
                    appIcon: r.appIcon || "",
                    desktopEntry: r.desktopEntry || "",
                    expireTimeout: r.expireTimeout || 0,
                    actions: acts,
                    timestamp: r.timestamp || 0
                })
            }
        })
        return out
    }

    // History = every persisted row, newest first. Plain-JS objects with the
    // DB row `id` and a `read` flag so the panel can reconcile against live
    // notifications and persist read-state back.
    function loadHistory(limit) {
        open()
        var out = []
        _db.readTransaction(function(tx) {
            var base = "SELECT id, appName, summary, body, urgency, appIcon, "
                + "desktopEntry, expireTimeout, actions, timestamp, read "
                + "FROM notifications"
            var rs
            if (limit && limit > 0) {
                rs = tx.executeSql(base + " ORDER BY id DESC LIMIT ?", [limit])
            } else {
                rs = tx.executeSql(base + " ORDER BY id DESC")
            }
            for (var i = 0; i < rs.rows.length; i++) {
                var r = rs.rows.item(i)
                var acts = []
                try { acts = JSON.parse(r.actions || "[]") } catch (e) { acts = [] }
                out.push({
                    id: r.id,
                    appName: r.appName || "",
                    summary: r.summary || "",
                    body: r.body || "",
                    urgency: r.urgency || 1,
                    appIcon: r.appIcon || "",
                    desktopEntry: r.desktopEntry || "",
                    expireTimeout: r.expireTimeout || 0,
                    actions: acts,
                    timestamp: r.timestamp || 0,
                    read: r.read ? 1 : 0
                })
            }
        })
        return out
    }

    function markRead(id) {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("UPDATE notifications SET read=1 WHERE id=?", [id])
        })
    }

    function markAllRead() {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("UPDATE notifications SET read=1")
        })
    }

    // Single-row delete (history card dismiss).
    function deleteHistoryRow(id) {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("DELETE FROM notifications WHERE id=?", [id])
        })
    }

    // Wipe only the already-read rows (Read group "Clear read").
    function deleteRead() {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("DELETE FROM notifications WHERE read=1")
        })
    }

    // Wipe the whole table (full clear).
    function deleteHistory() {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("DELETE FROM notifications")
        })
    }

    // ── recent apps ─────────────────────────────────────────

    function markRecent(entryId, time) {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO recent_apps(id,time) VALUES(?,?)",
                [entryId, time || _now()])
            tx.executeSql("DELETE FROM recent_apps WHERE id NOT IN "
                + "(SELECT id FROM recent_apps ORDER BY time DESC LIMIT " + _recentCap + ")")
        })
    }

    function loadRecents() {
        open()
        var out = []
        _db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT id,time FROM recent_apps ORDER BY time DESC")
            for (var i = 0; i < rs.rows.length; i++) {
                var r = rs.rows.item(i)
                out.push({ id: r.id, time: r.time })
            }
        })
        return out
    }

    // ── desktop apps cache ──────────────────────────────────

    function replaceApps(entries) {
        var list = entries || []
        open()
        _db.transaction(function(tx) {
            tx.executeSql("DELETE FROM apps")
            for (var i = 0; i < list.length; i++) {
                var e = list[i]
                tx.executeSql("INSERT OR REPLACE INTO apps "
                    + "(id,name,generic_name,icon,comment,exec_,categories,keywords,no_display,terminal) "
                    + "VALUES (?,?,?,?,?,?,?,?,?,?)",
                    [e.id || "", e.name || "", e.genericName || "", e.icon || "",
                     e.comment || "", e.exec || "", e.categories || "", e.keywords || "",
                     e.noDisplay ? 1 : 0, e.terminal ? 1 : 0])
            }
        })
    }

    function loadApps() {
        open()
        var out = []
        _db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT id,name,generic_name,icon,comment,exec_,"
                + "categories,keywords,no_display,terminal FROM apps")
            for (var i = 0; i < rs.rows.length; i++) {
                var r = rs.rows.item(i)
                out.push({
                    id: r.id,
                    name: r.name || "",
                    genericName: r.generic_name || "",
                    icon: r.icon || "",
                    comment: r.comment || "",
                    exec: r.exec_ || "",
                    categories: r.categories || "",
                    keywords: r.keywords || "",
                    noDisplay: !!r.no_display,
                    terminal: !!r.terminal
                })
            }
        })
        return out
    }

    function getAppsFingerprint() {
        var v = _getMeta("apps_fingerprint")
        return v === null ? "" : v
    }

    function setAppsFingerprint(hash) {
        _setMeta("apps_fingerprint", hash || "")
    }

    // ── cache (KDE Connect snapshot, etc.) ──────────────────

    function cacheGet(key) {
        open()
        var row = null
        _db.readTransaction(function(tx) {
            var rs = tx.executeSql("SELECT json,updated_at FROM cache WHERE key=?", [key])
            if (rs.rows.length > 0) {
                row = { json: rs.rows.item(0).json, updated_at: rs.rows.item(0).updated_at }
            }
        })
        return row
    }

    function cachePut(key, json) {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO cache(key,json,updated_at) VALUES(?,?,?)",
                [key, json || "", _now()])
        })
    }

    function cacheInvalidate(key) {
        open()
        _db.transaction(function(tx) {
            tx.executeSql("DELETE FROM cache WHERE key=?", [key])
        })
    }

    // TTL check helper for callers: true when the row is younger than 8s.
    function cacheFresh(row) {
        if (!row) return false
        return (Date.now() - (row.updated_at || 0) * 1000) < _cacheTtlMs
    }

    // ── legacy JSON migration (one-time) ────────────────────

    function migrateFromJson() {
        open()
        if (_getMeta("imported_notif") !== "1") _importNotifications()
        if (_getMeta("imported_recent") !== "1") _importRecents()
        if (_getMeta("imported_apps") !== "1") _importApps()
        if (_getMeta("imported_apps_hash") !== "1") _importAppsHash()
    }

    function _contentless(n) {
        return !n.appName && !n.summary && !n.body && !n.appIcon
            && !n.desktopEntry && !n.image
            && (!n.actions || n.actions.length === 0)
    }

    function _cacheDir() {
        var xdg = Quickshell.env("XDG_CACHE_HOME")
        if (xdg && xdg.length > 0) return xdg
        return (Quickshell.env("HOME") || "") + "/.cache"
    }

    function _importNotifications() {
        var home = Quickshell.env("HOME") || ""
        var state = Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
        var text = _readFile(state + "/quickshell/notifications.json")
        if (text && text.length > 0) {
            try {
                var arr = JSON.parse(text)
                if (Array.isArray(arr)) {
                    var rows = arr.filter(function(d) { return !dbRoot._contentless(d) })
                    open()
                    _db.transaction(function(tx) {
                        for (var i = 0; i < rows.length; i++) {
                            var d = rows[i]
                            tx.executeSql("INSERT INTO notifications "
                                + "(appName,summary,body,urgency,appIcon,desktopEntry,expireTimeout,actions,timestamp,read) "
                                + "VALUES (?,?,?,?,?,?,?,?,?,?)",
                                [d.appName || "", d.summary || "", d.body || "", d.urgency || 1,
                                 d.appIcon || "", d.desktopEntry || "", d.expireTimeout || 0,
                                 JSON.stringify(d.actions || []), d.timestamp || 0, 1])
                        }
                        tx.executeSql("DELETE FROM notifications WHERE id NOT IN "
                            + "(SELECT id FROM notifications ORDER BY id DESC LIMIT " + _notifCap + ")")
                    })
                }
            } catch (e) {
                console.log("Db: notifications migration failed:", e)
            }
        }
        _setMeta("imported_notif", "1")
    }

    function _importRecents() {
        var home = Quickshell.env("HOME") || ""
        var candidates = [home + "/.cache/quickshell/recent-apps.json"]
        var xdg = Quickshell.env("XDG_CACHE_HOME")
        if (xdg && xdg.length > 0) candidates.push(xdg + "/quickshell/recent-apps.json")

        var text = ""
        for (var c = 0; c < candidates.length; c++) {
            var t = _readFile(candidates[c])
            if (t && t.length > 0) { text = t; break }
        }
        if (text.length > 0) {
            try {
                var arr = JSON.parse(text)
                if (Array.isArray(arr)) {
                    open()
                    _db.transaction(function(tx) {
                        for (var i = 0; i < arr.length; i++) {
                            var it = arr[i]
                            if (!it || it.id === undefined) continue
                            tx.executeSql("INSERT OR REPLACE INTO recent_apps(id,time) VALUES(?,?)",
                                [it.id, it.time || 0])
                        }
                        tx.executeSql("DELETE FROM recent_apps WHERE id NOT IN "
                            + "(SELECT id FROM recent_apps ORDER BY time DESC LIMIT " + _recentCap + ")")
                    })
                }
            } catch (e) {
                console.log("Db: recent apps migration failed:", e)
            }
        }
        _setMeta("imported_recent", "1")
    }

    function _importApps() {
        var text = _readFile(_cacheDir() + "/quickshell/desktop-cache.json")
        if (text && text.length > 0) {
            try {
                var arr = JSON.parse(text)
                if (Array.isArray(arr)) replaceApps(arr)
            } catch (e) {
                console.log("Db: apps migration failed:", e)
            }
        }
        _setMeta("imported_apps", "1")
    }

    function _importAppsHash() {
        var text = _readFile(_cacheDir() + "/quickshell/desktop-cache.sha256")
        if (text && text.trim().length > 0) setAppsFingerprint(text.trim())
        _setMeta("imported_apps_hash", "1")
    }
}
