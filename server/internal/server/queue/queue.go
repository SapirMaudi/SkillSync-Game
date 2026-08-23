package queue

import (
	"fmt"
	"log"
	"math"
	"sync"
	"time"
)

var (
	WeightKills        = 1.0
	WeightDeaths       = -1.0
	WeightFlagCaptures = 5.0
	WeightWins         = 10.0
	WeightLosses       = -3.0
)

var (
	DefaultUniformityMax  = 25.0
	DefaultUniformityHard = 60.0
	DefaultRelaxAfter     = 20 * time.Second
)

var (
	DefaultMatchQualityAlpha = 0.7
)

type SoloPlayer struct {
	PlayerID uint64
	Name     string
	Skill    float64
	JoinTime time.Time
}

type Team struct {
	Members   [2]SoloPlayer
	TeamSkill float64
}

type Notification struct {
	PlayerID uint64
	Position uint32
	Size     uint32
}

type Match struct {
	Team1 [2]uint64
	Team2 [2]uint64
}

type DetailedMatch struct {
	Team1        Team
	Team2        Team
	Fairness     float64
	Uniformity   float64
	MatchQuality float64
	Alpha        float64
}

type Snapshot struct {
	Solos []SoloPlayer
	Teams []Team
}

type entryKind int

const (
	entrySolo entryKind = iota
	entryTeam
)

type entry struct {
	kind entryKind
	solo SoloPlayer
	team Team
}

type Manager struct {
	mu      sync.Mutex
	entries []entry
}

func New() *Manager {
	return &Manager{entries: make([]entry, 0, 32)}
}

func ComputeSkill(kills, deaths, flagCaptures, wins, losses int64) float64 {
	skill := float64(kills)*WeightKills +
		float64(deaths)*WeightDeaths +
		float64(flagCaptures)*WeightFlagCaptures +
		float64(wins)*WeightWins +
		float64(losses)*WeightLosses

	if skill < 0 {
		return 0
	}

	return skill
}

func (m *Manager) EnqueueSolo(playerID uint64, name string, skill float64, joinTime time.Time) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.containsPlayerLocked(playerID) {
		return false
	}

	m.insertEntryLocked(entry{
		kind: entrySolo,
		solo: SoloPlayer{
			PlayerID: playerID,
			Name:     name,
			Skill:    skill,
			JoinTime: joinTime,
		},
	})
	return true
}

func (m *Manager) RemovePlayer(playerID uint64) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, current := range m.entries {
		switch current.kind {
		case entrySolo:
			if current.solo.PlayerID == playerID {
				m.entries = append(m.entries[:i], m.entries[i+1:]...)
				return true
			}
		case entryTeam:
			first := current.team.Members[0]
			second := current.team.Members[1]
			if first.PlayerID == playerID || second.PlayerID == playerID {
				m.entries = append(m.entries[:i], m.entries[i+1:]...)

				survivor := first
				if first.PlayerID == playerID {
					survivor = second
				}

				m.insertEntryLocked(entry{
					kind: entrySolo,
					solo: survivor,
				})
				return true
			}
		}
	}

	return false
}

func (m *Manager) Notifications() []Notification {
	m.mu.Lock()
	defer m.mu.Unlock()

	notifications := make([]Notification, 0, len(m.entries)*2)
	size := uint32(len(m.entries))
	soloPosition := uint32(0)

	for _, current := range m.entries {
		switch current.kind {
		case entrySolo:
			soloPosition++
			notifications = append(notifications, Notification{
				PlayerID: current.solo.PlayerID,
				Position: soloPosition,
				Size:     size,
			})
		case entryTeam:
			for _, member := range current.team.Members {
				notifications = append(notifications, Notification{
					PlayerID: member.PlayerID,
					Position: 0,
					Size:     size,
				})
			}
		}
	}

	return notifications
}

func (m *Manager) Matchmake(now time.Time) []Match {
	m.mu.Lock()
	defer m.mu.Unlock()

	matches := make([]Match, 0, 4)

	for {
		if m.formBestTeamLocked(now) {
			continue
		}

		match, ok := m.formBestMatchLocked()
		if ok {
			matches = append(matches, match)
			continue
		}

		break
	}

	return matches
}

func (m *Manager) MatchmakeDetailed(now time.Time) []DetailedMatch {
	m.mu.Lock()
	defer m.mu.Unlock()

	matches := make([]DetailedMatch, 0, 4)

	for {
		if m.formBestTeamLocked(now) {
			continue
		}

		match, ok := m.formBestDetailedMatchLocked()
		if ok {
			matches = append(matches, match)
			continue
		}

		break
	}

	return matches
}

