package game

import (
	"math"
	"math/rand"
	"sync"
	"sync/atomic"
	"time"
)

const (
	TeamRed  uint32 = 1
	TeamBlue uint32 = 2

	WinningTeamTie uint32 = 0
	MaxTeamScore   uint32 = 3

	DefaultMaxHP uint32 = 100

	FlagStatusAtBase  uint32 = 0
	FlagStatusCarried uint32 = 1
	FlagStatusDropped uint32 = 2

	FlagTouchRadius float32 = 2.5

	MatchDurationSeconds uint32 = 180

	BulletSpawnOffsetTiles    float32 = 1.2
	BulletSpeedTilesPerSecond float32 = 32.0
	BulletLifetimeSeconds     float32 = 1.2
	BulletHitRadiusTiles      float32 = 0.85

	MinBulletDamage uint32 = 2
	MaxBulletDamage uint32 = 5

	ShootCooldown = 150 * time.Millisecond

	RespawnDuration               = 5 * time.Second
	RespawnDurationSeconds uint32 = 5

	SkillHaste   uint32 = 1
	SkillHeal    uint32 = 2
	SkillMolotov uint32 = 3

	HasteDuration          = 5 * time.Second
	HasteCooldown          = 20 * time.Second
	HasteActiveMS   uint32 = 5000
	HasteCooldownMS uint32 = 20000

	HealAmount     uint32 = 30
	HealCooldown          = 40 * time.Second
	HealCooldownMS uint32 = 40000

	MolotovCooldown                = 60 * time.Second
	MolotovCooldownMS      uint32  = 60000
	MolotovDuration                = 5 * time.Second
	MolotovDurationSeconds float32 = 5.0
	MolotovRadiusTiles     float32 = 3.0
	MolotovDamagePerTick   uint32  = 8
	MolotovTickInterval            = 1 * time.Second
)

type Position struct {
	X float32
	Y float32
}

type PlayerState struct {
	PlayerID      uint64
	Team          uint32
	Slot          uint32
	Position      Position
	SpawnPosition Position
	CurrentHP     uint32
	MaxHP         uint32
	AimX          float32
	AimY          float32

	MatchKills    uint32
	MatchDeaths   uint32
	MatchCaptures uint32

	LastShotAt    time.Time
	HasteEndsAt   time.Time
	SkillCooldown map[uint32]time.Time

	IsDead    bool
	RespawnAt time.Time
}

type BulletState struct {
	BulletID         uint64
	OwnerPlayerID    uint64
	OwnerTeam        uint32
	Position         Position
	DirX             float32
	DirY             float32
	SpeedTilesPerSec float32
	CreatedAt        time.Time
	LastUpdatedAt    time.Time
	ExpiresAt        time.Time
}

type MolotovState struct {
	MolotovID     uint64
	OwnerPlayerID uint64
	Position      Position
	RadiusTiles   float32
	CreatedAt     time.Time
	ExpiresAt     time.Time
	NextTickAt    time.Time
}

type FlagState struct {
	Team            uint32
	BasePosition    Position
	Position        Position
	Status          uint32
	CarrierPlayerID uint64
}

type FlagSnapshot struct {
	Team            uint32
	Position        Position
	Status          uint32
	CarrierPlayerID uint64
}

type ScoreSnapshot struct {
	RedScore  uint32
	BlueScore uint32
}

type HealthSnapshot struct {
	PlayerID  uint64
	CurrentHP uint32
	MaxHP     uint32
}

type TimerSnapshot struct {
	GameID           uint64
	RemainingSeconds uint32
	DurationSeconds  uint32
	IsRunning        bool
	Players          []uint64
}

type DeathSnapshot struct {
	GameID         uint64
	PlayerID       uint64
	RespawnSeconds uint32
	Players        []uint64
}

type RespawnSnapshot struct {
	GameID    uint64
	PlayerID  uint64
	Position  Position
	CurrentHP uint32
	MaxHP     uint32
	Players   []uint64
}

type BulletSnapshot struct {
	GameID              uint64
	BulletID            uint64
	OwnerPlayerID       uint64
	Position            Position
	DirX                float32
	DirY                float32
	SpeedTilesPerSecond float32
	LifetimeSeconds     float32
}

type BulletHitSnapshot struct {
	GameID         uint64
	BulletID       uint64
	OwnerPlayerID  uint64
	VictimPlayerID uint64
	Damage         uint32
	CurrentHP      uint32
	MaxHP          uint32
	Position       Position
	Players        []uint64
	Death          *DeathSnapshot
	ChangedFlags   []FlagSnapshot
}

