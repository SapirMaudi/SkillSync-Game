package states

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"server/pkg/packets"
	"strconv"
	"strings"
	"unicode/utf8"
)

const supportReportPrefix = "SUPPORT_REPORT:"
const supportReportResponsePrefix = "SUPPORT_REPORT_RESPONSE:"

const adminReportsGetPrefix = "ADMIN_REPORTS_GET:"
const adminReportsResponsePrefix = "ADMIN_REPORTS_RESPONSE:"

const adminReportResolvePrefix = "ADMIN_REPORT_RESOLVE:"
const adminReportResolveResponsePrefix = "ADMIN_REPORT_RESOLVE_RESPONSE:"

const supportReportMaxDescriptionLength = 500

type supportReportPayload struct {
	ReportType       string `json:"report_type"`
	Screen           string `json:"screen"`
	Category         string `json:"category"`
	Description      string `json:"description"`
	ReportedPlayerID uint64 `json:"reported_player_id"`
	GameID           uint64 `json:"game_id"`
}

type simpleReportResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

type adminReportsResponse struct {
	Success bool          `json:"success"`
	Message string        `json:"message"`
	Admin   bool          `json:"admin"`
	Reports []adminReport `json:"reports"`
}

type adminReport struct {
	ReportID       int64  `json:"report_id"`
	ReportType     string `json:"report_type"`
	ReporterUserID int64  `json:"reporter_user_id"`
	ReportedUserID int64  `json:"reported_user_id"`
	GameID         int64  `json:"game_id"`
	Screen         string `json:"screen"`
	Category       string `json:"category"`
	Description    string `json:"description"`
	Resolved       bool   `json:"resolved"`
	CreatedAt      string `json:"created_at"`
	ResolvedAt     string `json:"resolved_at"`
}

// handleReportChat handles all report-related chat packets.
// We are using ChatMessage temporarily so we do not need to regenerate protobuf packets yet.
//
// Supported messages:
// SUPPORT_REPORT:{json}
// ADMIN_REPORTS_GET:
// ADMIN_REPORT_RESOLVE:<report_id>
func handleReportChat(
	client server.ClientInterfacer,
	logger *log.Logger,
	senderID uint64,
	message *packets.Packet_Chat,
) bool {
	if message == nil || message.Chat == nil {
		return false
	}

	raw := message.Chat.Msg

	switch {
	case strings.HasPrefix(raw, supportReportPrefix):
		handleCreateReport(client, logger, senderID, strings.TrimPrefix(raw, supportReportPrefix))
		return true

	case strings.HasPrefix(raw, adminReportsGetPrefix):
		handleAdminListReports(client, logger, senderID)
		return true

	case strings.HasPrefix(raw, adminReportResolvePrefix):
		handleAdminResolveReport(client, logger, senderID, strings.TrimPrefix(raw, adminReportResolvePrefix))
		return true

	default:
		return false
	}
}

