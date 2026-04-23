package ui

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/arthur/keenetic-deck/apps/keenetic_tui/internal/core"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

const autoRefreshInterval = 2 * time.Second

var (
	appStyle = lipgloss.NewStyle().Padding(1, 2)

	tabBarStyle    = lipgloss.NewStyle().Padding(0, 1).MarginBottom(1)
	tabStyle       = lipgloss.NewStyle().Padding(0, 1).Foreground(lipgloss.Color("250"))
	activeTabStyle = lipgloss.NewStyle().
			Padding(0, 1).
			Foreground(lipgloss.Color("230")).
			Background(lipgloss.Color("62")).
			Bold(true)
	contentStyle  = lipgloss.NewStyle()
	titleStyle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	mutedStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("244"))
	errorStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("203"))
	successStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	accentStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("111")).Bold(true)
	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("230")).
			Background(lipgloss.Color("62")).
			Padding(0, 1)
	panelStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			Padding(1, 2)
)

type overviewLoadedMsg struct {
	id       int
	overview core.RouterOverview
	err      error
}

type routerSavedMsg struct {
	err     error
	message string
}

type routerDeletedMsg struct {
	err     error
	message string
}

type clientActionDoneMsg struct {
	err     error
	message string
}

type preferencesSavedMsg struct {
	err     error
	message string
}

type tickMsg time.Time

type Model struct {
	env *core.Environment

	width  int
	height int

	section core.AppSection

	overview   *core.RouterOverview
	loading    bool
	refreshing bool

	requestID int

	errorMessage string
	flashMessage string

	clientQuery string
	policyQuery string

	searchInput  textinput.Model
	searchActive bool

	routerIndex     int
	clientIndex     int
	policyClientIdx int
	deviceClientIdx int

	form          *routerForm
	deleteConfirm *core.RouterProfile
	actionMenu    *clientActionMenu
}

func NewModel(env *core.Environment) Model {
	search := textinput.New()
	search.CharLimit = 120
	search.Prompt = "Search: "
	search.Placeholder = "Start typing"
	return Model{
		env:         env,
		section:     core.SectionRouters,
		searchInput: search,
		loading:     true,
	}
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(m.loadOverview(), tickCmd())
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case overviewLoadedMsg:
		if msg.id != m.requestID {
			return m, nil
		}
		m.loading = false
		m.refreshing = false
		if msg.err != nil {
			m.errorMessage = msg.err.Error()
			return m, nil
		}
		m.errorMessage = ""
		m.overview = &msg.overview
		m.ensureIndices()
		return m, nil
	case routerSavedMsg:
		m.form = nil
		if msg.err != nil {
			m.errorMessage = msg.err.Error()
			return m, nil
		}
		m.flashMessage = msg.message
		m.errorMessage = ""
		m.refreshing = true
		return m, m.loadOverview()
	case routerDeletedMsg:
		m.deleteConfirm = nil
		if msg.err != nil {
			m.errorMessage = msg.err.Error()
			return m, nil
		}
		m.flashMessage = msg.message
		m.errorMessage = ""
		m.refreshing = true
		return m, m.loadOverview()
	case clientActionDoneMsg:
		m.actionMenu = nil
		if msg.err != nil {
			m.errorMessage = msg.err.Error()
			return m, nil
		}
		m.flashMessage = msg.message
		m.errorMessage = ""
		m.refreshing = true
		return m, m.loadOverview()
	case preferencesSavedMsg:
		if msg.err != nil {
			m.errorMessage = msg.err.Error()
			return m, nil
		}
		m.flashMessage = msg.message
		m.errorMessage = ""
		if m.overview != nil {
			m.overview.AutoRefreshEnable = !m.overview.AutoRefreshEnable
		}
		return m, nil
	case tickMsg:
		cmds := []tea.Cmd{tickCmd()}
		if m.shouldAutoRefresh() {
			m.refreshing = true
			cmds = append(cmds, m.loadOverview())
		}
		return m, tea.Batch(cmds...)
	}

	if m.form != nil {
		return m.updateForm(msg)
	}
	if m.deleteConfirm != nil {
		return m.updateDeleteConfirm(msg)
	}
	if m.actionMenu != nil {
		return m.updateActionMenu(msg)
	}
	if m.searchActive {
		return m.updateSearch(msg)
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "tab", "right", "l":
			m.section = nextSection(m.section)
			return m, nil
		case "shift+tab", "left", "h":
			m.section = prevSection(m.section)
			return m, nil
		case "1":
			m.section = core.SectionRouters
			return m, nil
		case "2":
			m.section = core.SectionClients
			return m, nil
		case "3":
			m.section = core.SectionPolicies
			return m, nil
		case "4":
			m.section = core.SectionWireGuard
			return m, nil
		case "5":
			m.section = core.SectionThisDevice
			return m, nil
		case "6":
			m.section = core.SectionSettings
			return m, nil
		case "r":
			m.refreshing = true
			return m, m.loadOverview()
		case "/":
			if m.section == core.SectionClients || m.section == core.SectionPolicies {
				m.searchActive = true
				if m.section == core.SectionClients {
					m.searchInput.SetValue(m.clientQuery)
				} else {
					m.searchInput.SetValue(m.policyQuery)
				}
				cmd := m.searchInput.Focus()
				return m, cmd
			}
		}
	}

	return m.updateSection(msg)
}