type SkillActivationSnapshot struct {
	GameID     uint64
	PlayerID   uint64
	SkillID    uint32
	ActiveMS   uint32
	CooldownMS uint32
	Target     Position
	Players    []uint64
}

type HealSnapshot struct {
	GameID         uint64
	HealerPlayerID uint64
	TargetPlayerID uint64
	Amount         uint32
	CurrentHP      uint32
	MaxHP          uint32
	Position       Position
	Players        []uint64
}

type MolotovSnapshot struct {
	GameID          uint64
	MolotovID       uint64
	OwnerPlayerID   uint64
	Position        Position
	RadiusTiles     float32
	DurationSeconds float32
	Players         []uint64
}

type SkillDamageSnapshot struct {
	GameID         uint64
	SkillID        uint32
	SourcePlayerID uint64
	VictimPlayerID uint64
	Damage         uint32
	CurrentHP      uint32
	MaxHP          uint32
	Position       Position
	Players        []uint64
	Death          *DeathSnapshot
	ChangedFlags   []FlagSnapshot
}

type PlayerResultSnapshot struct {
	PlayerID uint64
	Team     uint32
	Kills    uint32
	Deaths   uint32
	Captures uint32
	Won      bool
	Lost     bool
}

type MatchEndedSnapshot struct {
	GameID      uint64
	RedScore    uint32
	BlueScore   uint32
	WinningTeam uint32
	Reason      string
	Players     []uint64
	Results     []PlayerResultSnapshot
}

type SkillUseResult struct {
	Activation SkillActivationSnapshot
	Heals      []HealSnapshot
	Molotov    *MolotovSnapshot
}

type Session struct {
	ID         uint64
	Team1      []uint64
	Team2      []uint64
	AllPlayers []uint64
	Players    map[uint64]*PlayerState
	Flags      map[uint32]*FlagState
	Scores     map[uint32]uint32
	Bullets    map[uint64]*BulletState
	Molotovs   map[uint64]*MolotovState

	StartedAt time.Time
	EndsAt    time.Time

	Ended       bool
	EndNotified bool
	EndReason   string
	WinningTeam uint32
}

type Manager struct {
	nextID        uint64
	nextBulletID  uint64
	nextMolotovID uint64

	mu           sync.Mutex
	sessions     map[uint64]*Session
	playerToGame map[uint64]uint64
}

func New() *Manager {
	return &Manager{
		sessions:     make(map[uint64]*Session),
		playerToGame: make(map[uint64]uint64),
	}
}

func NewPosition(x, y float32) Position {
	return Position{X: x, Y: y}
}

func normalizeDirection(x float32, y float32) (float32, float32) {
	length := math.Sqrt(float64(x*x + y*y))
	if length <= 0.0001 {
		return 1.0, 0.0
	}

	return float32(float64(x) / length), float32(float64(y) / length)
}

func newPlayerState(playerID uint64, team uint32, slot uint32, position Position) *PlayerState {
	return &PlayerState{
		PlayerID:      playerID,
		Team:          team,
		Slot:          slot,
		Position:      position,
		SpawnPosition: position,
		CurrentHP:     DefaultMaxHP,
		MaxHP:         DefaultMaxHP,
		AimX:          1.0,
		AimY:          0.0,
		MatchKills:    0,
		MatchDeaths:   0,
		MatchCaptures: 0,
		LastShotAt:    time.Time{},
		HasteEndsAt:   time.Time{},
		SkillCooldown: make(map[uint32]time.Time),
		IsDead:        false,
		RespawnAt:     time.Time{},
	}
}

func midpoint(a Position, b Position) Position {
	return Position{X: (a.X + b.X) / 2.0, Y: (a.Y + b.Y) / 2.0}
}

func distance(a Position, b Position) float32 {
	dx := float64(a.X - b.X)
	dy := float64(a.Y - b.Y)

	return float32(math.Sqrt(dx*dx + dy*dy))
}

func randomBulletDamage() uint32 {
	damageRange := int(MaxBulletDamage-MinBulletDamage) + 1
	return MinBulletDamage + uint32(rand.Intn(damageRange))
}

func copyPlayersList(session *Session) []uint64 {
	players := make([]uint64, 0, len(session.AllPlayers))
	players = append(players, session.AllPlayers...)
	return players
}

func enemyTeam(team uint32) uint32 {
	if team == TeamRed {
		return TeamBlue
	}

	return TeamRed
}