func handleCreateReport(
	client server.ClientInterfacer,
	logger *log.Logger,
	senderID uint64,
	jsonText string,
) {
	if senderID != client.Id() {
		logger.Println("sender ID mismatch in report request")
		sendSupportReportResponse(client, false, "Failed to send report.")
		return
	}

	var payload supportReportPayload
	if err := json.Unmarshal([]byte(jsonText), &payload); err != nil {
		logger.Printf("invalid report JSON: %v", err)
		sendSupportReportResponse(client, false, "Invalid report data.")
		return
	}

	payload.ReportType = strings.TrimSpace(payload.ReportType)
	payload.Screen = strings.TrimSpace(payload.Screen)
	payload.Category = strings.TrimSpace(payload.Category)
	payload.Description = strings.TrimSpace(payload.Description)

	if payload.ReportType == "" {
		payload.ReportType = "bug"
	}

	if payload.ReportType != "bug" && payload.ReportType != "player" {
		sendSupportReportResponse(client, false, "Invalid report type.")
		return
	}

	if payload.Screen == "" {
		payload.Screen = "unknown"
	}

	if payload.Category == "" {
		payload.Category = "Report Bug"
	}

	if utf8.RuneCountInString(payload.Description) < 5 {
		sendSupportReportResponse(client, false, "Please describe the problem first.")
		return
	}

	if utf8.RuneCountInString(payload.Description) > supportReportMaxDescriptionLength {
		sendSupportReportResponse(
			client,
			false,
			fmt.Sprintf("Report is too long. Max %d characters.", supportReportMaxDescriptionLength),
		)
		return
	}

	// Reporter is nullable because login/register reports can be sent before login.
	var reporterUserID interface{} = nil
	if client.UserDbId() != 0 {
		reporterUserID = int64(client.UserDbId())
	}

	// For bug reports, reported_user_id stays NULL.
	// For player reports, the client sends the runtime client/player id from the match result screen.
	// The server converts that runtime id into the target user's DB id before saving.
	var reportedUserID interface{} = nil

	if payload.ReportType == "player" {
		if client.UserDbId() == 0 {
			sendSupportReportResponse(client, false, "You must be logged in to report a player.")
			return
		}

		if payload.ReportedPlayerID == 0 {
			sendSupportReportResponse(client, false, "Invalid reported player.")
			return
		}

		if payload.ReportedPlayerID == client.Id() {
			sendSupportReportResponse(client, false, "You cannot report yourself.")
			return
		}

		reportedClient, ok := client.Hub().Clients.Get(payload.ReportedPlayerID)
		if !ok {
			sendSupportReportResponse(client, false, "Reported player is no longer connected.")
			return
		}

		if reportedClient.UserDbId() == 0 {
			sendSupportReportResponse(client, false, "Reported player has no user account.")
			return
		}

		reportedUserID = int64(reportedClient.UserDbId())
	} else {
		if payload.ReportedPlayerID != 0 {
			reportedUserID = int64(payload.ReportedPlayerID)
		}
	}

	var gameID interface{} = nil
	if payload.GameID != 0 {
		gameID = int64(payload.GameID)
	}

	report, err := client.DbTx().Queries.CreateReport(client.DbTx().Ctx, db.CreateReportParams{
		ReportType:     payload.ReportType,
		ReporterUserID: reporterUserID,
		ReportedUserID: reportedUserID,
		GameID:         gameID,
		Screen:         payload.Screen,
		Category:       payload.Category,
		Description:    payload.Description,
	})
	if err != nil {
		logger.Printf("failed to save report: %v", err)
		sendSupportReportResponse(client, false, "Failed to save report.")
		return
	}

	logger.Printf(
		"REPORT SAVED: id=%d type=%s reporter_user_id=%d reported_user_id=%v game_id=%v screen=%q category=%q",
		report.ReportID,
		report.ReportType,
		client.UserDbId(),
		reportedUserID,
		gameID,
		report.Screen,
		report.Category,
	)

	sendSupportReportResponse(client, true, "Report sent successfully. Thank you!")
}

func handleAdminListReports(
	client server.ClientInterfacer,
	logger *log.Logger,
	senderID uint64,
) {
	if senderID != client.Id() {
		sendAdminReportsResponse(client, false, false, "Failed to load reports.", nil)
		return
	}

	if !isClientAdmin(client, logger) {
		sendAdminReportsResponse(client, false, false, "You are not an admin.", nil)
		return
	}

	reports, err := client.DbTx().Queries.ListReports(client.DbTx().Ctx)
	if err != nil {
		logger.Printf("failed to list reports: %v", err)
		sendAdminReportsResponse(client, false, true, "Failed to load reports.", nil)
		return
	}

	responseReports := make([]adminReport, 0, len(reports))
	for _, report := range reports {
		responseReports = append(responseReports, convertReport(report))
	}

	sendAdminReportsResponse(client, true, true, "Reports loaded.", responseReports)
}

func handleAdminResolveReport(
	client server.ClientInterfacer,
	logger *log.Logger,
	senderID uint64,
	reportIDText string,
) {
	if senderID != client.Id() {
		sendAdminResolveResponse(client, false, "Failed to resolve report.")
		return
	}

	if !isClientAdmin(client, logger) {
		sendAdminResolveResponse(client, false, "You are not an admin.")
		return
	}

	reportID, err := strconv.ParseInt(strings.TrimSpace(reportIDText), 10, 64)
	if err != nil || reportID <= 0 {
		sendAdminResolveResponse(client, false, "Invalid report id.")
		return
	}

	_, err = client.DbTx().Queries.MarkReportResolved(client.DbTx().Ctx, reportID)
	if err != nil {
		logger.Printf("failed to resolve report %d: %v", reportID, err)
		sendAdminResolveResponse(client, false, "Failed to resolve report.")
		return
	}

	sendAdminResolveResponse(client, true, "Report marked as resolved.")

	// Refresh admin list after resolving.
	handleAdminListReports(client, logger, senderID)
}

