package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"time"

	"server/internal/server/queue"
)

type MockPlayer struct {
	PlayerID          uint64 `json:"player_id"`
	Name              string `json:"name"`
	Kills             int64  `json:"kills"`
	Deaths            int64  `json:"deaths"`
	FlagCaptures      int64  `json:"flag_captures"`
	Wins              int64  `json:"wins"`
	Losses            int64  `json:"losses"`
	JoinOffsetSeconds int64  `json:"join_offset_seconds"`
}

type LeftoverCategory struct {
	Title   string
	Players []queue.SoloPlayer
}

type MatchAverages struct {
	AveragePairGap      float64
	AverageMatchQuality float64
	MatchedPairCount    int
	MatchCount          int
}

func main() {
	baseDir, err := sourceDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to resolve matchmake folder: %v\n", err)
		os.Exit(1)
	}

	inputPath := filepath.Join(baseDir, "players_edge_relaxation_threshold.json") // change here to load a different set of players
	outputPath := filepath.Join(baseDir, "report.txt")

	players, err := loadPlayers(inputPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to load players from %s: %v\n", inputPath, err)
		os.Exit(1)
	}

	manager := queue.New()
	runAt := time.Now().UTC()

	for _, player := range players {
		skill := queue.ComputeSkill(player.Kills, player.Deaths, player.FlagCaptures, player.Wins, player.Losses)
		joinTime := runAt.Add(-time.Duration(player.JoinOffsetSeconds) * time.Second)

		joined := manager.EnqueueSolo(player.PlayerID, player.Name, skill, joinTime)
		if !joined {
			fmt.Fprintf(os.Stderr, "duplicate player_id detected: %d\n", player.PlayerID)
			os.Exit(1)
		}
	}

	matches := manager.MatchmakeDetailed(runAt)
	snapshot := manager.Snapshot()
	categories := categorizeLeftoverSolos(snapshot.Solos, runAt)
	averages := calculateMatchAverages(matches)

	report, err := buildReport(players, matches, snapshot, categories, averages, runAt)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to build report: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(outputPath, []byte(report), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write report to %s: %v\n", outputPath, err)
		os.Exit(1)
	}

	fmt.Printf("players file: %s\n", inputPath)
	fmt.Printf("report file:  %s\n", outputPath)
	fmt.Println("matchmaking report written successfully")

	fmt.Println()
	fmt.Println("SIMULATION AVERAGES")
	fmt.Println("-------------------")
	fmt.Printf("Matched pairs counted: %d\n", averages.MatchedPairCount)
	fmt.Printf("Matches counted: %d\n", averages.MatchCount)

	if averages.MatchedPairCount == 0 {
		fmt.Println("Average pair gap: N/A - no matched pairs")
	} else {
		fmt.Printf("Average pair gap: %.2f\n", averages.AveragePairGap)
	}

	if averages.MatchCount == 0 {
		fmt.Println("Average match quality: N/A - no matches")
	} else {
		fmt.Printf("Average match quality: %.2f\n", averages.AverageMatchQuality)
	}
}

func sourceDir() (string, error) {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		return "", fmt.Errorf("runtime.Caller failed")
	}
	return filepath.Dir(file), nil
}

func loadPlayers(path string) ([]MockPlayer, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var players []MockPlayer
	if err := json.Unmarshal(data, &players); err != nil {
		return nil, err
	}

	return players, nil
}

func categorizeLeftoverSolos(solos []queue.SoloPlayer, now time.Time) []LeftoverCategory {
	if len(solos) == 0 {
		return nil
	}

	unableToPair := make([]queue.SoloPlayer, 0)
	waitingForMorePlayers := make([]queue.SoloPlayer, 0)

	for i, player := range solos {
		canPair := false
		for j, other := range solos {
			if i == j {
				continue
			}
			if queue.CanPlayersPair(player, other, now) {
				canPair = true
				break
			}
		}

		if canPair {
			waitingForMorePlayers = append(waitingForMorePlayers, player)
		} else {
			unableToPair = append(unableToPair, player)
		}
	}

	categories := make([]LeftoverCategory, 0, 2)
	if len(unableToPair) > 0 {
		categories = append(categories, LeftoverCategory{
			Title:   "Could not form a valid teammate pair under the current teammate-gap threshold",
			Players: unableToPair,
		})
	}
	if len(waitingForMorePlayers) > 0 {
		categories = append(categories, LeftoverCategory{
			Title:   "Could form a teammate pair, but there were not enough additional players/teams to complete another full match",
			Players: waitingForMorePlayers,
		})
	}
	return categories
}