func (m *Manager) Snapshot() Snapshot {
	m.mu.Lock()
	defer m.mu.Unlock()

	snapshot := Snapshot{
		Solos: make([]SoloPlayer, 0),
		Teams: make([]Team, 0),
	}

	for _, current := range m.entries {
		switch current.kind {
		case entrySolo:
			snapshot.Solos = append(snapshot.Solos, current.solo)
		case entryTeam:
			snapshot.Teams = append(snapshot.Teams, current.team)
		}
	}

	return snapshot
}

func TeamPairGap(team Team) float64 {
	return math.Abs(team.Members[0].Skill - team.Members[1].Skill)
}

func MatchFairness(left Team, right Team) float64 {
	return computeFairness(left, right)
}

func MatchUniformity(left Team, right Team) float64 {
	return computeMatchUniformity(left, right)
}

func MatchQuality(fairness, uniformity, alpha float64) float64 {
	return computeMatchQuality(fairness, uniformity, alpha)
}

func CanPlayersPair(left, right SoloPlayer, now time.Time) bool {
	gap := math.Abs(left.Skill - right.Skill)
	allowedGap := math.Max(AllowedGap(left, now), AllowedGap(right, now))
	return gap <= allowedGap
}

func AllowedGap(player SoloPlayer, now time.Time) float64 {
	if now.Sub(player.JoinTime) >= DefaultRelaxAfter {
		return DefaultUniformityHard
	}
	return DefaultUniformityMax
}

func (m *Manager) containsPlayerLocked(playerID uint64) bool {
	for _, current := range m.entries {
		switch current.kind {
		case entrySolo:
			if current.solo.PlayerID == playerID {
				return true
			}
		case entryTeam:
			if current.team.Members[0].PlayerID == playerID || current.team.Members[1].PlayerID == playerID {
				return true
			}
		}
	}
	return false
}

func (m *Manager) formBestTeamLocked(now time.Time) bool {
	type candidate struct {
		leftIndex  int
		rightIndex int
		gap        float64
		oldestJoin time.Time
		lowID      uint64
		highID     uint64
	}

	best := candidate{leftIndex: -1, rightIndex: -1, gap: math.MaxFloat64}

	for i := 0; i < len(m.entries); i++ {
		if m.entries[i].kind != entrySolo {
			continue
		}

		for j := i + 1; j < len(m.entries); j++ {
			if m.entries[j].kind != entrySolo {
				continue
			}

			left := m.entries[i].solo
			right := m.entries[j].solo
			gap := math.Abs(left.Skill - right.Skill)
			allowedGap := math.Max(m.allowedGapLocked(left, now), m.allowedGapLocked(right, now))
			if gap > allowedGap {
				continue
			}

			oldestJoin := minTime(left.JoinTime, right.JoinTime)
			lowID := minUint64(left.PlayerID, right.PlayerID)
			highID := maxUint64(left.PlayerID, right.PlayerID)

			if best.leftIndex == -1 ||
				gap < best.gap ||
				(gap == best.gap && oldestJoin.Before(best.oldestJoin)) ||
				(gap == best.gap && oldestJoin.Equal(best.oldestJoin) && lowID < best.lowID) ||
				(gap == best.gap && oldestJoin.Equal(best.oldestJoin) && lowID == best.lowID && highID < best.highID) {
				best = candidate{
					leftIndex:  i,
					rightIndex: j,
					gap:        gap,
					oldestJoin: oldestJoin,
					lowID:      lowID,
					highID:     highID,
				}
			}
		}
	}

	if best.leftIndex == -1 {
		return false
	}

	left := m.entries[best.leftIndex].solo
	right := m.entries[best.rightIndex].solo
	team := Team{
		Members:   [2]SoloPlayer{left, right},
		TeamSkill: computeTeamSkill(left, right),
	}

	log.Printf(
		"[QUEUE] team formed: %s + %s | pair_gap(uniformity)=%.2f | team_skill=%.2f",
		playerLogString(left),
		playerLogString(right),
		best.gap,
		team.TeamSkill,
	)

	m.removeTwoEntriesLocked(best.leftIndex, best.rightIndex)
	m.insertEntryLocked(entry{kind: entryTeam, team: team})
	return true
}

