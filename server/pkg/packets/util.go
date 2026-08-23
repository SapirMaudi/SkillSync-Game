package packets

type Msg = isPacket_Msg

func NewChat(msg string) Msg {
	return &Packet_Chat{Chat: &ChatMessage{Msg: msg}}
}

func NewId(id uint64) Msg {
	return &Packet_Id{Id: &IdMessage{Id: id}}
}

func NewOkResponse() Msg {
	return &Packet_OkResponse{OkResponse: &OkResponseMessage{}}
}

func NewDenyResponse(reason string) Msg {
	return &Packet_ErrorResponse{ErrorResponse: &ErrorResponseMessage{Reason: reason}}
}

func NewResponseUserStats(kill uint64, death uint64, win uint64, losses uint64, cf uint64) Msg {
	return &Packet_ResponseUserStats{
		ResponseUserStats: &ResponseUserStatsMessage{
			Kills:         kill,
			Deaths:        death,
			Wins:          win,
			Losses:        losses,
			FlagsCaptured: cf,
		},
	}
}

func NewResponseUserName(name string) Msg {
	return &Packet_ResponseUserName{ResponseUserName: &ResponseUserNameMessage{Nickname: name}}
}

func NewResponseUserSkin(skinID uint64) Msg {
	return &Packet_ResponseUserSkin{ResponseUserSkin: &ResponseUserSkinMessage{SkinId: skinID}}
}

func NewRequestEnterQueue() Msg {
	return &Packet_RequestEnterQueue{RequestEnterQueue: &RequestEnterQueueMessage{}}
}

func NewRequestLeaveQueue() Msg {
	return &Packet_RequestLeaveQueue{RequestLeaveQueue: &RequestLeaveQueueMessage{}}
}

func NewRequestReturnToLobby() Msg {
	return &Packet_RequestReturnToLobby{
		RequestReturnToLobby: &RequestReturnToLobbyMessage{},
	}
}

func NewQueueJoined(position uint32, size uint32) Msg {
	return &Packet_QueueJoined{QueueJoined: &QueueJoinedMessage{Position: position, Size: size}}
}

func NewQueueLeft() Msg {
	return &Packet_QueueLeft{QueueLeft: &QueueLeftMessage{}}
}

func NewMatchFound(gameID uint64, team uint32, teamIDs []uint64, enemyIDs []uint64) Msg {
	return &Packet_MatchFound{
		MatchFound: &MatchFoundMessage{
			GameId:   gameID,
			Team:     team,
			TeamIds:  teamIDs,
			EnemyIds: enemyIDs,
		},
	}
}

func NewSpawnPlayer(
	gameID uint64,
	playerID uint64,
	team uint32,
	slot uint32,
	x float32,
	y float32,
	nickname string,
	skinID uint64,
	currentHP uint32,
	maxHP uint32,
	aimX float32,
	aimY float32,
) Msg {
	return &Packet_SpawnPlayer{
		SpawnPlayer: &SpawnPlayerMessage{
			GameId:    gameID,
			PlayerId:  playerID,
			Team:      team,
			Slot:      slot,
			X:         x,
			Y:         y,
			Nickname:  nickname,
			SkinId:    skinID,
			CurrentHp: currentHP,
			MaxHp:     maxHP,
			AimX:      aimX,
			AimY:      aimY,
		},
	}
}

func NewDespawnPlayer(gameID uint64, playerID uint64) Msg {
	return &Packet_DespawnPlayer{DespawnPlayer: &DespawnPlayerMessage{GameId: gameID, PlayerId: playerID}}
}

func NewPlayerMoved(gameID uint64, playerID uint64, x float32, y float32) Msg {
	return &Packet_PlayerMoved{
		PlayerMoved: &PlayerMovedMessage{
			GameId:   gameID,
			PlayerId: playerID,
			X:        x,
			Y:        y,
		},
	}
}

