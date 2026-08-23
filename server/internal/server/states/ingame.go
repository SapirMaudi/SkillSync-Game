package states

import (
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/game"
	"server/pkg/packets"
	"time"
)

type InGame struct {
	client server.ClientInterfacer
	logger *log.Logger
}

func (s *InGame) Name() string { return "InGame" }

func (s *InGame) SetClient(client server.ClientInterfacer) {
	s.client = client
	prefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), s.Name())
	s.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (s *InGame) OnEnter() {
	session, ok := s.client.Hub().Games.GetByPlayer(s.client.Id())
	if !ok {
		s.logger.Println("player entered InGame without active session")
		s.client.SocketSend(packets.NewDenyResponse("game session not found"))
		return
	}

	dbTx := s.client.Hub().NewDbTx()
	queries := dbTx.Queries
	dbCtx := dbTx.Ctx

	for _, playerID := range session.AllPlayers {
		playerState, ok := session.Players[playerID]
		if !ok {
			continue
		}

		nickname := fmt.Sprintf("P%d", playerState.PlayerID)
		var skinID uint64 = 0

		peer, ok := s.client.Hub().Clients.Get(playerID)
		if ok && peer.UserDbId() != 0 {
			user, err := queries.GetUserByID(dbCtx, int64(peer.UserDbId()))
			if err != nil {
				s.logger.Printf("failed to load user data for player %d: %v", playerID, err)
			} else {
				nickname = user.Nickname
				if user.SelectedCharacter.Valid {
					skinID = uint64(user.SelectedCharacter.Int64)
				}
			}
		}

		s.client.SocketSend(packets.NewSpawnPlayer(
			session.ID,
			playerState.PlayerID,
			playerState.Team,
			playerState.Slot,
			playerState.Position.X,
			playerState.Position.Y,
			nickname,
			skinID,
			playerState.CurrentHP,
			playerState.MaxHP,
			playerState.AimX,
			playerState.AimY,
		))
	}

	for _, flag := range session.Flags {
		s.client.SocketSend(packets.NewSpawnFlag(
			session.ID,
			flag.Team,
			flag.Position.X,
			flag.Position.Y,
			flag.Status,
			flag.CarrierPlayerID,
		))
	}

	s.client.SocketSend(packets.NewScoreUpdated(
		session.ID,
		session.Scores[game.TeamRed],
		session.Scores[game.TeamBlue],
	))

	now := time.Now()

	s.client.SocketSend(packets.NewGameTimeUpdated(
		session.ID,
		session.RemainingSeconds(now),
		game.MatchDurationSeconds,
		session.IsTimerRunning(now),
	))
}

func (s *InGame) HandleMessage(senderId uint64, message packets.Msg) {
	switch message := message.(type) {
	case *packets.Packet_Chat:
		if handleReportChat(s.client, s.logger, senderId, message) {
			return
		}
		s.client.SocketSend(packets.NewDenyResponse("chat message not allowed in InGame state"))

	case *packets.Packet_MovementInput:
		s.handleMovementInput(senderId, message)

	case *packets.Packet_AimInput:
		s.handleAimInput(senderId, message)

	case *packets.Packet_ShootRequest:
		s.handleShootRequest(senderId, message)

	case *packets.Packet_SkillRequest:
		s.handleSkillRequest(senderId, message)

	case *packets.Packet_RequestReturnToLobby:
		s.handleReturnToLobby(senderId)

	default:
		s.client.SocketSend(packets.NewDenyResponse("message not allowed in InGame state"))
	}
}

func (s *InGame) handleReturnToLobby(senderId uint64) {
	if senderId != s.client.Id() {
		s.logger.Println("sender ID mismatch in return to lobby request")
		return
	}

	s.client.SetState(&Connected{})
}

func (s *InGame) handleSkillRequest(senderId uint64, message *packets.Packet_SkillRequest) {
	if senderId != s.client.Id() {
		s.logger.Println("sender ID mismatch in skill request")
		return
	}

	session, ok := s.client.Hub().Games.GetByPlayer(s.client.Id())
	if !ok {
		s.client.SocketSend(packets.NewDenyResponse("game session not found"))
		return
	}

	if message.SkillRequest.GameId != session.ID {
		s.logger.Printf("skill game_id mismatch: got=%d expected=%d", message.SkillRequest.GameId, session.ID)
		return
	}

	updatedSession, result, reason, ok := s.client.Hub().Games.UseSkill(
		s.client.Id(),
		message.SkillRequest.SkillId,
		message.SkillRequest.TargetX,
		message.SkillRequest.TargetY,
		time.Now(),
	)
	if !ok {
		if reason != "" {
			s.client.SocketSend(packets.NewDenyResponse(reason))
		}
		return
	}

	s.broadcastToSession(updatedSession, packets.NewSkillActivated(
		result.Activation.GameID,
		result.Activation.PlayerID,
		result.Activation.SkillID,
		result.Activation.ActiveMS,
		result.Activation.CooldownMS,
		result.Activation.Target.X,
		result.Activation.Target.Y,
	))

	for _, heal := range result.Heals {
		s.broadcastToSession(updatedSession, packets.NewPlayerHealed(
			heal.GameID,
			heal.HealerPlayerID,
			heal.TargetPlayerID,
			heal.Amount,
			heal.CurrentHP,
			heal.MaxHP,
			heal.Position.X,
			heal.Position.Y,
		))
	}

	if result.Molotov != nil {
		s.broadcastToSession(updatedSession, packets.NewMolotovSpawned(
			result.Molotov.GameID,
			result.Molotov.MolotovID,
			result.Molotov.OwnerPlayerID,
			result.Molotov.Position.X,
			result.Molotov.Position.Y,
			result.Molotov.RadiusTiles,
			result.Molotov.DurationSeconds,
		))
	}
}