func (m *Manager) formBestMatchLocked() (Match, bool) {
	type candidate struct {
		leftIndex    int
		rightIndex   int
		fairness     float64
		uniformity   float64
		matchQuality float64
		oldestJoin   time.Time
		lowID        uint64
		highID       uint64
	}

	best := candidate{
		leftIndex:    -1,
		rightIndex:   -1,
		matchQuality: math.MaxFloat64,
	}

	for i := 0; i < len(m.entries); i++ {
		if m.entries[i].kind != entryTeam {
			continue
		}

		for j := i + 1; j < len(m.entries); j++ {
			if m.entries[j].kind != entryTeam {
				continue
			}

			left := m.entries[i].team
			right := m.entries[j].team

			fairness := computeFairness(left, right)
			uniformity := computeMatchUniformity(left, right)
			matchQuality := computeMatchQuality(fairness, uniformity, DefaultMatchQualityAlpha)

			oldestJoin := minTime(teamJoinTime(left), teamJoinTime(right))
			leftMinID := minUint64(left.Members[0].PlayerID, left.Members[1].PlayerID)
			rightMinID := minUint64(right.Members[0].PlayerID, right.Members[1].PlayerID)
			lowID := minUint64(leftMinID, rightMinID)
			highID := maxUint64(leftMinID, rightMinID)

			if best.leftIndex == -1 ||
				matchQuality < best.matchQuality ||
				(matchQuality == best.matchQuality && oldestJoin.Before(best.oldestJoin)) ||
				(matchQuality == best.matchQuality && oldestJoin.Equal(best.oldestJoin) && lowID < best.lowID) ||
				(matchQuality == best.matchQuality && oldestJoin.Equal(best.oldestJoin) && lowID == best.lowID && highID < best.highID) {
				best = candidate{
					leftIndex:    i,
					rightIndex:   j,
					fairness:     fairness,
					uniformity:   uniformity,
					matchQuality: matchQuality,
					oldestJoin:   oldestJoin,
					lowID:        lowID,
					highID:       highID,
				}
			}
		}
	}

	if best.leftIndex == -1 {
		return Match{}, false
	}

	left := m.entries[best.leftIndex].team
	right := m.entries[best.rightIndex].team
	match := Match{
		Team1: [2]uint64{left.Members[0].PlayerID, left.Members[1].PlayerID},
		Team2: [2]uint64{right.Members[0].PlayerID, right.Members[1].PlayerID},
	}

	log.Printf(
		"[QUEUE] match formed: TEAM1=%s vs TEAM2=%s | fairness=%.2f | match_uniformity=%.2f | alpha=%.2f | quality=%.2f",
		teamLogString(left),
		teamLogString(right),
		best.fairness,
		best.uniformity,
		DefaultMatchQualityAlpha,
		best.matchQuality,
	)

	m.removeTwoEntriesLocked(best.leftIndex, best.rightIndex)
	return match, true
}

func (m *Manager) formBestDetailedMatchLocked() (DetailedMatch, bool) {
	type candidate struct {
		leftIndex    int
		rightIndex   int
		fairness     float64
		uniformity   float64
		matchQuality float64
		oldestJoin   time.Time
		lowID        uint64
		highID       uint64
	}

	best := candidate{
		leftIndex:    -1,
		rightIndex:   -1,
		matchQuality: math.MaxFloat64,
	}

	for i := 0; i < len(m.entries); i++ {
		if m.entries[i].kind != entryTeam {
			continue
		}

		for j := i + 1; j < len(m.entries); j++ {
			if m.entries[j].kind != entryTeam {
				continue
			}

			left := m.entries[i].team
			right := m.entries[j].team

			fairness := computeFairness(left, right)
			uniformity := computeMatchUniformity(left, right)
			matchQuality := computeMatchQuality(fairness, uniformity, DefaultMatchQualityAlpha)

			oldestJoin := minTime(teamJoinTime(left), teamJoinTime(right))
			leftMinID := minUint64(left.Members[0].PlayerID, left.Members[1].PlayerID)
			rightMinID := minUint64(right.Members[0].PlayerID, right.Members[1].PlayerID)
			lowID := minUint64(leftMinID, rightMinID)
			highID := maxUint64(leftMinID, rightMinID)

			if best.leftIndex == -1 ||
				matchQuality < best.matchQuality ||
				(matchQuality == best.matchQuality && oldestJoin.Before(best.oldestJoin)) ||
				(matchQuality == best.matchQuality && oldestJoin.Equal(best.oldestJoin) && lowID < best.lowID) ||
				(matchQuality == best.matchQuality && oldestJoin.Equal(best.oldestJoin) && lowID == best.lowID && highID < best.highID) {
				best = candidate{
					leftIndex:    i,
					rightIndex:   j,
					fairness:     fairness,
					uniformity:   uniformity,
					matchQuality: matchQuality,
					oldestJoin:   oldestJoin,
					lowID:        lowID,
					highID:       highID,
				}
			}
		}
	}

	if best.leftIndex == -1 {
		return DetailedMatch{}, false
	}

	left := m.entries[best.leftIndex].team
	right := m.entries[best.rightIndex].team
	detailed := DetailedMatch{
		Team1:        left,
		Team2:        right,
		Fairness:     best.fairness,
		Uniformity:   best.uniformity,
		MatchQuality: best.matchQuality,
		Alpha:        DefaultMatchQualityAlpha,
	}

	log.Printf(
		"[QUEUE] match formed: TEAM1=%s vs TEAM2=%s | fairness=%.2f | match_uniformity=%.2f | alpha=>[Fairness=%.2f & Quality=%.2f] | quality=%.2f",
		teamLogString(left),
		teamLogString(right),
		best.fairness,
		best.uniformity,
		DefaultMatchQualityAlpha,
		1.0-DefaultMatchQualityAlpha,
		best.matchQuality,
	)

	m.removeTwoEntriesLocked(best.leftIndex, best.rightIndex)
	return detailed, true
}