func NewPlayerHealthUpdated(gameID uint64, playerID uint64, currentHP uint32, maxHP uint32) Msg {
	return &Packet_PlayerHealthUpdated{
		PlayerHealthUpdated: &PlayerHealthUpdatedMessage{
			GameId:    gameID,
			PlayerId:  playerID,
			CurrentHp: currentHP,
			MaxHp:     maxHP,
		},
	}
}

func NewSpawnFlag(
	gameID uint64,
	team uint32,
	x float32,
	y float32,
	status uint32,
	carrierPlayerID uint64,
) Msg {
	return &Packet_SpawnFlag{
		SpawnFlag: &SpawnFlagMessage{
			GameId:          gameID,
			Team:            team,
			X:               x,
			Y:               y,
			Status:          status,
			CarrierPlayerId: carrierPlayerID,
		},
	}
}

func NewFlagStateUpdated(
	gameID uint64,
	team uint32,
	x float32,
	y float32,
	status uint32,
	carrierPlayerID uint64,
) Msg {
	return &Packet_FlagStateUpdated{
		FlagStateUpdated: &FlagStateUpdatedMessage{
			GameId:          gameID,
			Team:            team,
			X:               x,
			Y:               y,
			Status:          status,
			CarrierPlayerId: carrierPlayerID,
		},
	}
}

func NewScoreUpdated(gameID uint64, redScore uint32, blueScore uint32) Msg {
	return &Packet_ScoreUpdated{
		ScoreUpdated: &ScoreUpdatedMessage{
			GameId:    gameID,
			RedScore:  redScore,
			BlueScore: blueScore,
		},
	}
}

func NewGameTimeUpdated(gameID uint64, remainingSeconds uint32, durationSeconds uint32, isRunning bool) Msg {
	return &Packet_GameTimeUpdated{
		GameTimeUpdated: &GameTimeUpdatedMessage{
			GameId:           gameID,
			RemainingSeconds: remainingSeconds,
			DurationSeconds:  durationSeconds,
			IsRunning:        isRunning,
		},
	}
}

func NewPlayerAimUpdated(gameID uint64, playerID uint64, aimX float32, aimY float32) Msg {
	return &Packet_PlayerAimUpdated{
		PlayerAimUpdated: &PlayerAimUpdatedMessage{
			GameId:   gameID,
			PlayerId: playerID,
			AimX:     aimX,
			AimY:     aimY,
		},
	}
}

func NewBulletSpawned(
	gameID uint64,
	bulletID uint64,
	ownerPlayerID uint64,
	x float32,
	y float32,
	dirX float32,
	dirY float32,
	speedTilesPerSecond float32,
	lifetimeSeconds float32,
) Msg {
	return &Packet_BulletSpawned{
		BulletSpawned: &BulletSpawnedMessage{
			GameId:              gameID,
			BulletId:            bulletID,
			OwnerPlayerId:       ownerPlayerID,
			X:                   x,
			Y:                   y,
			DirX:                dirX,
			DirY:                dirY,
			SpeedTilesPerSecond: speedTilesPerSecond,
			LifetimeSeconds:     lifetimeSeconds,
		},
	}
}

func NewBulletHit(
	gameID uint64,
	bulletID uint64,
	ownerPlayerID uint64,
	victimPlayerID uint64,
	damage uint32,
	currentHP uint32,
	maxHP uint32,
	x float32,
	y float32,
) Msg {
	return &Packet_BulletHit{
		BulletHit: &BulletHitMessage{
			GameId:         gameID,
			BulletId:       bulletID,
			OwnerPlayerId:  ownerPlayerID,
			VictimPlayerId: victimPlayerID,
			Damage:         damage,
			CurrentHp:      currentHP,
			MaxHp:          maxHP,
			X:              x,
			Y:              y,
		},
	}
}

