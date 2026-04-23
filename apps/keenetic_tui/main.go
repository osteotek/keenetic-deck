package main

import (
	"fmt"
	"os"

	"github.com/arthur/keenetic-deck/apps/keenetic_tui/internal/core"
	"github.com/arthur/keenetic-deck/apps/keenetic_tui/internal/ui"
	tea "github.com/charmbracelet/bubbletea"
)

func main() {
	env, err := core.NewEnvironment()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to initialize environment: %v\n", err)
		os.Exit(1)
	}

	program := tea.NewProgram(
		ui.NewModel(env),
		tea.WithAltScreen(),
	)
	if _, err := program.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "program error: %v\n", err)
		os.Exit(1)
	}
}
