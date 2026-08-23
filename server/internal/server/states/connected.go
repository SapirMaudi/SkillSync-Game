package states

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"server/pkg/packets"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

const settingsChangeNicknamePrefix = "SETTINGS_CHANGE_NICKNAME:"
const settingsChangePasswordPrefix = "SETTINGS_CHANGE_PASSWORD:"
const settingsResponsePrefix = "SETTINGS_RESPONSE:"

type Connected struct {
	client server.ClientInterfacer
	logger *log.Logger
	queies *db.Queries
	dbCtx  context.Context
}

type settingsChangeNicknamePayload struct {
	Nickname string `json:"nickname"`
}

type settingsChangePasswordPayload struct {
	Password string `json:"password"`
}

type settingsResponsePayload struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Action  string `json:"action"`
}

func (c *Connected) Name() string {
	return "Connected"
}

func (c *Connected) SetClient(client server.ClientInterfacer) {
	c.client = client
	loggingPrefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), c.Name())
	c.logger = log.New(log.Writer(), loggingPrefix, log.LstdFlags)
	c.queies = client.DbTx().Queries
	c.dbCtx = client.DbTx().Ctx
}

func (c *Connected) OnEnter() {
	c.client.SocketSend(packets.NewId(c.client.Id()))
}

func (c *Connected) HandleMessage(senderId uint64, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_Chat:
		if handleReportChat(c.client, c.logger, senderId, message) {
			return
		}

		if c.handleSettingsChat(senderId, message) {
			return
		}

		c.client.SocketSend(packets.NewDenyResponse("chat message not allowed in Connected state"))

	case *packets.Packet_LoginRequest:
		c.handleLoginRequest(senderId, message)

	case *packets.Packet_RegisterRequest:
		c.handleRegisterRequest(senderId, message)

	case *packets.Packet_RequestGeneralInfo:
		c.handleRequestGeneralInfo(senderId, message)

	case *packets.Packet_RequestUpdateUserSkin:
		c.handleRequestUpdateUserSkin(senderId, message)

	case *packets.Packet_RequestEnterQueue:
		if c.client.UserDbId() == 0 {
			c.client.SocketSend(packets.NewDenyResponse("must be logged in to enter queue"))
			return
		}
		c.client.SetState(&InQueue{})

	default:
		c.client.SocketSend(packets.NewDenyResponse("message not allowed in Connected state"))
	}
}

func (c *Connected) OnExit() {
}

func (c *Connected) handleLoginRequest(senderId uint64, message *packets.Packet_LoginRequest) {
	if senderId != c.client.Id() {
		c.logger.Println("sender ID mismatch in login request")
		return
	}

	userEmail := message.LoginRequest.Email
	failMessage := packets.NewDenyResponse("invalid email or password")

	user, err := c.queies.GetUserByEmail(c.dbCtx, strings.ToLower(userEmail))
	if err != nil {
		c.logger.Println("failed to get user by email", userEmail, ":", err)
		c.client.SocketSend(failMessage)
		return
	}

	if user.IsBanned.Bool {
		c.logger.Println("banned user", userEmail, "attempted to log in")
		c.client.SocketSend(packets.NewDenyResponse("user is banned"))
		return
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(message.LoginRequest.Password))
	if err != nil {
		c.logger.Println("invalid password for user", userEmail)
		c.client.SocketSend(failMessage)
		return
	}

	c.logger.Println("user", userEmail, "logged in successfully")
	c.client.SetUserDbId(uint64(user.PlayerID))
	c.client.SocketSend(packets.NewOkResponse())
}