func (m Model) View() string {
	if m.width == 0 || m.height == 0 {
		return "Loading..."
	}

	tabBar := m.renderTabBar()
	content := m.renderContent()

	statusLines := []string{titleStyle.Render("Keenetic Deck TUI")}
	if m.loading {
		statusLines = append(statusLines, mutedStyle.Render("Loading router state..."))
	} else if m.refreshing {
		statusLines = append(statusLines, mutedStyle.Render("Refreshing..."))
	}
	if m.errorMessage != "" {
		statusLines = append(statusLines, errorStyle.Render(m.errorMessage))
	} else if m.flashMessage != "" {
		statusLines = append(statusLines, successStyle.Render(m.flashMessage))
	}
	statusLines = append(statusLines, mutedStyle.Render(m.renderHeaderStatus()))
	statusLines = append(statusLines, mutedStyle.Render("tab/h/l switch • 1-6 jump • r refresh • / search • j/k move • enter action • q quit"))

	body := lipgloss.JoinVertical(lipgloss.Left, strings.Join(statusLines, "\n"), "", tabBar, content)
	if overlay := m.renderOverlay(); overlay != "" {
		body = lipgloss.JoinVertical(lipgloss.Left, body, "", overlay)
	}
	return appStyle.Render(body)
}

func (m *Model) updateSection(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch m.section {
	case core.SectionRouters:
		return m.updateRouters(msg)
	case core.SectionClients:
		return m.updateClients(msg)
	case core.SectionPolicies:
		return m.updatePolicies(msg)
	case core.SectionWireGuard:
		return m.updateWireGuard(msg)
	case core.SectionThisDevice:
		return m.updateThisDevice(msg)
	case core.SectionSettings:
		return m.updateSettings(msg)
	default:
		return m, nil
	}
}

func (m *Model) updateRouters(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		routers := m.routers()
		switch key.String() {
		case "j", "down":
			if len(routers) > 0 && m.routerIndex < len(routers)-1 {
				m.routerIndex++
			}
		case "k", "up":
			if m.routerIndex > 0 {
				m.routerIndex--
			}
		case "a":
			m.startRouterForm(nil)
			return m, m.form.Focus()
		case "e":
			if router := m.currentRouter(); router != nil {
				copy := *router
				m.startRouterForm(&copy)
				return m, m.form.Focus()
			}
		case "d":
			if router := m.currentRouter(); router != nil {
				copy := *router
				m.deleteConfirm = &copy
			}
		case "enter":
			if router := m.currentRouter(); router != nil {
				m.refreshing = true
				return m, selectRouterCmd(m.env, router.ID)
			}
		}
	}
	return m, nil
}

func (m *Model) updateClients(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		clients := m.filteredClients()
		switch key.String() {
		case "j", "down":
			if len(clients) > 0 && m.clientIndex < len(clients)-1 {
				m.clientIndex++
			}
		case "k", "up":
			if m.clientIndex > 0 {
				m.clientIndex--
			}
		case "enter":
			if len(clients) > 0 {
				m.openActionMenu(clients[m.clientIndex], "clients")
			}
		}
	}
	return m, nil
}

func (m *Model) updatePolicies(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		rows := m.policyClientRows()
		switch key.String() {
		case "j", "down":
			if len(rows) > 0 && m.policyClientIdx < len(rows)-1 {
				m.policyClientIdx++
			}
		case "k", "up":
			if m.policyClientIdx > 0 {
				m.policyClientIdx--
			}
		case "enter":
			if len(rows) > 0 {
				m.openActionMenu(rows[m.policyClientIdx].Client, "policies")
			}
		}
	}
	return m, nil
}

func (m *Model) updateWireGuard(msg tea.Msg) (tea.Model, tea.Cmd) {
	return m, nil
}

func (m *Model) updateThisDevice(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		rows := m.matchedClients()
		switch key.String() {
		case "j", "down":
			if len(rows) > 0 && m.deviceClientIdx < len(rows)-1 {
				m.deviceClientIdx++
			}
		case "k", "up":
			if m.deviceClientIdx > 0 {
				m.deviceClientIdx--
			}
		case "enter":
			if len(rows) > 0 {
				m.openActionMenu(rows[m.deviceClientIdx], "device")
			}
		}
	}
	return m, nil
}

func (m *Model) updateSettings(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		if key.String() == "a" && m.overview != nil {
			enabled := !m.overview.AutoRefreshEnable
			return m, savePreferencesCmd(m.env, enabled)
		}
	}
	return m, nil
}

func (m *Model) updateSearch(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		switch key.String() {
		case "esc":
			m.searchActive = false
			m.searchInput.Blur()
			return m, nil
		case "enter":
			m.searchActive = false
			m.searchInput.Blur()
			return m, nil
		}
	}
	var cmd tea.Cmd
	m.searchInput, cmd = m.searchInput.Update(msg)
	if m.section == core.SectionClients {
		m.clientQuery = m.searchInput.Value()
		m.clientIndex = 0
	} else if m.section == core.SectionPolicies {
		m.policyQuery = m.searchInput.Value()
		m.policyClientIdx = 0
	}
	return m, cmd
}

func (m *Model) updateForm(msg tea.Msg) (tea.Model, tea.Cmd) {
	return m.form.Update(msg, m.env)
}