func copyPlayerState(state *PlayerState) *PlayerState {
	if state == nil {
		return nil
	}

	return &PlayerState{
		PlayerID:      state.PlayerID,
		Team:          state.Team,
		Slot:          state.Slot,
		Position:      state.Position,
		SpawnPosition: state.SpawnPosition,
		CurrentHP:     state.CurrentHP,
		MaxHP:         state.MaxHP,
		AimX:          state.AimX,
		AimY:          state.AimY,
		MatchKills:    state.MatchKills,
		MatchDeaths:   state.MatchDeaths,
		MatchCaptures: state.MatchCaptures,
		LastShotAt:    state.LastShotAt,
		HasteEndsAt:   state.HasteEndsAt,
		IsDead:        state.IsDead,
		RespawnAt:     state.RespawnAt,
	}
}

func copyFlagSnapshot(flag *FlagState) FlagSnapshot {
	return FlagSnapshot{
		Team:            flag.Team,
		Position:        flag.Position,
		Status:          flag.Status,
		CarrierPlayerID: flag.CarrierPlayerID,
	}
}

func (s *Session) RemainingSeconds(now time.Time) uint32 {
	if now.After(s.EndsAt) || now.Equal(s.EndsAt) {
		return 0
	}

	return uint32(s.EndsAt.Sub(now).Seconds())
}

func (s *Session) IsTimerRunning(now time.Time) bool {
	return s.RemainingSeconds(now) > 0
}