func (m *Manager) allowedGapLocked(player SoloPlayer, now time.Time) float64 {
	return AllowedGap(player, now)
}

func (m *Manager) insertEntryLocked(newEntry entry) {
	insertAt := len(m.entries)
	for i, current := range m.entries {
		if entryQueueTime(newEntry).Before(entryQueueTime(current)) {
			insertAt = i
			break
		}
		if entryQueueTime(newEntry).Equal(entryQueueTime(current)) && entryMinPlayerID(newEntry) < entryMinPlayerID(current) {
			insertAt = i
			break
		}
	}

	m.entries = append(m.entries, entry{})
	copy(m.entries[insertAt+1:], m.entries[insertAt:])
	m.entries[insertAt] = newEntry
}

func (m *Manager) removeTwoEntriesLocked(leftIndex, rightIndex int) {
	if leftIndex > rightIndex {
		leftIndex, rightIndex = rightIndex, leftIndex
	}

	m.entries = append(m.entries[:rightIndex], m.entries[rightIndex+1:]...)
	m.entries = append(m.entries[:leftIndex], m.entries[leftIndex+1:]...)
}

func entryQueueTime(current entry) time.Time {
	switch current.kind {
	case entrySolo:
		return current.solo.JoinTime
	case entryTeam:
		return teamJoinTime(current.team)
	default:
		return time.Time{}
	}
}

func entryMinPlayerID(current entry) uint64 {
	switch current.kind {
	case entrySolo:
		return current.solo.PlayerID
	case entryTeam:
		return minUint64(current.team.Members[0].PlayerID, current.team.Members[1].PlayerID)
	default:
		return 0
	}
}

func teamJoinTime(team Team) time.Time {
	return minTime(team.Members[0].JoinTime, team.Members[1].JoinTime)
}

func computeTeamSkill(left, right SoloPlayer) float64 {
	return math.Max(left.Skill, right.Skill)
}

func computeFairness(left Team, right Team) float64 {
	return math.Abs(left.TeamSkill - right.TeamSkill)
}

func computeMatchUniformity(left Team, right Team) float64 {
	s1 := left.Members[0].Skill
	s2 := left.Members[1].Skill
	s3 := right.Members[0].Skill
	s4 := right.Members[1].Skill

	mean := (s1 + s2 + s3 + s4) / 4.0

	sumSquares := 0.0
	sumSquares += math.Pow(s1-mean, 2)
	sumSquares += math.Pow(s2-mean, 2)
	sumSquares += math.Pow(s3-mean, 2)
	sumSquares += math.Pow(s4-mean, 2)

	return math.Sqrt(sumSquares / 4.0)
}

func computeMatchQuality(fairness, uniformity, alpha float64) float64 {
	return alpha*fairness + (1.0-alpha)*uniformity
}

func minTime(left, right time.Time) time.Time {
	if left.Before(right) {
		return left
	}
	return right
}

func minUint64(left, right uint64) uint64 {
	if left < right {
		return left
	}
	return right
}

func maxUint64(left, right uint64) uint64 {
	if left > right {
		return left
	}
	return right
}

func playerLogString(player SoloPlayer) string {
	return fmt.Sprintf("%s (id=%d, skill=%.2f)", player.Name, player.PlayerID, player.Skill)
}

func teamLogString(team Team) string {
	return fmt.Sprintf(
		"[%s | %s] team_skill=%.2f",
		playerLogString(team.Members[0]),
		playerLogString(team.Members[1]),
		team.TeamSkill,
	)
}
