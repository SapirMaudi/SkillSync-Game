package server

import (
	"context"
	"database/sql"
	_ "embed"
	"fmt"
	"log"
	"net/http"
	"server/internal/server/db"
	"server/internal/server/game"
	"server/internal/server/objects"
	"server/internal/server/queue"
	"server/pkg/packets"
	"time"

	_ "modernc.org/sqlite"
)

//go:embed db/config/schema.sql
var schemeGenSql string

type DbTx struct {
	Ctx     context.Context
	Queries *db.Queries
}

func (h *Hub) NewDbTx() *DbTx {
	return &DbTx{
		Ctx:     context.Background(),
		Queries: db.New(h.dbPool),
	}
}

type ClientStateHandler interface {
	Name() string
	SetClient(client ClientInterfacer)
	OnEnter()
	HandleMessage(senderId uint64, message packets.Msg)
	OnExit()
}

type ClientInterfacer interface {
	Initialize(id uint64)
	SetState(state ClientStateHandler)
	EnterInGameState()
	Id() uint64
	ProcessMesssage(senderId uint64, message packets.Msg)
	ReadPump()
	WritePump()
	SocketSend(message packets.Msg)
	SocketSendAs(message packets.Msg, senderId uint64)
	PassToPeer(message packets.Msg, peerId uint64)
	Broadcast(message packets.Msg)
	DbTx() *DbTx
	SetUserDbId(userDbId uint64)
	UserDbId() uint64
	Close(reason string)
	Hub() *Hub
	StateName() string
}

type Hub struct {
	Clients        *objects.SharedCollection[ClientInterfacer]
	BroadcastChan  chan *packets.Packet
	RegisterChan   chan ClientInterfacer
	UnregisterChan chan ClientInterfacer
	QueueWakeChan  chan struct{}
	dbPool         *sql.DB
	Queue          *queue.Manager
	Games          *game.Manager
}

func NewHub() *Hub {
	dbPool, err := sql.Open("sqlite", "db.sqlite")
	if err != nil {
		log.Fatal("failed to open database:", err)
	}

	return &Hub{
		Clients:        objects.NewSharedCollection[ClientInterfacer](),
		BroadcastChan:  make(chan *packets.Packet),
		RegisterChan:   make(chan ClientInterfacer),
		UnregisterChan: make(chan ClientInterfacer),
		QueueWakeChan:  make(chan struct{}, 1),
		dbPool:         dbPool,
		Queue:          queue.New(),
		Games:          game.New(),
	}
}

func (h *Hub) WakeQueue() {
	select {
	case h.QueueWakeChan <- struct{}{}:
	default:
	}
}

func (h *Hub) Run() {
	log.Println("Init DB...")
	if _, err := h.dbPool.ExecContext(context.Background(), schemeGenSql); err != nil {
		log.Fatal("failed to initialize database:", err)
	}

	queueTicker := time.NewTicker(500 * time.Millisecond)
	defer queueTicker.Stop()

	gameTimerTicker := time.NewTicker(1 * time.Second)
	defer gameTimerTicker.Stop()

	bulletTicker := time.NewTicker(20 * time.Millisecond)
	defer bulletTicker.Stop()

	molotovTicker := time.NewTicker(100 * time.Millisecond)
	defer molotovTicker.Stop()

	respawnTicker := time.NewTicker(100 * time.Millisecond)
	defer respawnTicker.Stop()

	endGameTicker := time.NewTicker(500 * time.Millisecond)
	defer endGameTicker.Stop()

	log.Println("server is ready to accept clients...")

	for {
		select {
		case client := <-h.RegisterChan:
			client.Initialize(h.Clients.Add(client))

		case client := <-h.UnregisterChan:
			h.Queue.RemovePlayer(client.Id())

			gameID, peers, removed := h.Games.RemovePlayer(client.Id())
			if removed {
				for _, peerID := range peers {
					peer, ok := h.Clients.Get(peerID)
					if !ok {
						continue
					}

					peer.SocketSend(packets.NewDespawnPlayer(gameID, client.Id()))
				}
			}

			h.Clients.Remove(client.Id())
			h.WakeQueue()

		case packet := <-h.BroadcastChan:
			h.Clients.ForEach(func(clientId uint64, client ClientInterfacer) {
				if clientId != packet.SenderId {
					client.ProcessMesssage(packet.SenderId, packet.Msg)
				}
			})

		case <-h.QueueWakeChan:
			h.processQueue()

		case <-queueTicker.C:
			h.processQueue()

		case <-gameTimerTicker.C:
			h.broadcastGameTimers()

		case <-bulletTicker.C:
			h.processBulletHits()

		case <-molotovTicker.C:
			h.processMolotovTicks()

		case <-respawnTicker.C:
			h.processRespawns()

		case <-endGameTicker.C:
			h.processEndedGames()
		}
	}
}