func (m *Model) updateDeleteConfirm(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		switch key.String() {
		case "esc", "n":
			m.deleteConfirm = nil
		case "y":
			router := *m.deleteConfirm
			return m, deleteRouterCmd(m.env, router)
		}
	}
	return m, nil
}

func (m *Model) updateActionMenu(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch key := msg.(type) {
	case tea.KeyMsg:
		switch key.String() {
		case "esc":
			m.actionMenu = nil
		case "j", "down":
			if m.actionMenu.index < len(m.actionMenu.options)-1 {
				m.actionMenu.index++
			}
		case "k", "up":
			if m.actionMenu.index > 0 {
				m.actionMenu.index--
			}
		case "enter":
			option := m.actionMenu.options[m.actionMenu.index]
			status := m.selectedStatus()
			if status == nil {
				return m, nil
			}
			return m, clientActionCmd(m.env, *status, option.request, option.label)
		}
	}
	return m, nil
}

func (m *Model) renderTabBar() string {
	tabs := make([]string, 0, 6)
	for _, section := range []core.AppSection{
		core.SectionRouters,
		core.SectionClients,
		core.SectionPolicies,
		core.SectionWireGuard,
		core.SectionThisDevice,
		core.SectionSettings,
	} {
		line := tabStyle.Render(section.Label())
		if section == m.section {
			line = activeTabStyle.Render(section.Label())
		}
		tabs = append(tabs, line)
	}
	return tabBarStyle.Render(lipgloss.JoinHorizontal(lipgloss.Top, tabs...))
}

func (m *Model) renderContent() string {
	var body string
	switch m.section {
	case core.SectionRouters:
		body = m.renderRouters()
	case core.SectionClients:
		body = m.renderClients()
	case core.SectionPolicies:
		body = m.renderPolicies()
	case core.SectionWireGuard:
		body = m.renderWireGuard()
	case core.SectionThisDevice:
		body = m.renderThisDevice()
	case core.SectionSettings:
		body = m.renderSettings()
	}
	return contentStyle.
		Width(max(20, m.width-4)).
		MaxHeight(m.contentMaxHeight()).
		Render(body)
}

func (m *Model) renderHeaderStatus() string {
	if m.overview == nil || m.overview.SelectedStatus == nil {
		return "No router selected"
	}
	status := m.overview.SelectedStatus
	label := "connection failed"
	if status.IsConnected {
		label = "connected"
	} else if !status.HasStoredPassword {
		label = "password missing"
	}
	checked := status.CheckedAt.Format("2006-01-02 15:04:05")
	return fmt.Sprintf("%s • %s • checked %s", status.Router.Name, label, checked)
}

func (m *Model) searchLine(hint, value string) string {
	if m.searchActive && (m.section == core.SectionClients || m.section == core.SectionPolicies) {
		return fmt.Sprintf("Search (%s): %s", hint, m.searchInput.View())
	}
	if strings.TrimSpace(value) == "" {
		return fmt.Sprintf("Search (%s): / to filter", hint)
	}
	return fmt.Sprintf("Search (%s): %s", hint, value)
}