func (s *InGame) handleMovementInput(senderId uint64, message *packets.Packet_MovementInput) {
	if senderId != s.client.Id() {
		s.logger.Println("sender ID mismatch in movement input")
		return
	}

	session, ok := s.client.Hub().Games.GetByPlayer(s.client.Id())
	if !ok {
		s.client.SocketSend(packets.NewDenyResponse("game session not found"))
		return
	}

	if message.MovementInput.GameId != session.ID {
		s.logger.Printf("movement game_id mismatch: got=%d expected=%d", message.MovementInput.GameId, session.ID)
		return
	}

	updatedSession, state, changedFlags, scoreUpdate, ok := s.client.Hub().Games.UpdatePlayerPosition(
		s.client.Id(),
		message.MovementInput.X,
		message.MovementInput.Y,
	)
	if !ok {
		s.logger.Println("failed to update player position")
		return
	}

	if state != nil {
		for _, peerID := range updatedSession.AllPlayers {
			if peerID == s.client.Id() {
				continue
			}

			peer, ok := s.client.Hub().Clients.Get(peerID)
			if !ok {
				continue
			}

			peer.SocketSend(packets.NewPlayerMoved(
				updatedSession.ID,
				state.PlayerID,
				state.Position.X,
				state.Position.Y,
			))
		}
	}

	for _, flagSnapshot := range changedFlags {
		s.broadcastToSession(updatedSession, packets.NewFlagStateUpdated(
			updatedSession.ID,
			flagSnapshot.Team,
			flagSnapshot.Position.X,
			flagSnapshot.Position.Y,
			flagSnapshot.Status,
			flagSnapshot.CarrierPlayerID,
		))
	}

	if scoreUpdate != nil {
		s.broadcastToSession(updatedSession, packets.NewScoreUpdated(
			updatedSession.ID,
			scoreUpdate.RedScore,
			scoreUpdate.BlueScore,
		))
	}
}

func (s *InGame) handleAimInput(senderId uint64, message *packets.Packet_AimInput) {
	if senderId != s.client.Id() {
		s.logger.Println("sender ID mismatch in aim input")
		return
	}

	session, ok := s.client.Hub().Games.GetByPlayer(s.client.Id())
	if !ok {
		s.client.SocketSend(packets.NewDenyResponse("game session not found"))
		return
	}

	if message.AimInput.GameId != session.ID {
		s.logger.Printf("aim game_id mismatch: got=%d expected=%d", message.AimInput.GameId, session.ID)
		return
	}

	updatedSession, state, ok := s.client.Hub().Games.SetPlayerAim(
		s.client.Id(),
		message.AimInput.AimX,
		message.AimInput.AimY,
	)
	if !ok {
		s.logger.Println("failed to update player aim")
		return
	}

	if state == nil {
		return
	}

	for _, peerID := range updatedSession.AllPlayers {
		if peerID == s.client.Id() {
			continue
		}

		peer, ok := s.client.Hub().Clients.Get(peerID)
		if !ok {
			continue
		}

		peer.SocketSend(packets.NewPlayerAimUpdated(
			updatedSession.ID,
			state.PlayerID,
			state.AimX,
			state.AimY,
		))
	}
}

func (s *InGame) handleShootRequest(senderId uint64, message *packets.Packet_ShootRequest) {
	if senderId != s.client.Id() {
		s.logger.Println("sender ID mismatch in shoot request")
		return
	}

	session, ok := s.client.Hub().Games.GetByPlayer(s.client.Id())
	if !ok {
		s.client.SocketSend(packets.NewDenyResponse("game session not found"))
		return
	}

	if message.ShootRequest.GameId != session.ID {
		s.logger.Printf("shoot game_id mismatch: got=%d expected=%d", message.ShootRequest.GameId, session.ID)
		return
	}

	updatedSession, bullet, ok := s.client.Hub().Games.SpawnBullet(
		s.client.Id(),
		message.ShootRequest.AimX,
		message.ShootRequest.AimY,
	)
	if !ok {
		s.logger.Println("failed to spawn bullet")
		return
	}

	s.broadcastToSession(updatedSession, packets.NewPlayerAimUpdated(
		updatedSession.ID,
		bullet.OwnerPlayerID,
		bullet.DirX,
		bullet.DirY,
	))

	s.broadcastToSession(updatedSession, packets.NewBulletSpawned(
		bullet.GameID,
		bullet.BulletID,
		bullet.OwnerPlayerID,
		bullet.Position.X,
		bullet.Position.Y,
		bullet.DirX,
		bullet.DirY,
		bullet.SpeedTilesPerSecond,
		bullet.LifetimeSeconds,
	))
}

func (s *InGame) broadcastToSession(session *game.Session, message packets.Msg) {
	for _, peerID := range session.AllPlayers {
		peer, ok := s.client.Hub().Clients.Get(peerID)
		if !ok {
			continue
		}

		peer.SocketSend(message)
	}
}

func (s *InGame) OnExit() {}