func (c *Connected) handleRegisterRequest(senderId uint64, message *packets.Packet_RegisterRequest) {
	if senderId != c.client.Id() {
		c.logger.Println("sender ID mismatch in register request")
		return
	}

	userNickName := message.RegisterRequest.Nickname
	userEmail := message.RegisterRequest.Email
	err := validateNickname(userNickName)
	err2 := validateEmail(userEmail)

	if err != nil {
		c.logger.Println("invalid nickname")
		c.client.SocketSend(packets.NewDenyResponse("invalid nickname"))
		return
	}

	if err2 != nil {
		c.logger.Println("invalid email")
		c.client.SocketSend(packets.NewDenyResponse("invalid email"))
		return
	}

	if _, err := c.queies.GetUserByNickname(c.dbCtx, strings.ToLower(userNickName)); err == nil {
		c.logger.Println("nickname already taken:", userNickName)
		c.client.SocketSend(packets.NewDenyResponse("nickname already taken"))
		return
	}

	if _, err := c.queies.GetUserByEmail(c.dbCtx, strings.ToLower(userEmail)); err == nil {
		c.logger.Println("email already registered:", userEmail)
		c.client.SocketSend(packets.NewDenyResponse("email already registered"))
		return
	}

	genericFailMessage := packets.NewDenyResponse("failed to register user - please try again later")

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(message.RegisterRequest.Password), bcrypt.DefaultCost)
	if err != nil {
		c.logger.Println("failed to hash password for user", userEmail, ":", err)
		c.client.SocketSend(genericFailMessage)
		return
	}

	_, err = c.queies.CreateUser(c.dbCtx, db.CreateUserParams{
		Nickname:     strings.ToLower(userNickName),
		Email:        strings.ToLower(userEmail),
		PasswordHash: string(passwordHash),
	})
	if err != nil {
		c.logger.Println("failed to create user", userEmail, ":", err)
		c.client.SocketSend(genericFailMessage)
		return
	}

	c.logger.Println("user", userEmail, "registered successfully")
	c.client.SocketSend(packets.NewOkResponse())
}

func validateNickname(nickname string) error {
	if len(nickname) <= 0 {
		return errors.New("Empty nickname")
	}

	if len(nickname) > 20 {
		return errors.New("Nickname too long")
	}

	if strings.ContainsAny(nickname, " \t\n\r") {
		return errors.New("Nickname contains whitespace")
	}

	return nil
}

func validateEmail(email string) error {
	if len(email) <= 0 {
		return errors.New("Empty email")
	}

	if len(email) > 50 {
		return errors.New("Email too long")
	}

	if !strings.Contains(email, "@") {
		return errors.New("Email missing @")
	}

	if strings.ContainsAny(email, " \t\n\r") {
		return errors.New("Email contains whitespace")
	}

	return nil
}

func (c *Connected) handleRequestGeneralInfo(senderId uint64, message *packets.Packet_RequestGeneralInfo) {
	if senderId != c.client.Id() {
		c.logger.Println("sender ID mismatch at general info request")
		return
	}

	user, err := c.queies.GetUserByID(c.dbCtx, int64(c.client.UserDbId()))
	if err != nil {
		c.logger.Println("failed to get user by ID:", err)
		return
	}

	if message.RequestGeneralInfo.Info == "nickname" {
		c.logger.Println("user", user.Email, "requested nickname info")
		c.client.SocketSend(packets.NewResponseUserName(user.Nickname))
	} else if message.RequestGeneralInfo.Info == "stats" {
		c.logger.Println("user", user.Email, "requested stats info")
		c.client.SocketSend(packets.NewResponseUserStats(
			uint64(user.Kills.Int64),
			uint64(user.Deaths.Int64),
			uint64(user.Wins.Int64),
			uint64(user.Losses.Int64),
			uint64(user.FlagCaptures.Int64),
		))
	} else if message.RequestGeneralInfo.Info == "skin" {
		c.logger.Println("user", user.Email, "requested skin info")
		c.client.SocketSend(packets.NewResponseUserSkin(uint64(user.SelectedCharacter.Int64)))
	}
}

func (c *Connected) handleRequestUpdateUserSkin(senderId uint64, message *packets.Packet_RequestUpdateUserSkin) {
	if senderId != c.client.Id() {
		c.logger.Println("sender ID mismatch at update user skin request")
		return
	}

	user, err := c.queies.GetUserByID(c.dbCtx, int64(c.client.UserDbId()))
	if err != nil {
		c.logger.Println("failed to get user by ID:", err)
		return
	}

	_, err = c.queies.UpdateUserSkin(c.dbCtx, db.UpdateUserSkinParams{
		SelectedCharacter: sql.NullInt64{Int64: int64(message.RequestUpdateUserSkin.SkinId), Valid: true},
		PlayerID:          int64(c.client.UserDbId()),
	})
	if err != nil {
		c.logger.Println("failed to update user skin:", err)
		return
	}

	c.logger.Println("user", user.Email, "updated skin successfully")
}

