CREATE TABLE IF NOT EXISTS users (
    player_id INTEGER PRIMARY KEY AUTOINCREMENT,
    nickname TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    kills INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    flag_captures INTEGER DEFAULT 0,
    is_banned BOOLEAN DEFAULT 0,
    is_admin BOOLEAN DEFAULT 0,
    selected_character INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS reports (
    report_id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_type TEXT NOT NULL DEFAULT 'bug' CHECK (report_type IN ('bug', 'player')),
    reporter_user_id INTEGER NULL,
    reported_user_id INTEGER NULL,
    game_id INTEGER NULL,
    screen TEXT NOT NULL DEFAULT 'unknown',
    category TEXT NOT NULL DEFAULT 'Report Bug',
    description TEXT NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TEXT NULL,

    FOREIGN KEY (reporter_user_id) REFERENCES users(player_id),
    FOREIGN KEY (reported_user_id) REFERENCES users(player_id)
);