func (m *Manager) Create2v2(players [4]uint64) *Session {
	gameID := atomic.AddUint64(&m.nextID, 1)

	startedAt := time.Now()
	endsAt := startedAt.Add(time.Duration(MatchDurationSeconds) * time.Second)

	redSlot1Position := NewPosition(9, 6)
	redSlot2Position := NewPosition(9, 31)
	blueSlot1Position := NewPosition(64, 6)
	blueSlot2Position := NewPosition(64, 31)

	redFlagPosition := midpoint(redSlot1Position, redSlot2Position)
	blueFlagPosition := midpoint(blueSlot1Position, blueSlot2Position)

	s := &Session{
		ID:         gameID,
		Team1:      []uint64{players[0], players[1]},
		Team2:      []uint64{players[2], players[3]},
		AllPlayers: []uint64{players[0], players[1], players[2], players[3]},
		Players: map[uint64]*PlayerState{
			players[0]: newPlayerState(players[0], TeamRed, 1, redSlot1Position),
			players[1]: newPlayerState(players[1], TeamRed, 2, redSlot2Position),
			players[2]: newPlayerState(players[2], TeamBlue, 1, blueSlot1Position),
			players[3]: newPlayerState(players[3], TeamBlue, 2, blueSlot2Position),
		},
		Flags: map[uint32]*FlagState{
			TeamRed: {
				Team:            TeamRed,
				BasePosition:    redFlagPosition,
				Position:        redFlagPosition,
				Status:          FlagStatusAtBase,
				CarrierPlayerID: 0,
			},
			TeamBlue: {
				Team:            TeamBlue,
				BasePosition:    blueFlagPosition,
				Position:        blueFlagPosition,
				Status:          FlagStatusAtBase,
				CarrierPlayerID: 0,
			},
		},
		Scores: map[uint32]uint32{
			TeamRed:  0,
			TeamBlue: 0,
		},
		Bullets:     make(map[uint64]*BulletState),
		Molotovs:    make(map[uint64]*MolotovState),
		StartedAt:   startedAt,
		EndsAt:      endsAt,
		Ended:       false,
		EndNotified: false,
		EndReason:   "",
		WinningTeam: WinningTeamTie,
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	m.sessions[gameID] = s

	for _, pid := range s.AllPlayers {
		m.playerToGame[pid] = gameID
	}

	return s
}

func (m *Manager) GetByPlayer(playerID uint64) (*Session, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	gameID, ok := m.playerToGame[playerID]
	if !ok {
		return nil, false
	}

	s, ok := m.sessions[gameID]
	return s, ok
}

func (m *Manager) TimerSnapshots(now time.Time) []TimerSnapshot {
	m.mu.Lock()
	defer m.mu.Unlock()

	snapshots := make([]TimerSnapshot, 0, len(m.sessions))

	for _, session := range m.sessions {
		if session.Ended {
			continue
		}

		snapshots = append(snapshots, TimerSnapshot{
			GameID:           session.ID,
			RemainingSeconds: session.RemainingSeconds(now),
			DurationSeconds:  MatchDurationSeconds,
			IsRunning:        session.IsTimerRunning(now),
			Players:          copyPlayersList(session),
		})
	}

	return snapshots
}

func (m *Manager) ProcessEndedGames(now time.Time) []MatchEndedSnapshot {
	m.mu.Lock()
	defer m.mu.Unlock()

	endedMatches := make([]MatchEndedSnapshot, 0)

	for _, session := range m.sessions {
		if session.EndNotified {
			continue
		}

		if session.Ended {
			session.EndNotified = true
			endedMatches = append(endedMatches, m.buildMatchEndedSnapshotLocked(session))
			continue
		}

		if now.Before(session.EndsAt) {
			continue
		}

		session.Ended = true
		session.EndReason = "time"

		redScore := session.Scores[TeamRed]
		blueScore := session.Scores[TeamBlue]

		if redScore > blueScore {
			session.WinningTeam = TeamRed
		} else if blueScore > redScore {
			session.WinningTeam = TeamBlue
		} else {
			session.WinningTeam = WinningTeamTie
		}

		session.EndNotified = true
		endedMatches = append(endedMatches, m.buildMatchEndedSnapshotLocked(session))
	}

	return endedMatches
}

func (m *Manager) buildMatchEndedSnapshotLocked(session *Session) MatchEndedSnapshot {
	results := make([]PlayerResultSnapshot, 0, len(session.AllPlayers))

	for _, playerID := range session.AllPlayers {
		player, ok := session.Players[playerID]
		if !ok {
			continue
		}

		won := false
		lost := false

		if session.WinningTeam == WinningTeamTie {
			lost = true
		} else if player.Team == session.WinningTeam {
			won = true
		} else {
			lost = true
		}

		results = append(results, PlayerResultSnapshot{
			PlayerID: player.PlayerID,
			Team:     player.Team,
			Kills:    player.MatchKills,
			Deaths:   player.MatchDeaths,
			Captures: player.MatchCaptures,
			Won:      won,
			Lost:     lost,
		})
	}

	return MatchEndedSnapshot{
		GameID:      session.ID,
		RedScore:    session.Scores[TeamRed],
		BlueScore:   session.Scores[TeamBlue],
		WinningTeam: session.WinningTeam,
		Reason:      session.EndReason,
		Players:     copyPlayersList(session),
		Results:     results,
	}
}

func (m *Manager) ProcessRespawns(now time.Time) []RespawnSnapshot {
	m.mu.Lock()
	defer m.mu.Unlock()

	respawns := make([]RespawnSnapshot, 0)

	for _, session := range m.sessions {
		if session.Ended {
			continue
		}

		for _, player := range session.Players {
			if !player.IsDead {
				continue
			}

			if now.Before(player.RespawnAt) {
				continue
			}

			player.IsDead = false
			player.RespawnAt = time.Time{}
			player.CurrentHP = player.MaxHP
			player.Position = player.SpawnPosition
			player.HasteEndsAt = time.Time{}

			respawns = append(respawns, RespawnSnapshot{
				GameID:    session.ID,
				PlayerID:  player.PlayerID,
				Position:  player.Position,
				CurrentHP: player.CurrentHP,
				MaxHP:     player.MaxHP,
				Players:   copyPlayersList(session),
			})
		}
	}

	return respawns
}

func (m *Manager) UseSkill(playerID uint64, skillID uint32, targetX float32, targetY float32, now time.Time) (*Session, SkillUseResult, string, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	gameID, ok := m.playerToGame[playerID]
	if !ok {
		return nil, SkillUseResult{}, "player is not in a game", false
	}

	session, ok := m.sessions[gameID]
	if !ok {
		return nil, SkillUseResult{}, "game session not found", false
	}

	if session.Ended {
		return nil, SkillUseResult{}, "match already ended", false
	}

	player, ok := session.Players[playerID]
	if !ok {
		return nil, SkillUseResult{}, "player state not found", false
	}

	if player.IsDead || player.CurrentHP == 0 {
		return nil, SkillUseResult{}, "dead players cannot use skills", false
	}

	cooldownUntil := player.SkillCooldown[skillID]
	if !cooldownUntil.IsZero() && now.Before(cooldownUntil) {
		return nil, SkillUseResult{}, "skill is on cooldown", false
	}

	switch skillID {
	case SkillHaste:
		return m.useHasteLocked(session, player, now)

	case SkillHeal:
		return m.useHealLocked(session, player, now)

	case SkillMolotov:
		return m.useMolotovLocked(session, player, Position{X: targetX, Y: targetY}, now)

	default:
		return nil, SkillUseResult{}, "unknown skill", false
	}
}

func (m *Manager) useHasteLocked(session *Session, player *PlayerState, now time.Time) (*Session, SkillUseResult, string, bool) {
	player.SkillCooldown[SkillHaste] = now.Add(HasteCooldown)
	player.HasteEndsAt = now.Add(HasteDuration)

	return session, SkillUseResult{
		Activation: SkillActivationSnapshot{
			GameID:     session.ID,
			PlayerID:   player.PlayerID,
			SkillID:    SkillHaste,
			ActiveMS:   HasteActiveMS,
			CooldownMS: HasteCooldownMS,
			Target:     player.Position,
			Players:    copyPlayersList(session),
		},
	}, "", true
}

func (m *Manager) useHealLocked(session *Session, player *PlayerState, now time.Time) (*Session, SkillUseResult, string, bool) {
	player.SkillCooldown[SkillHeal] = now.Add(HealCooldown)

	heals := make([]HealSnapshot, 0, 2)

	for _, target := range session.Players {
		if target.Team != player.Team {
			continue
		}

		if target.IsDead || target.CurrentHP == 0 {
			continue
		}

		before := target.CurrentHP
		after := target.CurrentHP + HealAmount

		if after > target.MaxHP {
			after = target.MaxHP
		}

		target.CurrentHP = after
		actualHeal := after - before

		if actualHeal == 0 {
			actualHeal = HealAmount
		}

		heals = append(heals, HealSnapshot{
			GameID:         session.ID,
			HealerPlayerID: player.PlayerID,
			TargetPlayerID: target.PlayerID,
			Amount:         actualHeal,
			CurrentHP:      target.CurrentHP,
			MaxHP:          target.MaxHP,
			Position:       target.Position,
			Players:        copyPlayersList(session),
		})
	}

	return session, SkillUseResult{
		Activation: SkillActivationSnapshot{
			GameID:     session.ID,
			PlayerID:   player.PlayerID,
			SkillID:    SkillHeal,
			ActiveMS:   0,
			CooldownMS: HealCooldownMS,
			Target:     player.Position,
			Players:    copyPlayersList(session),
		},
		Heals: heals,
	}, "", true
}

func (m *Manager) useMolotovLocked(session *Session, player *PlayerState, target Position, now time.Time) (*Session, SkillUseResult, string, bool) {
	player.SkillCooldown[SkillMolotov] = now.Add(MolotovCooldown)

	molotovID := atomic.AddUint64(&m.nextMolotovID, 1)

	session.Molotovs[molotovID] = &MolotovState{
		MolotovID:     molotovID,
		OwnerPlayerID: player.PlayerID,
		Position:      target,
		RadiusTiles:   MolotovRadiusTiles,
		CreatedAt:     now,
		ExpiresAt:     now.Add(MolotovDuration),
		NextTickAt:    now.Add(MolotovTickInterval),
	}

	molotov := &MolotovSnapshot{
		GameID:          session.ID,
		MolotovID:       molotovID,
		OwnerPlayerID:   player.PlayerID,
		Position:        target,
		RadiusTiles:     MolotovRadiusTiles,
		DurationSeconds: MolotovDurationSeconds,
		Players:         copyPlayersList(session),
	}

	return session, SkillUseResult{
		Activation: SkillActivationSnapshot{
			GameID:     session.ID,
			PlayerID:   player.PlayerID,
			SkillID:    SkillMolotov,
			ActiveMS:   uint32(MolotovDuration / time.Millisecond),
			CooldownMS: MolotovCooldownMS,
			Target:     target,
			Players:    copyPlayersList(session),
		},
		Molotov: molotov,
	}, "", true
}

func (m *Manager) ProcessMolotovTicks(now time.Time) []SkillDamageSnapshot {
	m.mu.Lock()
	defer m.mu.Unlock()

	damages := make([]SkillDamageSnapshot, 0)

	for _, session := range m.sessions {
		if session.Ended {
			continue
		}

		for molotovID, molotov := range session.Molotovs {
			if now.After(molotov.ExpiresAt) || now.Equal(molotov.ExpiresAt) {
				delete(session.Molotovs, molotovID)
				continue
			}

			if now.Before(molotov.NextTickAt) {
				continue
			}

			molotov.NextTickAt = molotov.NextTickAt.Add(MolotovTickInterval)

			for _, player := range session.Players {
				if player.IsDead || player.CurrentHP == 0 {
					continue
				}

				if distance(player.Position, molotov.Position) > molotov.RadiusTiles {
					continue
				}

				death, changedFlags := m.applyDamageLocked(session, player, MolotovDamagePerTick, now, molotov.OwnerPlayerID)

				damages = append(damages, SkillDamageSnapshot{
					GameID:         session.ID,
					SkillID:        SkillMolotov,
					SourcePlayerID: molotov.OwnerPlayerID,
					VictimPlayerID: player.PlayerID,
					Damage:         MolotovDamagePerTick,
					CurrentHP:      player.CurrentHP,
					MaxHP:          player.MaxHP,
					Position:       player.Position,
					Players:        copyPlayersList(session),
					Death:          death,
					ChangedFlags:   changedFlags,
				})
			}
		}
	}

	return damages
}

func (m *Manager) ProcessBulletHits(now time.Time) []BulletHitSnapshot {
	m.mu.Lock()
	defer m.mu.Unlock()

	hits := make([]BulletHitSnapshot, 0)

	for _, session := range m.sessions {
		if session.Ended {
			continue
		}

		for bulletID, bullet := range session.Bullets {
			if now.After(bullet.ExpiresAt) || now.Equal(bullet.ExpiresAt) {
				delete(session.Bullets, bulletID)
				continue
			}

			deltaSeconds := float32(now.Sub(bullet.LastUpdatedAt).Seconds())
			if deltaSeconds < 0 {
				deltaSeconds = 0
			}

			bullet.LastUpdatedAt = now
			bullet.Position.X += bullet.DirX * bullet.SpeedTilesPerSec * deltaSeconds
			bullet.Position.Y += bullet.DirY * bullet.SpeedTilesPerSec * deltaSeconds

			victim := m.findBulletVictimLocked(session, bullet)
			if victim == nil {
				continue
			}

			damage := randomBulletDamage()
			death, changedFlags := m.applyDamageLocked(session, victim, damage, now, bullet.OwnerPlayerID)

			hits = append(hits, BulletHitSnapshot{
				GameID:         session.ID,
				BulletID:       bullet.BulletID,
				OwnerPlayerID:  bullet.OwnerPlayerID,
				VictimPlayerID: victim.PlayerID,
				Damage:         damage,
				CurrentHP:      victim.CurrentHP,
				MaxHP:          victim.MaxHP,
				Position:       victim.Position,
				Players:        copyPlayersList(session),
				Death:          death,
				ChangedFlags:   changedFlags,
			})

			delete(session.Bullets, bulletID)
		}
	}

	return hits
}

func (m *Manager) applyDamageLocked(
	session *Session,
	victim *PlayerState,
	damage uint32,
	now time.Time,
	sourcePlayerID uint64,
) (*DeathSnapshot, []FlagSnapshot) {
	if damage >= victim.CurrentHP {
		victim.CurrentHP = 0

		if sourcePlayerID != 0 && sourcePlayerID != victim.PlayerID {
			if killer, ok := session.Players[sourcePlayerID]; ok {
				killer.MatchKills++
			}
		}

		victim.MatchDeaths++

		return m.markPlayerDeadLocked(session, victim, now)
	}

	victim.CurrentHP -= damage
	return nil, nil
}

func (m *Manager) markPlayerDeadLocked(session *Session, player *PlayerState, now time.Time) (*DeathSnapshot, []FlagSnapshot) {
	if player.IsDead {
		return nil, nil
	}

	player.IsDead = true
	player.RespawnAt = now.Add(RespawnDuration)
	player.HasteEndsAt = time.Time{}

	changedFlags := make([]FlagSnapshot, 0)

	for _, flag := range session.Flags {
		if flag.Status == FlagStatusCarried && flag.CarrierPlayerID == player.PlayerID {
			flag.Status = FlagStatusDropped
			flag.CarrierPlayerID = 0
			flag.Position = player.Position
			changedFlags = append(changedFlags, copyFlagSnapshot(flag))
		}
	}

	for bulletID, bullet := range session.Bullets {
		if bullet.OwnerPlayerID == player.PlayerID {
			delete(session.Bullets, bulletID)
		}
	}

	return &DeathSnapshot{
		GameID:         session.ID,
		PlayerID:       player.PlayerID,
		RespawnSeconds: RespawnDurationSeconds,
		Players:        copyPlayersList(session),
	}, changedFlags
}

func (m *Manager) findBulletVictimLocked(session *Session, bullet *BulletState) *PlayerState {
	for _, player := range session.Players {
		if player.PlayerID == bullet.OwnerPlayerID {
			continue
		}

		if player.Team == bullet.OwnerTeam {
			continue
		}

		if player.IsDead || player.CurrentHP == 0 {
			continue
		}

		if distance(player.Position, bullet.Position) <= BulletHitRadiusTiles {
			return player
		}
	}

	return nil
}

func (m *Manager) UpdatePlayerPosition(playerID uint64, x, y float32) (*Session, *PlayerState, []FlagSnapshot, *ScoreSnapshot, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	gameID, ok := m.playerToGame[playerID]
	if !ok {
		return nil, nil, nil, nil, false
	}

	session, ok := m.sessions[gameID]
	if !ok {
		return nil, nil, nil, nil, false
	}

	if session.Ended {
		return session, nil, nil, nil, false
	}

	state, ok := session.Players[playerID]
	if !ok {
		return nil, nil, nil, nil, false
	}

	if state.IsDead || state.CurrentHP == 0 {
		return session, copyPlayerState(state), nil, nil, true
	}

	state.Position = Position{X: x, Y: y}

	changedFlags, scoreUpdate := m.resolveFlagTouchesLocked(session, state)

	return session, copyPlayerState(state), changedFlags, scoreUpdate, true
}

func (m *Manager) SetPlayerAim(playerID uint64, aimX float32, aimY float32) (*Session, *PlayerState, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	gameID, ok := m.playerToGame[playerID]
	if !ok {
		return nil, nil, false
	}

	session, ok := m.sessions[gameID]
	if !ok {
		return nil, nil, false
	}

	if session.Ended {
		return session, nil, false
	}

	state, ok := session.Players[playerID]
	if !ok {
		return nil, nil, false
	}

	normalizedX, normalizedY := normalizeDirection(aimX, aimY)

	state.AimX = normalizedX
	state.AimY = normalizedY

	return session, copyPlayerState(state), true
}

func (m *Manager) SpawnBullet(playerID uint64, aimX float32, aimY float32) (*Session, BulletSnapshot, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	gameID, ok := m.playerToGame[playerID]
	if !ok {
		return nil, BulletSnapshot{}, false
	}

	session, ok := m.sessions[gameID]
	if !ok {
		return nil, BulletSnapshot{}, false
	}

	if session.Ended {
		return nil, BulletSnapshot{}, false
	}

	state, ok := session.Players[playerID]
	if !ok {
		return nil, BulletSnapshot{}, false
	}

	now := time.Now()

	if !state.LastShotAt.IsZero() && now.Sub(state.LastShotAt) < ShootCooldown {
		return nil, BulletSnapshot{}, false
	}

	if state.IsDead || state.CurrentHP == 0 {
		return nil, BulletSnapshot{}, false
	}

	state.LastShotAt = now

	normalizedX, normalizedY := normalizeDirection(aimX, aimY)

	state.AimX = normalizedX
	state.AimY = normalizedY

	bulletID := atomic.AddUint64(&m.nextBulletID, 1)

	spawnPosition := Position{
		X: state.Position.X + normalizedX*BulletSpawnOffsetTiles,
		Y: state.Position.Y + normalizedY*BulletSpawnOffsetTiles,
	}

	session.Bullets[bulletID] = &BulletState{
		BulletID:         bulletID,
		OwnerPlayerID:    state.PlayerID,
		OwnerTeam:        state.Team,
		Position:         spawnPosition,
		DirX:             normalizedX,
		DirY:             normalizedY,
		SpeedTilesPerSec: BulletSpeedTilesPerSecond,
		CreatedAt:        now,
		LastUpdatedAt:    now,
		ExpiresAt:        now.Add(time.Duration(BulletLifetimeSeconds * float32(time.Second))),
	}

	return session, BulletSnapshot{
		GameID:              session.ID,
		BulletID:            bulletID,
		OwnerPlayerID:       state.PlayerID,
		Position:            spawnPosition,
		DirX:                normalizedX,
		DirY:                normalizedY,
		SpeedTilesPerSecond: BulletSpeedTilesPerSecond,
		LifetimeSeconds:     BulletLifetimeSeconds,
	}, true
}

func (m *Manager) resolveFlagTouchesLocked(session *Session, player *PlayerState) ([]FlagSnapshot, *ScoreSnapshot) {
	changedFlags := make([]FlagSnapshot, 0, 2)

	if player.IsDead || player.CurrentHP == 0 {
		return changedFlags, nil
	}

	ownTeam := player.Team
	enemy := enemyTeam(ownTeam)

	ownFlag := session.Flags[ownTeam]
	enemyFlag := session.Flags[enemy]

	if ownFlag == nil || enemyFlag == nil {
		return changedFlags, nil
	}

	if ownFlag.Status == FlagStatusDropped && distance(player.Position, ownFlag.Position) <= FlagTouchRadius {
		ownFlag.Status = FlagStatusAtBase
		ownFlag.CarrierPlayerID = 0
		ownFlag.Position = ownFlag.BasePosition

		changedFlags = append(changedFlags, copyFlagSnapshot(ownFlag))
	}

	if enemyFlag.Status == FlagStatusCarried &&
		enemyFlag.CarrierPlayerID == player.PlayerID &&
		ownFlag.Status == FlagStatusAtBase &&
		distance(player.Position, ownFlag.BasePosition) <= FlagTouchRadius {

		session.Scores[ownTeam]++
		player.MatchCaptures++

		enemyFlag.Status = FlagStatusAtBase
		enemyFlag.CarrierPlayerID = 0
		enemyFlag.Position = enemyFlag.BasePosition

		changedFlags = append(changedFlags, copyFlagSnapshot(enemyFlag))

		scoreUpdate := &ScoreSnapshot{
			RedScore:  session.Scores[TeamRed],
			BlueScore: session.Scores[TeamBlue],
		}

		if session.Scores[ownTeam] >= MaxTeamScore {
			session.Ended = true
			session.EndReason = "score"
			session.WinningTeam = ownTeam
			session.Bullets = make(map[uint64]*BulletState)
			session.Molotovs = make(map[uint64]*MolotovState)
		}

		return changedFlags, scoreUpdate
	}

	if enemyFlag.Status != FlagStatusCarried && distance(player.Position, enemyFlag.Position) <= FlagTouchRadius {
		enemyFlag.Status = FlagStatusCarried
		enemyFlag.CarrierPlayerID = player.PlayerID
		enemyFlag.Position = player.Position

		changedFlags = append(changedFlags, copyFlagSnapshot(enemyFlag))
	}

	return changedFlags, nil
}

func (m *Manager) UpdatePlayerHealthDelta(playerID uint64, deltaHP int32) (*Session, HealthSnapshot, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	gameID, ok := m.playerToGame[playerID]
	if !ok {
		return nil, HealthSnapshot{}, false
	}

	session, ok := m.sessions[gameID]
	if !ok {
		return nil, HealthSnapshot{}, false
	}

	if session.Ended {
		return nil, HealthSnapshot{}, false
	}

	state, ok := session.Players[playerID]
	if !ok {
		return nil, HealthSnapshot{}, false
	}

	nextHP := int64(state.CurrentHP) + int64(deltaHP)

	if nextHP < 0 {
		nextHP = 0
	}

	if nextHP > int64(state.MaxHP) {
		nextHP = int64(state.MaxHP)
	}

	state.CurrentHP = uint32(nextHP)

	return session, HealthSnapshot{
		PlayerID:  state.PlayerID,
		CurrentHP: state.CurrentHP,
		MaxHP:     state.MaxHP,
	}, true
}

func (m *Manager) RemovePlayer(playerID uint64) (gameID uint64, peers []uint64, removed bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	gameID, ok := m.playerToGame[playerID]
	if !ok {
		return 0, nil, false
	}

	delete(m.playerToGame, playerID)

	session, ok := m.sessions[gameID]
	if !ok {
		return gameID, nil, true
	}

	player, hadPlayerState := session.Players[playerID]
	delete(session.Players, playerID)

	if hadPlayerState {
		for _, flag := range session.Flags {
			if flag.Status == FlagStatusCarried && flag.CarrierPlayerID == player.PlayerID {
				flag.Status = FlagStatusDropped
				flag.CarrierPlayerID = 0
				flag.Position = player.Position
			}
		}

		for bulletID, bullet := range session.Bullets {
			if bullet.OwnerPlayerID == player.PlayerID {
				delete(session.Bullets, bulletID)
			}
		}
	}

	peers = make([]uint64, 0, len(session.AllPlayers)-1)
	remainingPlayers := make([]uint64, 0, len(session.AllPlayers)-1)

	for _, pid := range session.AllPlayers {
		if pid == playerID {
			continue
		}

		remainingPlayers = append(remainingPlayers, pid)

		if _, stillMapped := m.playerToGame[pid]; stillMapped {
			peers = append(peers, pid)
		}
	}

	session.AllPlayers = remainingPlayers

	team1 := make([]uint64, 0, len(session.Team1))
	for _, pid := range session.Team1 {
		if pid != playerID {
			team1 = append(team1, pid)
		}
	}
	session.Team1 = team1

	team2 := make([]uint64, 0, len(session.Team2))
	for _, pid := range session.Team2 {
		if pid != playerID {
			team2 = append(team2, pid)
		}
	}
	session.Team2 = team2

	if len(session.AllPlayers) == 0 {
		delete(m.sessions, gameID)
	}

	return gameID, peers, true
}