func (c *Connected) handleSettingsChat(senderId uint64, message *packets.Packet_Chat) bool {
	if message == nil || message.Chat == nil {
		return false
	}

	raw := message.Chat.Msg

	switch {
	case strings.HasPrefix(raw, settingsChangeNicknamePrefix):
		c.handleChangeNickname(senderId, strings.TrimPrefix(raw, settingsChangeNicknamePrefix))
		return true

	case strings.HasPrefix(raw, settingsChangePasswordPrefix):
		c.handleChangePassword(senderId, strings.TrimPrefix(raw, settingsChangePasswordPrefix))
		return true

	default:
		return false
	}
}

func (c *Connected) handleChangeNickname(senderId uint64, jsonText string) {
	if senderId != c.client.Id() {
		c.sendSettingsResponse(false, "Failed to change nickname.", "nickname")
		return
	}

	if c.client.UserDbId() == 0 {
		c.sendSettingsResponse(false, "You must be logged in to change nickname.", "nickname")
		return
	}

	var payload settingsChangeNicknamePayload
	if err := json.Unmarshal([]byte(jsonText), &payload); err != nil {
		c.logger.Println("invalid nickname change JSON:", err)
		c.sendSettingsResponse(false, "Invalid nickname request.", "nickname")
		return
	}

	newNickname := strings.ToLower(strings.TrimSpace(payload.Nickname))

	if err := validateNickname(newNickname); err != nil {
		c.sendSettingsResponse(false, "Invalid nickname.", "nickname")
		return
	}

	currentUser, err := c.queies.GetUserByID(c.dbCtx, int64(c.client.UserDbId()))
	if err != nil {
		c.logger.Println("failed to load current user:", err)
		c.sendSettingsResponse(false, "Failed to change nickname.", "nickname")
		return
	}

	existingUser, err := c.queies.GetUserByNickname(c.dbCtx, newNickname)
	if err == nil && existingUser.PlayerID != currentUser.PlayerID {
		c.sendSettingsResponse(false, "Nickname already taken.", "nickname")
		return
	}

	_, err = c.queies.UpdateUserNickname(c.dbCtx, db.UpdateUserNicknameParams{
		Nickname: newNickname,
		PlayerID: int64(c.client.UserDbId()),
	})
	if err != nil {
		c.logger.Println("failed to update nickname:", err)
		c.sendSettingsResponse(false, "Failed to change nickname.", "nickname")
		return
	}

	c.logger.Println("user", currentUser.Email, "changed nickname to", newNickname)
	c.sendSettingsResponse(true, "Nickname changed successfully.", "nickname")
	c.client.SocketSend(packets.NewResponseUserName(newNickname))
}

func (c *Connected) handleChangePassword(senderId uint64, jsonText string) {
	if senderId != c.client.Id() {
		c.sendSettingsResponse(false, "Failed to change password.", "password")
		return
	}

	if c.client.UserDbId() == 0 {
		c.sendSettingsResponse(false, "You must be logged in to change password.", "password")
		return
	}

	var payload settingsChangePasswordPayload
	if err := json.Unmarshal([]byte(jsonText), &payload); err != nil {
		c.logger.Println("invalid password change JSON:", err)
		c.sendSettingsResponse(false, "Invalid password request.", "password")
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(payload.Password), bcrypt.DefaultCost)
	if err != nil {
		c.logger.Println("failed to hash new password:", err)
		c.sendSettingsResponse(false, "Failed to change password.", "password")
		return
	}

	_, err = c.queies.UpdateUserPassword(c.dbCtx, db.UpdateUserPasswordParams{
		PasswordHash: string(passwordHash),
		PlayerID:     int64(c.client.UserDbId()),
	})
	if err != nil {
		c.logger.Println("failed to update password:", err)
		c.sendSettingsResponse(false, "Failed to change password.", "password")
		return
	}

	c.logger.Println("user", c.client.UserDbId(), "changed password")
	c.sendSettingsResponse(true, "Password changed successfully.", "password")
}

func (c *Connected) sendSettingsResponse(success bool, message string, action string) {
	payload := settingsResponsePayload{
		Success: success,
		Message: message,
		Action:  action,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		c.client.SocketSend(packets.NewChat(settingsResponsePrefix + `{"success":false,"message":"Failed to create response.","action":"unknown"}`))
		return
	}

	c.client.SocketSend(packets.NewChat(settingsResponsePrefix + string(data)))
}