func (m *Model) renderRouters() string {
	lines := []string{
		titleStyle.Render("Routers"),
		fmt.Sprintf("Storage: %s", m.storagePath()),
		"",
		m.renderSelectedRouterSummary(),
		"",
		mutedStyle.Render("Keys: a add, e edit, d delete, enter select"),
		"",
	}
	routers := m.routers()
	if len(routers) == 0 {
		lines = append(lines, "No routers stored yet.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	for index, router := range routers {
		marker := "  "
		if index == m.routerIndex {
			marker = "› "
		}
		selected := ""
		if m.overview != nil && router.ID == m.overview.SelectedRouterID {
			selected = " [selected]"
		}
		password := "no password"
		if m.overview != nil && m.overview.PasswordStored[router.ID] {
			password = "password saved"
		}
		line := fmt.Sprintf("%s%s%s\n   %s • %s", marker, router.Name, selected, router.Address, password)
		if index == m.routerIndex {
			line = selectedStyle.Render(line)
		}
		lines = append(lines, line, "")
	}
	return panelStyle.Render(strings.Join(lines, "\n"))
}

func (m *Model) renderSelectedRouterSummary() string {
	if m.overview == nil || m.overview.SelectedStatus == nil {
		return "No selected router status yet."
	}
	status := m.overview.SelectedStatus
	lines := []string{
		accentStyle.Render("Selected Router Status"),
		fmt.Sprintf("%s (%s)", status.Router.Name, status.Router.Address),
	}
	if status.ConnectionTarget != nil {
		lines = append(lines, fmt.Sprintf("Target: %s via %s", status.ConnectionTarget.URI, status.ConnectionTarget.Kind))
	}
	if status.ErrorMessage != "" {
		lines = append(lines, errorStyle.Render(status.ErrorMessage))
	} else {
		lines = append(lines,
			fmt.Sprintf("Clients: %d total, %d online", status.ClientCount, status.OnlineClientCount),
			fmt.Sprintf("Policies: %d", status.PolicyCount),
			fmt.Sprintf("WireGuard peers: %d", status.WireGuardPeerCount),
		)
	}
	return strings.Join(lines, "\n")
}

func (m *Model) renderClients() string {
	status := m.selectedStatus()
	lines := []string{
		titleStyle.Render("Clients"),
		m.searchLine("Name, IP, or MAC", m.clientQuery),
		"",
	}
	if status == nil {
		lines = append(lines, "Select and connect a router to see its clients.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	if !status.IsConnected {
		lines = append(lines, "Clients will appear here after the selected router connects successfully.")
		if status.ErrorMessage != "" {
			lines = append(lines, errorStyle.Render(status.ErrorMessage))
		}
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	clients := m.filteredClients()
	if len(clients) == 0 {
		lines = append(lines, "No clients matched the current filter.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	start, end := listWindow(len(clients), m.clientIndex, m.clientsListCapacity())
	visibleClients := clients[start:end]
	lines = append(lines, mutedStyle.Render(fmt.Sprintf("Showing %d-%d of %d clients", start+1, end, len(clients))))
	lines = append(lines, mutedStyle.Render("Enter opens client actions: default policy, named policies, block, Wake-on-LAN"), "")
	for offset, client := range visibleClients {
		index := start + offset
		state := "offline"
		if client.ConnectionState == core.ClientConnectionOnline {
			state = "online"
		}
		details := []string{state, client.MACAddress}
		if client.IPAddress != "" {
			details = append(details, client.IPAddress)
		}
		if client.PolicyName != "" {
			details = append(details, "policy="+client.PolicyName)
		}
		line := fmt.Sprintf("%s%s\n   %s", selector(index == m.clientIndex), client.Name, strings.Join(details, " • "))
		if client.IsWireless() {
			wireless := []string{}
			if client.WiFiBand != "" {
				wireless = append(wireless, client.WiFiBand)
			}
			if client.WiFiStandard != "" {
				wireless = append(wireless, client.WiFiStandard)
			}
			if len(wireless) > 0 {
				line += "\n   " + strings.Join(wireless, " • ")
			}
		}
		if index == m.clientIndex {
			line = selectedStyle.Render(line)
		}
		lines = append(lines, line, "")
	}
	return panelStyle.Render(strings.Join(lines, "\n"))
}

func (m *Model) renderPolicies() string {
	status := m.selectedStatus()
	lines := []string{
		titleStyle.Render("Policies"),
		m.searchLine("Policy, name, IP, or MAC", m.policyQuery),
		"",
	}
	if status == nil {
		lines = append(lines, "Select and connect a router to manage policies.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	if !status.IsConnected {
		lines = append(lines, "Policies will appear here after the selected router connects successfully.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	rows := m.policyClientRows()
	summary := policySummary(status)
	lines = append(lines,
		fmt.Sprintf("Named policies: %d", summary.NamedPolicyCount),
		fmt.Sprintf("Assigned clients: %d", summary.AssignedClientCount),
		fmt.Sprintf("Default clients: %d", summary.DefaultClientCount),
		fmt.Sprintf("Blocked clients: %d", summary.BlockedClientCount),
		"",
	)
	if len(rows) == 0 {
		lines = append(lines, "No policies or clients matched the current filter.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	start, end := listWindow(len(rows), m.policyClientIdx, m.policiesListCapacity())
	visibleRows := rows[start:end]
	lines = append(lines, mutedStyle.Render(fmt.Sprintf("Showing %d-%d of %d policy rows", start+1, end, len(rows))), "")
	currentGroup := ""
	for offset, row := range visibleRows {
		index := start + offset
		if row.GroupLabel != currentGroup {
			currentGroup = row.GroupLabel
			lines = append(lines, accentStyle.Render(currentGroup))
		}
		line := fmt.Sprintf("%s%s\n   %s • %s", selector(index == m.policyClientIdx), row.Client.Name, row.Client.MACAddress, defaultString(row.Client.PolicyName, "default"))
		if row.IsLocalMatch {
			line += " • this device"
		}
		if index == m.policyClientIdx {
			line = selectedStyle.Render(line)
		}
		lines = append(lines, line)
	}
	return panelStyle.Render(strings.Join(lines, "\n"))
}

func (m *Model) renderWireGuard() string {
	status := m.selectedStatus()
	lines := []string{titleStyle.Render("WireGuard"), ""}
	if status == nil {
		lines = append(lines, "Select and connect a router to view WireGuard peers.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	if !status.IsConnected {
		lines = append(lines, "WireGuard peers will appear here after the selected router connects successfully.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	grouped := groupPeers(status.WireGuardPeers)
	if len(grouped) == 0 {
		lines = append(lines, "No WireGuard peers were returned by the router.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	for _, group := range grouped {
		lines = append(lines, accentStyle.Render(group.InterfaceName))
		for _, peer := range group.Peers {
			state := "disabled"
			if peer.IsEnabled {
				state = "enabled"
			}
			lines = append(lines,
				fmt.Sprintf("%s (%s)", peer.PeerName, state),
				fmt.Sprintf("  Allowed IPs: %s", strings.Join(peer.AllowedIPs, ", ")),
			)
			if peer.Endpoint != "" {
				lines = append(lines, fmt.Sprintf("  Endpoint: %s", peer.Endpoint))
			}
		}
		lines = append(lines, "")
	}
	return panelStyle.Render(strings.Join(lines, "\n"))
}

func (m *Model) renderThisDevice() string {
	status := m.selectedStatus()
	lines := []string{titleStyle.Render("This Device"), ""}
	if status == nil {
		lines = append(lines, "Select and connect a router to match this device against router clients.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	lines = append(lines,
		fmt.Sprintf("Local interface discovery: %s", availability(len(status.LocalMACAddresses) > 0)),
		"Traffic inspection: unavailable",
		"",
	)
	if len(status.LocalMACAddresses) == 0 {
		lines = append(lines, "No local MAC addresses were discovered on this device.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	lines = append(lines, "Local MAC addresses:")
	for _, mac := range status.LocalMACAddresses {
		lines = append(lines, "  "+mac)
	}
	lines = append(lines, "")
	if !status.IsConnected {
		lines = append(lines, "The selected router is not connected yet, so device matching cannot be completed.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	matches := m.matchedClients()
	if len(matches) == 0 {
		lines = append(lines, "No selected-router clients matched the local MAC addresses.")
		return panelStyle.Render(strings.Join(lines, "\n"))
	}
	lines = append(lines, mutedStyle.Render("Matched clients can be managed directly from this screen."), "")
	for index, client := range matches {
		line := fmt.Sprintf("%s%s\n   %s", selector(index == m.deviceClientIdx), client.Name, client.MACAddress)
		if index == m.deviceClientIdx {
			line = selectedStyle.Render(line)
		}
		lines = append(lines, line)
	}
	return panelStyle.Render(strings.Join(lines, "\n"))
}

func (m *Model) renderSettings() string {
	lines := []string{
		titleStyle.Render("Settings"),
		"Keenetic Deck TUI",
		"Bubble Tea-based terminal app",
		"",
		fmt.Sprintf("Auto-refresh live router screens: %s", availability(m.overview != nil && m.overview.AutoRefreshEnable)),
		"Press a to toggle",
		"",
		fmt.Sprintf("Router storage: %s", m.storagePath()),
	}
	if m.env != nil {
		lines = append(lines,
			fmt.Sprintf("Secrets: %s", m.env.StoragePaths.SecretsPath),
			fmt.Sprintf("Preferences: %s", m.env.StoragePaths.PreferencesPath),
		)
	}
	status := m.selectedStatus()
	lines = append(lines, "", accentStyle.Render("Platform Capabilities"))
	if status != nil && len(status.LocalMACAddresses) > 0 {
		lines = append(lines, fmt.Sprintf("Local interface discovery available (%d MACs)", len(status.LocalMACAddresses)))
	} else {
		lines = append(lines, "Local interface discovery unavailable")
	}
	if status != nil && status.IsConnected {
		lines = append(lines, "Wake-on-LAN available through client action menus")
	} else {
		lines = append(lines, "Wake-on-LAN requires an active router connection")
	}
	lines = append(lines, "Traffic inspection unavailable")
	return panelStyle.Render(strings.Join(lines, "\n"))
}

func (m *Model) renderOverlay() string {
	switch {
	case m.form != nil:
		return panelStyle.Render(m.form.View())
	case m.deleteConfirm != nil:
		return panelStyle.Render(fmt.Sprintf("Delete router %q?\n\nThis removes the router profile and its saved password.\n\nPress y to confirm or n/esc to cancel.", m.deleteConfirm.Name))
	case m.actionMenu != nil:
		lines := []string{
			fmt.Sprintf("Actions for %s (%s)", m.actionMenu.client.Name, m.actionMenu.client.MACAddress),
			"",
		}
		for index, option := range m.actionMenu.options {
			line := fmt.Sprintf("%s%s", selector(index == m.actionMenu.index), option.label)
			if index == m.actionMenu.index {
				line = selectedStyle.Render(line)
			}
			lines = append(lines, line)
		}
		lines = append(lines, "", mutedStyle.Render("Enter selects • esc cancels"))
		return panelStyle.Render(strings.Join(lines, "\n"))
	default:
		return ""
	}
}

func (m *Model) routers() []core.RouterProfile {
	if m.overview == nil {
		return nil
	}
	return m.overview.Routers
}

func (m *Model) currentRouter() *core.RouterProfile {
	routers := m.routers()
	if len(routers) == 0 || m.routerIndex >= len(routers) {
		return nil
	}
	return &routers[m.routerIndex]
}

func (m *Model) selectedStatus() *core.SelectedRouterStatus {
	if m.overview == nil {
		return nil
	}
	return m.overview.SelectedStatus
}

func (m *Model) filteredClients() []core.ClientDevice {
	status := m.selectedStatus()
	if status == nil {
		return nil
	}
	query := strings.ToLower(strings.TrimSpace(m.clientQuery))
	clients := make([]core.ClientDevice, 0, len(status.Clients))
	for _, client := range status.Clients {
		if query == "" || strings.Contains(strings.ToLower(client.Name), query) || strings.Contains(strings.ToLower(client.MACAddress), query) || strings.Contains(strings.ToLower(client.IPAddress), query) {
			clients = append(clients, client)
		}
	}
	sort.Slice(clients, func(i, j int) bool {
		if clientOnlineRank(clients[i]) != clientOnlineRank(clients[j]) {
			return clientOnlineRank(clients[i]) < clientOnlineRank(clients[j])
		}
		return strings.ToLower(clients[i].Name) < strings.ToLower(clients[j].Name)
	})
	if m.clientIndex >= len(clients) {
		m.clientIndex = max(0, len(clients)-1)
	}
	return clients
}

type policyClientRow struct {
	GroupLabel   string
	Client       core.ClientDevice
	IsLocalMatch bool
}

func (m *Model) policyClientRows() []policyClientRow {
	status := m.selectedStatus()
	if status == nil {
		return nil
	}
	groups := buildPolicyGroups(*status)
	filtered := make([]policyClientRow, 0)
	query := strings.ToLower(strings.TrimSpace(m.policyQuery))
	for _, group := range groups {
		for _, client := range group.Clients {
			if query != "" {
				groupMatches := strings.Contains(strings.ToLower(group.Label), query)
				clientMatches := strings.Contains(strings.ToLower(client.Name), query) || strings.Contains(strings.ToLower(client.MACAddress), query) || strings.Contains(strings.ToLower(client.IPAddress), query)
				if !groupMatches && !clientMatches {
					continue
				}
			}
			filtered = append(filtered, policyClientRow{
				GroupLabel:   group.Label,
				Client:       client,
				IsLocalMatch: isLocalDeviceClient(client, status.LocalMACAddresses),
			})
		}
	}
	if m.policyClientIdx >= len(filtered) {
		m.policyClientIdx = max(0, len(filtered)-1)
	}
	return filtered
}

func (m *Model) matchedClients() []core.ClientDevice {
	status := m.selectedStatus()
	if status == nil {
		return nil
	}
	matches := make([]core.ClientDevice, 0)
	for _, client := range status.Clients {
		if isLocalDeviceClient(client, status.LocalMACAddresses) {
			matches = append(matches, client)
		}
	}
	sort.Slice(matches, func(i, j int) bool {
		return strings.ToLower(matches[i].Name) < strings.ToLower(matches[j].Name)
	})
	if m.deviceClientIdx >= len(matches) {
		m.deviceClientIdx = max(0, len(matches)-1)
	}
	return matches
}

func (m *Model) startRouterForm(existing *core.RouterProfile) {
	var hasStoredPassword bool
	if existing != nil {
		hasStoredPassword = m.overview != nil && m.overview.PasswordStored[existing.ID]
	}
	m.form = newRouterForm(m, existing, hasStoredPassword)
}

func (m *Model) openActionMenu(client core.ClientDevice, source string) {
	status := m.selectedStatus()
	if status == nil {
		return
	}
	options := []actionOption{
		{label: "Apply default policy", request: core.SetDefaultPolicy(client.MACAddress)},
	}
	for _, policy := range status.Policies {
		options = append(options, actionOption{
			label:   "Apply policy: " + policy.Name,
			request: core.SetNamedPolicy(client.MACAddress, policy.Name),
		})
	}
	options = append(options,
		actionOption{label: "Block client", request: core.BlockClient(client.MACAddress)},
		actionOption{label: "Wake on LAN", request: core.WakeOnLAN(client.MACAddress)},
	)
	m.actionMenu = &clientActionMenu{
		client:  client,
		source:  source,
		options: options,
	}
}

func (m *Model) ensureIndices() {
	if m.overview == nil {
		return
	}
	if len(m.overview.Routers) == 0 {
		m.routerIndex = 0
		return
	}
	if m.routerIndex >= len(m.overview.Routers) {
		m.routerIndex = len(m.overview.Routers) - 1
	}
}

func (m *Model) storagePath() string {
	if m.overview != nil && m.overview.StoragePath != "" {
		return m.overview.StoragePath
	}
	if m.env != nil {
		return m.env.StoragePaths.RoutersPath
	}
	return ""
}

func (m *Model) contentMaxHeight() int {
	return max(12, m.height-8)
}

func (m *Model) clientsListCapacity() int {
	return max(1, (m.contentMaxHeight()-12)/4)
}

func (m *Model) policiesListCapacity() int {
	return max(1, (m.contentMaxHeight()-14)/2)
}

func listWindow(total, selected, capacity int) (int, int) {
	if total <= 0 {
		return 0, 0
	}
	if capacity <= 0 || capacity >= total {
		return 0, total
	}
	if selected < 0 {
		selected = 0
	}
	if selected >= total {
		selected = total - 1
	}
	start := selected - capacity/2
	if start < 0 {
		start = 0
	}
	end := start + capacity
	if end > total {
		end = total
		start = max(0, end-capacity)
	}
	return start, end
}

func (m *Model) shouldAutoRefresh() bool {
	if m.loading || m.refreshing || m.overview == nil || !m.overview.AutoRefreshEnable {
		return false
	}
	if m.form != nil || m.deleteConfirm != nil || m.actionMenu != nil || m.searchActive {
		return false
	}
	status := m.overview.SelectedStatus
	if status == nil || m.overview.SelectedRouterID == "" {
		return false
	}
	return m.section == core.SectionClients || m.section == core.SectionPolicies || m.section == core.SectionWireGuard || m.section == core.SectionThisDevice
}

func (m *Model) loadOverview() tea.Cmd {
	m.requestID++
	requestID := m.requestID
	return func() tea.Msg {
		overview, err := m.env.LoadOverview()
		return overviewLoadedMsg{id: requestID, overview: overview, err: err}
	}
}

type routerForm struct {
	parent            *Model
	existing          *core.RouterProfile
	hasStoredPassword bool
	inputs            []textinput.Model
	focus             int
}

func newRouterForm(parent *Model, existing *core.RouterProfile, hasStoredPassword bool) *routerForm {
	makeInput := func(placeholder, value string) textinput.Model {
		input := textinput.New()
		input.Placeholder = placeholder
		input.SetValue(value)
		input.CharLimit = 200
		return input
	}
	name := ""
	address := ""
	login := "admin"
	password := ""
	if existing != nil {
		name = existing.Name
		address = existing.Address
		login = existing.Login
	}
	inputs := []textinput.Model{
		makeInput("Name", name),
		makeInput("Address", address),
		makeInput("Login", login),
		makeInput("Password", password),
	}
	inputs[3].EchoMode = textinput.EchoPassword
	inputs[3].EchoCharacter = '•'
	return &routerForm{
		parent:            parent,
		existing:          existing,
		hasStoredPassword: hasStoredPassword,
		inputs:            inputs,
	}
}

func (f *routerForm) Focus() tea.Cmd {
	f.inputs[0].Focus()
	return textinput.Blink
}

func (f *routerForm) Update(msg tea.Msg, env *core.Environment) (tea.Model, tea.Cmd) {
	parent := f.parent
	switch key := msg.(type) {
	case tea.KeyMsg:
		switch key.String() {
		case "esc":
			parent.form = nil
			return parent, nil
		case "shift+tab", "up":
			f.blurAll()
			if f.focus > 0 {
				f.focus--
			}
			return parent, f.inputs[f.focus].Focus()
		case "tab", "down":
			f.blurAll()
			if f.focus < len(f.inputs)-1 {
				f.focus++
			}
			return parent, f.inputs[f.focus].Focus()
		case "ctrl+s":
			return f.submit(env)
		case "enter":
			if f.focus == len(f.inputs)-1 {
				return f.submit(env)
			}
			f.blurAll()
			f.focus++
			if f.focus >= len(f.inputs) {
				f.focus = len(f.inputs) - 1
			}
			return parent, f.inputs[f.focus].Focus()
		}
	}
	var cmd tea.Cmd
	f.inputs[f.focus], cmd = f.inputs[f.focus].Update(msg)
	return parent, cmd
}

func (f *routerForm) submit(env *core.Environment) (tea.Model, tea.Cmd) {
	parent := f.parent
	name := strings.TrimSpace(f.inputs[0].Value())
	address := strings.TrimSpace(f.inputs[1].Value())
	login := strings.TrimSpace(f.inputs[2].Value())
	password := f.inputs[3].Value()
	if name == "" || address == "" || login == "" {
		parent.errorMessage = "Name, address, and login are required."
		return parent, nil
	}
	if f.existing == nil && strings.TrimSpace(password) == "" {
		parent.errorMessage = "Password is required when adding a new router."
		return parent, nil
	}
	input := core.RouterFormInput{
		Name:     name,
		Address:  address,
		Login:    login,
		Password: password,
	}
	return parent, saveRouterCmd(env, input, f.existing)
}

func (f *routerForm) blurAll() {
	for i := range f.inputs {
		f.inputs[i].Blur()
	}
}

func (f *routerForm) View() string {
	title := "Add Router"
	passwordHint := "Stored separately from router metadata."
	if f.existing != nil {
		title = "Edit Router"
		if f.hasStoredPassword {
			passwordHint = "Leave password blank to keep the existing saved password."
		}
	}
	lines := []string{
		title,
		"",
		renderFormInput("Name", f.inputs[0], f.focus == 0),
		renderFormInput("Address", f.inputs[1], f.focus == 1),
		renderFormInput("Login", f.inputs[2], f.focus == 2),
		renderFormInput("Password", f.inputs[3], f.focus == 3),
		"",
		mutedStyle.Render(passwordHint),
		mutedStyle.Render("tab/shift+tab move • ctrl+s save • esc cancel"),
	}
	return strings.Join(lines, "\n")
}

type clientActionMenu struct {
	client  core.ClientDevice
	source  string
	options []actionOption
	index   int
}

type actionOption struct {
	label   string
	request core.ClientActionRequest
}

func renderFormInput(label string, input textinput.Model, focused bool) string {
	view := fmt.Sprintf("%s: %s", label, input.View())
	if focused {
		return selectedStyle.Render(view)
	}
	return view
}

func saveRouterCmd(env *core.Environment, input core.RouterFormInput, existing *core.RouterProfile) tea.Cmd {
	return func() tea.Msg {
		err := env.SaveRouter(input, existing)
		if err != nil {
			return routerSavedMsg{err: err}
		}
		message := "Router saved"
		if existing == nil {
			message = fmt.Sprintf("Added router %s", input.Name)
		} else {
			message = fmt.Sprintf("Updated router %s", input.Name)
		}
		return routerSavedMsg{message: message}
	}
}

func deleteRouterCmd(env *core.Environment, router core.RouterProfile) tea.Cmd {
	return func() tea.Msg {
		err := env.DeleteRouter(router)
		return routerDeletedMsg{err: err, message: fmt.Sprintf("Deleted %s", router.Name)}
	}
}

func selectRouterCmd(env *core.Environment, routerID string) tea.Cmd {
	return func() tea.Msg {
		err := env.SetSelectedRouterID(routerID)
		if err != nil {
			return routerSavedMsg{err: err}
		}
		return routerSavedMsg{message: "Selected router"}
	}
}

func clientActionCmd(env *core.Environment, status core.SelectedRouterStatus, request core.ClientActionRequest, label string) tea.Cmd {
	return func() tea.Msg {
		err := env.RunClientAction(status, request)
		return clientActionDoneMsg{err: err, message: label}
	}
}

func savePreferencesCmd(env *core.Environment, enabled bool) tea.Cmd {
	return func() tea.Msg {
		err := env.SetAutoRefreshEnabled(enabled)
		label := "Disabled auto-refresh"
		if enabled {
			label = "Enabled auto-refresh"
		}
		return preferencesSavedMsg{err: err, message: label}
	}
}

func tickCmd() tea.Cmd {
	return tea.Tick(autoRefreshInterval, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func nextSection(section core.AppSection) core.AppSection {
	switch section {
	case core.SectionSettings:
		return core.SectionRouters
	default:
		return section + 1
	}
}

func prevSection(section core.AppSection) core.AppSection {
	switch section {
	case core.SectionRouters:
		return core.SectionSettings
	default:
		return section - 1
	}
}

func selector(selected bool) string {
	if selected {
		return "› "
	}
	return "  "
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func availability(enabled bool) string {
	if enabled {
		return "available"
	}
	return "unavailable"
}

func clientOnlineRank(client core.ClientDevice) int {
	if client.ConnectionState == core.ClientConnectionOnline {
		return 0
	}
	return 1
}

type policyGroup struct {
	Label       string
	Description string
	Clients     []core.ClientDevice
}

func buildPolicyGroups(status core.SelectedRouterStatus) []policyGroup {
	policies := map[string]string{}
	for _, policy := range status.Policies {
		policies[policy.Name] = policy.Description
	}
	groups := map[string][]core.ClientDevice{
		"Default": {},
		"Blocked": {},
	}
	for _, policy := range status.Policies {
		groups[policy.Name] = []core.ClientDevice{}
	}
	for _, client := range status.Clients {
		switch {
		case client.IsDenied || client.Access == core.ClientAccessDeny:
			groups["Blocked"] = append(groups["Blocked"], client)
		case strings.TrimSpace(client.PolicyName) == "":
			groups["Default"] = append(groups["Default"], client)
		default:
			groups[client.PolicyName] = append(groups[client.PolicyName], client)
		}
	}
	order := []string{"Default", "Blocked"}
	for _, policy := range status.Policies {
		order = append(order, policy.Name)
	}
	seen := map[string]struct{}{}
	result := []policyGroup{}
	for _, label := range order {
		if _, ok := seen[label]; ok {
			continue
		}
		seen[label] = struct{}{}
		clients := groups[label]
		sort.Slice(clients, func(i, j int) bool {
			localI := isLocalDeviceClient(clients[i], status.LocalMACAddresses)
			localJ := isLocalDeviceClient(clients[j], status.LocalMACAddresses)
			if localI != localJ {
				return localI
			}
			if clientOnlineRank(clients[i]) != clientOnlineRank(clients[j]) {
				return clientOnlineRank(clients[i]) < clientOnlineRank(clients[j])
			}
			return strings.ToLower(clients[i].Name) < strings.ToLower(clients[j].Name)
		})
		description := policies[label]
		if label == "Default" {
			description = "Router default policy"
		}
		if label == "Blocked" {
			description = "Explicitly denied clients"
		}
		result = append(result, policyGroup{
			Label:       label,
			Description: description,
			Clients:     clients,
		})
	}
	return result
}

type policySummaryValues struct {
	NamedPolicyCount         int
	NamedPoliciesWithClients int
	AssignedClientCount      int
	DefaultClientCount       int
	BlockedClientCount       int
}

func policySummary(status *core.SelectedRouterStatus) policySummaryValues {
	values := policySummaryValues{NamedPolicyCount: len(status.Policies)}
	for _, group := range buildPolicyGroups(*status) {
		switch group.Label {
		case "Default":
			values.DefaultClientCount = len(group.Clients)
		case "Blocked":
			values.BlockedClientCount = len(group.Clients)
		default:
			if len(group.Clients) > 0 {
				values.NamedPoliciesWithClients++
			}
			values.AssignedClientCount += len(group.Clients)
		}
	}
	return values
}

type peerGroup struct {
	InterfaceName string
	Peers         []core.WireGuardPeer
}

func groupPeers(peers []core.WireGuardPeer) []peerGroup {
	grouped := map[string][]core.WireGuardPeer{}
	for _, peer := range peers {
		grouped[peer.InterfaceName] = append(grouped[peer.InterfaceName], peer)
	}
	names := make([]string, 0, len(grouped))
	for name := range grouped {
		names = append(names, name)
	}
	sort.Strings(names)
	result := make([]peerGroup, 0, len(names))
	for _, name := range names {
		result = append(result, peerGroup{InterfaceName: name, Peers: grouped[name]})
	}
	return result
}

func isLocalDeviceClient(client core.ClientDevice, localMACAddresses []string) bool {
	for _, mac := range localMACAddresses {
		if strings.EqualFold(client.MACAddress, mac) {
			return true
		}
	}
	return false
}

func defaultString(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}