func calculateMatchAverages(matches []queue.DetailedMatch) MatchAverages {
	if len(matches) == 0 {
		return MatchAverages{
			AveragePairGap:      0,
			AverageMatchQuality: 0,
			MatchedPairCount:    0,
			MatchCount:          0,
		}
	}

	totalPairGap := 0.0
	totalMatchQuality := 0.0
	matchedPairCount := 0

	for _, match := range matches {
		team1Gap := queue.TeamPairGap(match.Team1)
		team2Gap := queue.TeamPairGap(match.Team2)

		totalPairGap += team1Gap
		totalPairGap += team2Gap
		matchedPairCount += 2

		totalMatchQuality += match.MatchQuality
	}

	return MatchAverages{
		AveragePairGap:      totalPairGap / float64(matchedPairCount),
		AverageMatchQuality: totalMatchQuality / float64(len(matches)),
		MatchedPairCount:    matchedPairCount,
		MatchCount:          len(matches),
	}
}

func buildReport(
	input []MockPlayer,
	matches []queue.DetailedMatch,
	snapshot queue.Snapshot,
	categories []LeftoverCategory,
	averages MatchAverages,
	runAt time.Time,
) (string, error) {
	var b strings.Builder

	fmt.Fprintf(&b, "MATCHMAKING REPORT\n")
	fmt.Fprintf(&b, "==================\n\n")
	fmt.Fprintf(&b, "Run time: %s\n", runAt.Format(time.RFC3339))
	fmt.Fprintf(&b, "Input players: %d\n", len(input))
	fmt.Fprintf(&b, "Matches formed: %d\n", len(matches))
	fmt.Fprintf(&b, "Unmatched teams: %d\n", len(snapshot.Teams))
	fmt.Fprintf(&b, "Unmatched solo players: %d\n\n", len(snapshot.Solos))

	fmt.Fprintf(&b, "ALGORITHM PARAMETERS\n")
	fmt.Fprintf(&b, "--------------------\n")
	fmt.Fprintf(&b, "Teammate uniformity max gap: %.2f\n", queue.DefaultUniformityMax)
	fmt.Fprintf(&b, "Teammate uniformity hard gap: %.2f\n", queue.DefaultUniformityHard)
	fmt.Fprintf(&b, "Relax after: %s\n", queue.DefaultRelaxAfter)
	fmt.Fprintf(&b, "Match quality alpha: %.2f\n\n", queue.DefaultMatchQualityAlpha)

	fmt.Fprintf(&b, "SIMULATION AVERAGES\n")
	fmt.Fprintf(&b, "-------------------\n")
	fmt.Fprintf(&b, "Matched pairs counted: %d\n", averages.MatchedPairCount)
	fmt.Fprintf(&b, "Matches counted: %d\n", averages.MatchCount)

	if averages.MatchedPairCount == 0 {
		fmt.Fprintf(&b, "Average pair gap: N/A - no matched pairs\n")
	} else {
		fmt.Fprintf(&b, "Average pair gap: %.2f\n", averages.AveragePairGap)
	}

	if averages.MatchCount == 0 {
		fmt.Fprintf(&b, "Average match quality: N/A - no matches\n\n")
	} else {
		fmt.Fprintf(&b, "Average match quality: %.2f\n\n", averages.AverageMatchQuality)
	}

	fmt.Fprintf(&b, "INPUT PLAYERS\n")
	fmt.Fprintf(&b, "-------------\n")
	sortedInput := append([]MockPlayer(nil), input...)
	sort.Slice(sortedInput, func(i, j int) bool {
		if sortedInput[i].JoinOffsetSeconds != sortedInput[j].JoinOffsetSeconds {
			return sortedInput[i].JoinOffsetSeconds > sortedInput[j].JoinOffsetSeconds
		}
		return sortedInput[i].PlayerID < sortedInput[j].PlayerID
	})
	for _, player := range sortedInput {
		skill := queue.ComputeSkill(player.Kills, player.Deaths, player.FlagCaptures, player.Wins, player.Losses)
		fmt.Fprintf(&b,
			"- %s (id=%d) | skill=%.2f | join_offset_seconds=%d | stats: kills=%d deaths=%d flags=%d wins=%d losses=%d\n",
			player.Name,
			player.PlayerID,
			skill,
			player.JoinOffsetSeconds,
			player.Kills,
			player.Deaths,
			player.FlagCaptures,
			player.Wins,
			player.Losses,
		)
	}
	fmt.Fprintf(&b, "\n")

	fmt.Fprintf(&b, "MATCHES FORMED\n")
	fmt.Fprintf(&b, "--------------\n")
	if len(matches) == 0 {
		fmt.Fprintf(&b, "No matches were formed.\n\n")
	} else {
		for i, match := range matches {
			fmt.Fprintf(&b, "Match %d\n", i+1)
			fmt.Fprintf(&b, "  Team 1: %s\n", formatTeam(match.Team1))
			fmt.Fprintf(&b, "  Team 2: %s\n", formatTeam(match.Team2))
			fmt.Fprintf(&b, "  Team 1 pair gap: %.2f\n", queue.TeamPairGap(match.Team1))
			fmt.Fprintf(&b, "  Team 2 pair gap: %.2f\n", queue.TeamPairGap(match.Team2))
			fmt.Fprintf(&b, "  Fairness: %.2f\n", match.Fairness)
			fmt.Fprintf(&b, "  Match uniformity: %.2f\n", match.Uniformity)
			fmt.Fprintf(&b, "  Quality: %.2f (alpha=%.2f)\n\n", match.MatchQuality, match.Alpha)
		}
	}

	fmt.Fprintf(&b, "UNMATCHED TEAMS\n")
	fmt.Fprintf(&b, "---------------\n")
	if len(snapshot.Teams) == 0 {
		fmt.Fprintf(&b, "No unmatched teams remain.\n\n")
	} else {
		for i, team := range snapshot.Teams {
			fmt.Fprintf(&b, "Team %d: %s\n", i+1, formatTeam(team))
			fmt.Fprintf(&b, "  Pair gap: %.2f\n", queue.TeamPairGap(team))
			fmt.Fprintf(&b, "  Status: Team exists but could not be matched against another team.\n\n")
		}
	}

	fmt.Fprintf(&b, "LEFTOVER SOLO PLAYERS\n")
	fmt.Fprintf(&b, "---------------------\n")
	if len(snapshot.Solos) == 0 {
		fmt.Fprintf(&b, "No leftover solo players remain.\n")
		return b.String(), nil
	}

	if len(categories) == 0 {
		fmt.Fprintf(&b, "No categories available.\n")
		return b.String(), nil
	}

	for _, category := range categories {
		fmt.Fprintf(&b, "%s\n", category.Title)
		for _, player := range category.Players {
			fmt.Fprintf(&b, "  - %s (id=%d) | skill=%.2f | join_time=%s | allowed_gap_now=%.2f\n",
				player.Name,
				player.PlayerID,
				player.Skill,
				player.JoinTime.Format(time.RFC3339),
				queue.AllowedGap(player, runAt),
			)
		}
		fmt.Fprintf(&b, "\n")
	}

	return b.String(), nil
}

func formatTeam(team queue.Team) string {
	left := team.Members[0]
	right := team.Members[1]
	return fmt.Sprintf(
		"[%s (id=%d, skill=%.2f) + %s (id=%d, skill=%.2f)] | team_skill=%.2f",
		left.Name,
		left.PlayerID,
		left.Skill,
		right.Name,
		right.PlayerID,
		right.Skill,
		team.TeamSkill,
	)
}
