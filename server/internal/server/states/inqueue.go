package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"server/internal/server/queue"
	"server/pkg/packets"
	"time"
)

type InQueue struct {
	client  server.ClientInterfacer
	logger  *log.Logger
	queries *db.Queries
	dbCtx   context.Context
}

func (s *InQueue) Name() string { return "InQueue" }

func (s *InQueue) SetClient(client server.ClientInterfacer) {
	s.client = client
	prefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), s.Name())
	s.logger = log.New(log.Writer(), prefix, log.LstdFlags)
	s.queries = client.DbTx().Queries
	s.dbCtx = client.DbTx().Ctx
}

func (s *InQueue) OnEnter() {
	if s.client.UserDbId() == 0 {
		s.client.SocketSend(packets.NewDenyResponse("must be logged in to enter queue"))
		s.client.SetState(&Connected{})
		return
	}

	user, err := s.queries.GetUserByID(s.dbCtx, int64(s.client.UserDbId()))
	if err != nil {
		s.logger.Printf("failed to load user stats before entering queue: %v", err)
		s.client.SocketSend(packets.NewDenyResponse("failed to enter queue"))
		s.client.SetState(&Connected{})
		return
	}

	skill := queue.ComputeSkill(
		user.Kills.Int64,
		user.Deaths.Int64,
		user.FlagCaptures.Int64,
		user.Wins.Int64,
		user.Losses.Int64,
	)

	joined := s.client.Hub().Queue.EnqueueSolo(s.client.Id(), user.Nickname, skill, time.Now())
	if !joined {
		s.logger.Printf("client %d is already in the queue", s.client.Id())
	}

	s.client.Hub().WakeQueue()
}

func (s *InQueue) HandleMessage(senderId uint64, message packets.Msg) {
	switch m := message.(type) {
	case *packets.Packet_Chat:
		if handleReportChat(s.client, s.logger, senderId, m) {
			return
		}
		s.client.SocketSend(packets.NewDenyResponse("chat message not allowed while in queue"))
	case *packets.Packet_RequestLeaveQueue:
		_ = m
		log.Printf("Client %d requested to leave queue", s.client.Id())
		removed := s.client.Hub().Queue.RemovePlayer(s.client.Id())
		if removed {
			s.client.SocketSend(packets.NewQueueLeft())
			s.client.Hub().WakeQueue()
		}
		s.client.SetState(&Connected{})
	default:
		s.client.SocketSend(packets.NewDenyResponse("message not allowed while in queue"))
	}
}

func (s *InQueue) OnExit() {}
