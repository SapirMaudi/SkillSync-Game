package clients

import (
	"fmt"
	"log"
	"net/http"
	"server/internal/server"
	"server/internal/server/states"
	"server/pkg/packets"
	"sync"
	"sync/atomic"

	"github.com/gorilla/websocket"
	"google.golang.org/protobuf/proto"
)

type WebSocketClient struct {
	id       uint64
	conn     *websocket.Conn
	hub      *server.Hub
	sendChan chan *packets.Packet
	state    server.ClientStateHandler
	logger   *log.Logger
	dbTx     *server.DbTx
	UserIdDb uint64

	closeOnce sync.Once
	closed    atomic.Bool
}

func NewWebSocketClient(hub *server.Hub, writer http.ResponseWriter, request *http.Request) (server.ClientInterfacer, error) {
	upgrader := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin: func(r *http.Request) bool {
			return true
		},
	}

	conn, err := upgrader.Upgrade(writer, request, nil)
	if err != nil {
		return nil, err
	}

	c := &WebSocketClient{
		hub:      hub,
		conn:     conn,
		sendChan: make(chan *packets.Packet, 256),
		logger:   log.New(log.Writer(), "unknown client: ", log.LstdFlags),
		dbTx:     hub.NewDbTx(),
	}

	return c, nil
}

func (c *WebSocketClient) Id() uint64 {
	return c.id
}

func (c *WebSocketClient) SetState(state server.ClientStateHandler) {
	prevStateName := "None"
	if c.state != nil {
		prevStateName = c.state.Name()
		c.state.OnExit()
	}

	newStateName := "None"
	if state != nil {
		newStateName = state.Name()
	}

	c.logger.Printf("Changing state from %s to %s", prevStateName, newStateName)
	c.state = state
	if c.state != nil {
		c.state.SetClient(c)
		c.state.OnEnter()
	}
}

func (c *WebSocketClient) EnterInGameState() {
	c.SetState(&states.InGame{})
}

func (c *WebSocketClient) Initialize(id uint64) {
	c.id = id
	c.logger.SetPrefix(fmt.Sprintf("Client %d: ", c.id))
	c.SetState(&states.Connected{})
}

func (c *WebSocketClient) ProcessMesssage(senderId uint64, message packets.Msg) {
	if c.state == nil {
		return
	}
	c.state.HandleMessage(senderId, message)
}

func (c *WebSocketClient) ReadPump() {
	defer func() {
		c.logger.Println("closing connection, read pump exited")
		c.Close("Read Pump Closed")
	}()

	for {
		_, data, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				c.logger.Printf("error: %v", err)
			}
			break
		}

		packet := &packets.Packet{}
		err = proto.Unmarshal(data, packet)
		if err != nil {
			c.logger.Printf("failed to unmarshal packet: %v", err)
			continue
		}

		if packet.SenderId == 0 {
			packet.SenderId = c.id
		}

		c.ProcessMesssage(c.id, packet.Msg)
	}
}

func (c *WebSocketClient) WritePump() {
	defer func() {
		c.logger.Println("closing connection, write pump exited")
		c.Close("Write Pump Closed")
	}()

	for packet := range c.sendChan {
		writer, err := c.conn.NextWriter(websocket.BinaryMessage)
		if err != nil {
			c.logger.Printf("failed to get next writer: %v", err)
			return
		}

		data, err := proto.Marshal(packet)
		if err != nil {
			c.logger.Printf("failed to marshal packet: %v", err)
			continue
		}

		_, err = writer.Write(data)
		if err != nil {
			c.logger.Printf("failed to write message: %v", err)
			continue
		}

		writer.Write([]byte{'\n'})

		if err := writer.Close(); err != nil {
			c.logger.Printf("failed to close writer: %v", err)
			continue
		}
	}
}

func (c *WebSocketClient) SocketSend(message packets.Msg) {
	c.SocketSendAs(message, c.id)
}

func (c *WebSocketClient) SocketSendAs(message packets.Msg, senderId uint64) {
	if c.closed.Load() {
		return
	}

	defer func() {
		_ = recover()
	}()

	select {
	case c.sendChan <- &packets.Packet{SenderId: senderId, Msg: message}:
	default:
		c.logger.Println("send channel is full, dropping message")
	}
}

func (c *WebSocketClient) PassToPeer(message packets.Msg, peerId uint64) {
	if peer, exists := c.hub.Clients.Get(peerId); exists {
		peer.ProcessMesssage(c.id, message)
	}
}

func (c *WebSocketClient) Broadcast(message packets.Msg) {
	c.hub.BroadcastChan <- &packets.Packet{SenderId: c.id, Msg: message}
}

func (c *WebSocketClient) DbTx() *server.DbTx {
	return c.dbTx
}

func (c *WebSocketClient) SetUserDbId(userDbId uint64) {
	c.UserIdDb = userDbId
}

func (c *WebSocketClient) UserDbId() uint64 {
	return c.UserIdDb
}

func (c *WebSocketClient) Close(reason string) {
	c.closeOnce.Do(func() {
		c.logger.Println("closing client connection:", reason)
		c.closed.Store(true)

		c.SetState(nil)
		c.hub.UnregisterChan <- c
		close(c.sendChan)
		_ = c.conn.Close()
	})
}

func (c *WebSocketClient) Hub() *server.Hub {
	return c.hub
}

func (c *WebSocketClient) StateName() string {
	if c.state == nil {
		return "None"
	}
	return c.state.Name()
}
