-- name: GetUserByEmail :one
SELECT * FROM users
WHERE email = ? LIMIT 1;

-- name: GetUserByNickname :one
SELECT * FROM users
WHERE nickname = ? LIMIT 1;

-- name: GetUserByID :one
SELECT * FROM users
WHERE player_id = ? LIMIT 1;

-- name: CreateUser :one
INSERT INTO users (nickname, email, password_hash)
VALUES (?, ?, ?)
RETURNING *;

-- name: UpdateUserSkin :one
UPDATE users
SET selected_character = ?
WHERE player_id = ?
RETURNING *;

-- name: UpdateUserNickname :one
UPDATE users
SET nickname = ?
WHERE player_id = ?
RETURNING *;

-- name: UpdateUserPassword :one
UPDATE users
SET password_hash = ?
WHERE player_id = ?
RETURNING *;

-- name: CreateReport :one
INSERT INTO reports (
    report_type,
    reporter_user_id,
    reported_user_id,
    game_id,
    screen,
    category,
    description
)
VALUES (?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: ListReports :many
SELECT * FROM reports
ORDER BY resolved ASC, report_id DESC;

-- name: MarkReportResolved :one
UPDATE reports
SET resolved = 1,
    resolved_at = CURRENT_TIMESTAMP
WHERE report_id = ?
RETURNING *;