func NewSkillActivated(
	gameID uint64,
	playerID uint64,
	skillID uint32,
	activeMS uint32,
	cooldownMS uint32,
	targetX float32,
	targetY float32,
) Msg {
	return &Packet_SkillActivated{
		SkillActivated: &SkillActivatedMessage{
			GameId:     gameID,
			PlayerId:   playerID,
			SkillId:    skillID,
			ActiveMs:   activeMS,
			CooldownMs: cooldownMS,
			TargetX:    targetX,
			TargetY:    targetY,
		},
	}
}

func NewPlayerHealed(
	gameID uint64,
	healerPlayerID uint64,
	targetPlayerID uint64,
	amount uint32,
	currentHP uint32,
	maxHP uint32,
	x float32,
	y float32,
) Msg {
	return &Packet_PlayerHealed{
		PlayerHealed: &PlayerHealedMessage{
			GameId:         gameID,
			HealerPlayerId: healerPlayerID,
			TargetPlayerId: targetPlayerID,
			Amount:         amount,
			CurrentHp:      currentHP,
			MaxHp:          maxHP,
			X:              x,
			Y:              y,
		},
	}
}

func NewMolotovSpawned(
	gameID uint64,
	molotovID uint64,
	ownerPlayerID uint64,
	x float32,
	y float32,
	radiusTiles float32,
	durationSeconds float32,
) Msg {
	return &Packet_MolotovSpawned{
		MolotovSpawned: &MolotovSpawnedMessage{
			GameId:          gameID,
			MolotovId:       molotovID,
			OwnerPlayerId:   ownerPlayerID,
			X:               x,
			Y:               y,
			RadiusTiles:     radiusTiles,
			DurationSeconds: durationSeconds,
		},
	}
}

func NewSkillDamage(
	gameID uint64,
	skillID uint32,
	sourcePlayerID uint64,
	victimPlayerID uint64,
	damage uint32,
	currentHP uint32,
	maxHP uint32,
	x float32,
	y float32,
) Msg {
	return &Packet_SkillDamage{
		SkillDamage: &SkillDamageMessage{
			GameId:         gameID,
			SkillId:        skillID,
			SourcePlayerId: sourcePlayerID,
			VictimPlayerId: victimPlayerID,
			Damage:         damage,
			CurrentHp:      currentHP,
			MaxHp:          maxHP,
			X:              x,
			Y:              y,
		},
	}
}

func NewPlayerDied(gameID uint64, playerID uint64, respawnSeconds uint32) Msg {
	return &Packet_PlayerDied{
		PlayerDied: &PlayerDiedMessage{
			GameId:         gameID,
			PlayerId:       playerID,
			RespawnSeconds: respawnSeconds,
		},
	}
}

func NewPlayerRespawned(
	gameID uint64,
	playerID uint64,
	x float32,
	y float32,
	currentHP uint32,
	maxHP uint32,
) Msg {
	return &Packet_PlayerRespawned{
		PlayerRespawned: &PlayerRespawnedMessage{
			GameId:    gameID,
			PlayerId:  playerID,
			X:         x,
			Y:         y,
			CurrentHp: currentHP,
			MaxHp:     maxHP,
		},
	}
}

func NewMatchPlayerResult(
	playerID uint64,
	nickname string,
	team uint32,
	kills uint32,
	deaths uint32,
	captures uint32,
	won bool,
	lost bool,
) *MatchPlayerResultMessage {
	return &MatchPlayerResultMessage{
		PlayerId: playerID,
		Nickname: nickname,
		Team:     team,
		Kills:    kills,
		Deaths:   deaths,
		Captures: captures,
		Won:      won,
		Lost:     lost,
	}
}

func NewMatchEnded(
	gameID uint64,
	redScore uint32,
	blueScore uint32,
	winningTeam uint32,
	reason string,
	results []*MatchPlayerResultMessage,
) Msg {
	return &Packet_MatchEnded{
		MatchEnded: &MatchEndedMessage{
			GameId:      gameID,
			RedScore:    redScore,
			BlueScore:   blueScore,
			WinningTeam: winningTeam,
			Reason:      reason,
			Results:     results,
		},
	}
}