func (h *Hub) processEndedGames() {
	endedMatches := h.Games.ProcessEndedGames(time.Now())

	for _, ended := range endedMatches {
		results := make([]*packets.MatchPlayerResultMessage, 0, len(ended.Results))

		for _, result := range ended.Results {
			nickname := fmt.Sprintf("P%d", result.PlayerID)
			userDbID := uint64(0)

			peer, ok := h.Clients.Get(result.PlayerID)
			if ok {
				userDbID = peer.UserDbId()
			}

			if userDbID != 0 {
				user, err := h.NewDbTx().Queries.GetUserByID(context.Background(), int64(userDbID))
				if err == nil {
					nickname = user.Nickname
				}
			}

			results = append(results, packets.NewMatchPlayerResult(
				result.PlayerID,
				nickname,
				result.Team,
				result.Kills,
				result.Deaths,
				result.Captures,
				result.Won,
				result.Lost,
			))

			if userDbID != 0 {
				h.updateUserMatchStats(
					userDbID,
					result.Kills,
					result.Deaths,
					result.Captures,
					result.Won,
					result.Lost,
				)
			}
		}

		message := packets.NewMatchEnded(
			ended.GameID,
			ended.RedScore,
			ended.BlueScore,
			ended.WinningTeam,
			ended.Reason,
			results,
		)

		for _, playerID := range ended.Players {
			peer, ok := h.Clients.Get(playerID)
			if !ok {
				continue
			}

			peer.SocketSend(message)
		}
	}
}

func (h *Hub) updateUserMatchStats(
	userDbID uint64,
	kills uint32,
	deaths uint32,
	captures uint32,
	won bool,
	lost bool,
) {
	winDelta := 0
	lossDelta := 0

	if won {
		winDelta = 1
	}

	if lost {
		lossDelta = 1
	}

	_, err := h.dbPool.ExecContext(
		context.Background(),
		`
		UPDATE users
		SET
			kills = kills + ?,
			deaths = deaths + ?,
			flag_captures = flag_captures + ?,
			wins = wins + ?,
			losses = losses + ?
		WHERE player_id = ?
		`,
		kills,
		deaths,
		captures,
		winDelta,
		lossDelta,
		userDbID,
	)

	if err != nil {
		log.Printf("failed to update match stats for user %d: %v", userDbID, err)
	}
}

func (h *Hub) processRespawns() {
	respawns := h.Games.ProcessRespawns(time.Now())

	for _, respawn := range respawns {
		message := packets.NewPlayerRespawned(
			respawn.GameID,
			respawn.PlayerID,
			respawn.Position.X,
			respawn.Position.Y,
			respawn.CurrentHP,
			respawn.MaxHP,
		)

		for _, playerID := range respawn.Players {
			peer, ok := h.Clients.Get(playerID)
			if !ok {
				continue
			}

			peer.SocketSend(message)
		}
	}
}

func (h *Hub) processMolotovTicks() {
	damages := h.Games.ProcessMolotovTicks(time.Now())

	for _, damage := range damages {
		damageMessage := packets.NewSkillDamage(
			damage.GameID,
			damage.SkillID,
			damage.SourcePlayerID,
			damage.VictimPlayerID,
			damage.Damage,
			damage.CurrentHP,
			damage.MaxHP,
			damage.Position.X,
			damage.Position.Y,
		)

		for _, playerID := range damage.Players {
			peer, ok := h.Clients.Get(playerID)
			if !ok {
				continue
			}

			peer.SocketSend(damageMessage)
		}

		for _, flag := range damage.ChangedFlags {
			flagMessage := packets.NewFlagStateUpdated(
				damage.GameID,
				flag.Team,
				flag.Position.X,
				flag.Position.Y,
				flag.Status,
				flag.CarrierPlayerID,
			)

			for _, playerID := range damage.Players {
				peer, ok := h.Clients.Get(playerID)
				if !ok {
					continue
				}

				peer.SocketSend(flagMessage)
			}
		}

		if damage.Death != nil {
			h.broadcastDeath(damage.Death)
		}
	}
}