func isClientAdmin(client server.ClientInterfacer, logger *log.Logger) bool {
	if client.UserDbId() == 0 {
		return false
	}

	user, err := client.DbTx().Queries.GetUserByID(client.DbTx().Ctx, int64(client.UserDbId()))
	if err != nil {
		logger.Printf("failed to check admin permission: %v", err)
		return false
	}

	return user.IsAdmin.Bool
}

func convertReport(report db.Report) adminReport {
	return adminReport{
		ReportID:       report.ReportID,
		ReportType:     report.ReportType,
		ReporterUserID: nullableToInt64(report.ReporterUserID),
		ReportedUserID: nullableToInt64(report.ReportedUserID),
		GameID:         nullableToInt64(report.GameID),
		Screen:         report.Screen,
		Category:       report.Category,
		Description:    report.Description,
		Resolved:       nullableToBool(report.Resolved),
		CreatedAt:      nullableToString(report.CreatedAt),
		ResolvedAt:     nullableToString(report.ResolvedAt),
	}
}

func nullableToInt64(value interface{}) int64 {
	if value == nil {
		return 0
	}

	switch v := value.(type) {
	case int64:
		return v

	case int:
		return int64(v)

	case int32:
		return int64(v)

	case uint64:
		return int64(v)

	case uint:
		return int64(v)

	case []byte:
		parsed, err := strconv.ParseInt(string(v), 10, 64)
		if err != nil {
			return 0
		}
		return parsed

	case string:
		parsed, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			return 0
		}
		return parsed

	case sql.NullInt64:
		if !v.Valid {
			return 0
		}
		return v.Int64

	default:
		return 0
	}
}

func nullableToString(value interface{}) string {
	if value == nil {
		return ""
	}

	switch v := value.(type) {
	case string:
		return v

	case []byte:
		return string(v)

	case sql.NullString:
		if !v.Valid {
			return ""
		}
		return v.String

	default:
		return fmt.Sprintf("%v", v)
	}
}

func nullableToBool(value interface{}) bool {
	if value == nil {
		return false
	}

	switch v := value.(type) {
	case bool:
		return v

	case int:
		return v != 0

	case int64:
		return v != 0

	case int32:
		return v != 0

	case uint64:
		return v != 0

	case []byte:
		text := strings.TrimSpace(strings.ToLower(string(v)))
		return text == "1" || text == "true"

	case string:
		text := strings.TrimSpace(strings.ToLower(v))
		return text == "1" || text == "true"

	case sql.NullBool:
		if !v.Valid {
			return false
		}
		return v.Bool

	default:
		return false
	}
}

func sendSupportReportResponse(client server.ClientInterfacer, success bool, message string) {
	payload := simpleReportResponse{
		Success: success,
		Message: message,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		client.SocketSend(packets.NewChat(
			supportReportResponsePrefix + `{"success":false,"message":"Failed to create report response."}`,
		))
		return
	}

	client.SocketSend(packets.NewChat(supportReportResponsePrefix + string(data)))
}

func sendAdminReportsResponse(
	client server.ClientInterfacer,
	success bool,
	admin bool,
	message string,
	reports []adminReport,
) {
	payload := adminReportsResponse{
		Success: success,
		Admin:   admin,
		Message: message,
		Reports: reports,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		client.SocketSend(packets.NewChat(
			adminReportsResponsePrefix + `{"success":false,"admin":false,"message":"Failed to create admin response.","reports":[]}`,
		))
		return
	}

	client.SocketSend(packets.NewChat(adminReportsResponsePrefix + string(data)))
}

func sendAdminResolveResponse(client server.ClientInterfacer, success bool, message string) {
	payload := simpleReportResponse{
		Success: success,
		Message: message,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		client.SocketSend(packets.NewChat(
			adminReportResolveResponsePrefix + `{"success":false,"message":"Failed to create resolve response."}`,
		))
		return
	}

	client.SocketSend(packets.NewChat(adminReportResolveResponsePrefix + string(data)))
}