func (h *Hub) processBulletHits() {
	hits := h.Games.ProcessBulletHits(time.Now())

	for _, hit := range hits {
		hitMessage := packets.NewBulletHit(
			hit.GameID,
			hit.BulletID,
			hit.OwnerPlayerID,
			hit.VictimPlayerID,
			hit.Damage,
			hit.CurrentHP,
			hit.MaxHP,
			hit.Position.X,
			hit.Position.Y,
		)

		for _, playerID := range hit.Players {
			peer, ok := h.Clients.Get(playerID)
			if !ok {
				continue
			}

			peer.SocketSend(hitMessage)
		}

		for _, flag := range hit.ChangedFlags {
			flagMessage := packets.NewFlagStateUpdated(
				hit.GameID,
				flag.Team,
				flag.Position.X,
				flag.Position.Y,
				flag.Status,
				flag.CarrierPlayerID,
			)

			for _, playerID := range hit.Players {
				peer, ok := h.Clients.Get(playerID)
				if !ok {
					continue
				}

				peer.SocketSend(flagMessage)
			}
		}

		if hit.Death != nil {
			h.broadcastDeath(hit.Death)
		}
	}
}

func (h *Hub) broadcastDeath(death *game.DeathSnapshot) {
	if death == nil {
		return
	}

	message := packets.NewPlayerDied(
		death.GameID,
		death.PlayerID,
		death.RespawnSeconds,
	)

	for _, playerID := range death.Players {
		peer, ok := h.Clients.Get(playerID)
		if !ok {
			continue
		}

		peer.SocketSend(message)
	}
}

func (h *Hub) broadcastGameTimers() {
	now := time.Now()
	snapshots := h.Games.TimerSnapshots(now)

	for _, snapshot := range snapshots {
		message := packets.NewGameTimeUpdated(
			snapshot.GameID,
			snapshot.RemainingSeconds,
			snapshot.DurationSeconds,
			snapshot.IsRunning,
		)

		for _, playerID := range snapshot.Players {
			peer, ok := h.Clients.Get(playerID)
			if !ok {
				continue
			}

			peer.SocketSend(message)
		}
	}
}

func (h *Hub) processQueue() {
	matches := h.Queue.Matchmake(time.Now())
	notifications := h.Queue.Notifications()

	for _, notification := range notifications {
		peer, ok := h.Clients.Get(notification.PlayerID)
		if !ok {
			continue
		}

		peer.SocketSend(packets.NewQueueJoined(notification.Position, notification.Size))
	}

	for _, queuedMatch := range matches {
		players := [4]uint64{
			queuedMatch.Team1[0],
			queuedMatch.Team1[1],
			queuedMatch.Team2[0],
			queuedMatch.Team2[1],
		}

		session := h.Games.Create2v2(players)

		for _, pid := range session.AllPlayers {
			peer, ok := h.Clients.Get(pid)
			if !ok {
				continue
			}

			team := uint32(2)
			teamIDs := session.Team2
			enemyIDs := session.Team1

			if pid == session.Team1[0] || pid == session.Team1[1] {
				team = 1
				teamIDs = session.Team1
				enemyIDs = session.Team2
			}

			peer.SocketSend(packets.NewMatchFound(session.ID, team, teamIDs, enemyIDs))
			peer.EnterInGameState()
		}
	}
}

func (h *Hub) Serve(
	getNewClient func(*Hub, http.ResponseWriter, *http.Request) (ClientInterfacer, error),
	writer http.ResponseWriter,
	request *http.Request,
) {
	log.Println("new client is connecting", request.RemoteAddr)

	client, err := getNewClient(h, writer, request)
	if err != nil {
		log.Println("error while creating new client:", err)
		return
	}

	h.RegisterChan <- client

	go client.WritePump()
	go client.ReadPump()
}
