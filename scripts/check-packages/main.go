package main

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#f5c2e7")).Padding(0, 1)
	groupStyle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#89b4fa")).Padding(0, 1)
	pacmanLabel   = lipgloss.NewStyle().Foreground(lipgloss.Color("#89b4fa")).Width(10).Align(lipgloss.Left)
	aurLabel      = lipgloss.NewStyle().Foreground(lipgloss.Color("#f9e2af")).Width(10).Align(lipgloss.Left)
	pipxLabel     = lipgloss.NewStyle().Foreground(lipgloss.Color("#94e2d5")).Width(10).Align(lipgloss.Left)
	missingLabel  = lipgloss.NewStyle().Foreground(lipgloss.Color("#f38ba8")).Width(8).Align(lipgloss.Left)
	okLabel       = lipgloss.NewStyle().Foreground(lipgloss.Color("#a6e3a1")).Width(8).Align(lipgloss.Left)
	cursorStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#cba6f7"))
	footerStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#6c7086")).Padding(0, 1)
	checkboxOn    = lipgloss.NewStyle().Foreground(lipgloss.Color("#a6e3a1")).Render("[x] ")
	checkboxOff   = lipgloss.NewStyle().Foreground(lipgloss.Color("#585b70")).Render("[ ] ")
	doneCheckbox  = lipgloss.NewStyle().Foreground(lipgloss.Color("#585b70")).Render("[✓] ")
	loadingStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#89b4fa"))
	barFilled     = lipgloss.NewStyle().Foreground(lipgloss.Color("#a6e3a1"))
	barEmpty      = lipgloss.NewStyle().Foreground(lipgloss.Color("#313244"))
	checkingStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#f5c2e7"))
	grayStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("#585b70"))
)

type pkgInfo struct {
	Name      string
	Group     string
	Installed bool
	InPacman  bool
	InPipx    bool
	Selected  bool
}

type installMsg struct {
	Pacman []string
	Aur    []string
	Pipx   []string
}

// scanDoneMsg is sent when a package scan completes
type scanDoneMsg struct {
	idx       int
	installed bool
	inPacman  bool
}

// scanTickMsg advances scanning to next package
type scanTickMsg struct{}

var packageDB = []struct{ Name, Group string; IsPipx bool }{
	// Core
	{Name: "hyprland", Group: "core"}, {Name: "hyprpaper", Group: "core"}, {Name: "hypridle", Group: "core"},
	{Name: "hyprlock", Group: "core"}, {Name: "hyprpolkitagent", Group: "core"}, {Name: "waybar", Group: "core"},
	{Name: "swaync", Group: "core"}, {Name: "rofi", Group: "core"}, {Name: "walker", Group: "core"},
	{Name: "grim", Group: "core"}, {Name: "slurp", Group: "core"}, {Name: "wl-clipboard", Group: "core"},
	{Name: "cliphist", Group: "core"}, {Name: "satty", Group: "core"}, {Name: "ghostty", Group: "core"},
	{Name: "dolphin", Group: "core"}, {Name: "fcitx5", Group: "core"}, {Name: "fcitx5-unikey", Group: "core"},
	{Name: "fcitx5-configtool", Group: "core"}, {Name: "blueman", Group: "core"}, {Name: "easyeffects", Group: "core"},
	{Name: "xdg-desktop-portal-hyprland", Group: "core"}, {Name: "xdg-desktop-portal-gtk", Group: "core"},
	{Name: "xdg-desktop-portal", Group: "core"}, {Name: "qt6-wayland", Group: "core"}, {Name: "brightnessctl", Group: "core"},
	{Name: "stow", Group: "core"}, {Name: "jq", Group: "core"}, {Name: "gawk", Group: "core"}, {Name: "curl", Group: "core"},
	{Name: "pacman-contrib", Group: "core"}, {Name: "flatpak", Group: "core"}, {Name: "fzf", Group: "core"},
	{Name: "waypaper", Group: "core"},

	// Optional
	{Name: "pavucontrol", Group: "optional"}, {Name: "mission-center", Group: "optional"}, {Name: "qt6ct", Group: "optional"},
	{Name: "wttr-bin", Group: "optional"}, {Name: "bibata-cursor-git", Group: "optional"},
	{Name: "mpv", Group: "optional"}, {Name: "mpv-mpris", Group: "optional"}, {Name: "webtorrent-cli", Group: "optional"},
	{Name: "fisher", Group: "optional"}, {Name: "neovim", Group: "optional"}, {Name: "yazi", Group: "optional"},
	{Name: "nwg-look", Group: "optional"}, {Name: "nwg-displays", Group: "optional"}, {Name: "entr", Group: "optional"},
	{Name: "gtk-engine-murrine", Group: "optional"}, {Name: "sesh-bin", Group: "optional"},
	{Name: "tmux", Group: "optional"}, {Name: "python-libtmux", Group: "optional"}, {Name: "tmuxp", Group: "optional"},
	{Name: "python-pipx", Group: "optional"},
	{Name: "subliminal", Group: "optional", IsPipx: true}, {Name: "streamlink", Group: "optional", IsPipx: true},

	// User apps
	{Name: "zen-browser-bin", Group: "userapp"}, {Name: "google-chrome", Group: "userapp"},
	{Name: "ferdium", Group: "userapp"},
	{Name: "bitwarden", Group: "userapp"}, {Name: "dbeaver", Group: "userapp"},
	{Name: "nextcloud-client", Group: "userapp"},
}

type model struct {
	pkgs           []pkgInfo
	cursor         int
	scrollOff      int
	pkgLineNums    []int // line number for each package (for scrolling)
	showMissingOnly bool
	scanning       bool
	scanIdx        int
	scanTotal      int
	install        *installMsg
	aurHelper      string
	width          int
	height         int
	quitting       bool
	err            error
}

func findAurHelper() string {
	for _, h := range []string{"paru", "yay"} {
		if _, err := exec.LookPath(h); err == nil {
			return h
		}
	}
	return ""
}

// scanOnePkg runs pacman -Q and pacman -Si for a single package
func scanOnePkg(idx int) tea.Cmd {
	return func() tea.Msg {
		p := packageDB[idx]
		var installed, inPacman bool
		if p.IsPipx {
			out, _ := exec.Command("pipx", "list").Output()
			for _, line := range strings.Split(string(out), "\n") {
				if strings.Contains(line, "package "+p.Name+" ") {
					installed = true
					break
				}
			}
			inPacman = false
		} else {
			if exec.Command("pacman", "-Q", p.Name).Run() == nil {
				installed = true
			}
			if exec.Command("pacman", "-Si", p.Name).Run() == nil {
				inPacman = true
			}
		}
		time.Sleep(5 * time.Millisecond)
		return scanDoneMsg{idx: idx, installed: installed, inPacman: inPacman}
	}
}

// nextScan sends a tick to advance to next package
func nextScan() tea.Cmd {
	return func() tea.Msg {
		return scanTickMsg{}
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		scanOnePkg(0),
		nextScan(),
	)
}

func (m *model) nextSelectable(delta int) {
	n := len(m.pkgs)
	if n == 0 {
		return
	}
	for i := 0; i < n; i++ {
		m.cursor = (m.cursor + delta + n) % n
		if !m.showMissingOnly || !m.pkgs[m.cursor].Installed {
			return
		}
	}
}

// scrollIntoView adjusts scrollOff so cursor is visible
func (m *model) scrollIntoView() {
	if m.height < 5 || m.cursor >= len(m.pkgLineNums) {
		return
	}
	cursorLine := m.pkgLineNums[m.cursor]
	headerLines := 2
	footerLines := 2
	visible := m.height - headerLines - footerLines
	if visible < 1 {
		visible = 1
	}

	top := m.scrollOff
	bottom := m.scrollOff + visible - 1

	if cursorLine < top {
		m.scrollOff = cursorLine
	} else if cursorLine > bottom {
		m.scrollOff = cursorLine - visible + 1
	}
	if m.scrollOff < 0 {
		m.scrollOff = 0
	}
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case scanDoneMsg:
		m.scanIdx = msg.idx
		// init the pkgInfo slot
		for len(m.pkgs) <= msg.idx {
			m.pkgs = append(m.pkgs, pkgInfo{})
		}
		p := packageDB[msg.idx]
		m.pkgs[msg.idx] = pkgInfo{
			Name:      p.Name,
			Group:     p.Group,
			Installed: msg.installed,
			InPacman:  msg.inPacman,
			InPipx:    p.IsPipx,
			Selected:  false,
		}
		// if all scanned, finish
		if msg.idx+1 >= len(packageDB) {
			m.scanning = false
			// sort
			sort.SliceStable(m.pkgs, func(i, j int) bool {
				gi, gj := m.pkgs[i].Group, m.pkgs[j].Group
				order := map[string]int{"core": 0, "optional": 1, "userapp": 2}
				if gi != gj {
					return order[gi] < order[gj]
				}
				return m.pkgs[i].Name < m.pkgs[j].Name
			})
			// cursor to first missing
			for i, p := range m.pkgs {
				if !p.Installed {
					m.cursor = i
					break
				}
			}
			// pre-compute line positions for scrolling
			_, m.pkgLineNums = m.buildContentLines()
			return m, nil
		}
		// scan next
		return m, nextScan()

	case scanTickMsg:
		// on tick, start scanning the next package
		if m.scanIdx+1 < len(packageDB) {
			return m, scanOnePkg(m.scanIdx + 1)
		}
		return m, nil

	case tea.KeyMsg:
		if m.install != nil {
			return m, tea.Quit
		}
		// ignore keys while scanning
		if m.scanning {
			return m, nil
		}

		switch msg.String() {
		case "q", "ctrl+c", "esc":
			m.quitting = true
			return m, tea.Quit

		case "j", "down":
			m.nextSelectable(1)
			m.scrollIntoView()

		case "k", "up":
			m.nextSelectable(-1)
			m.scrollIntoView()

		case " ", "enter":
			if len(m.pkgs) > 0 && m.cursor < len(m.pkgs) {
				i := m.cursor
				if !m.pkgs[i].Installed {
					m.pkgs[i].Selected = !m.pkgs[i].Selected
					m.nextSelectable(1)
					m.scrollIntoView()
				}
			}

		case "ctrl+a":
			for i := range m.pkgs {
				if !m.pkgs[i].Installed {
					m.pkgs[i].Selected = true
				}
			}

		case "ctrl+d":
			for i := range m.pkgs {
				m.pkgs[i].Selected = false
			}

		case "m":
			m.showMissingOnly = !m.showMissingOnly
			_, m.pkgLineNums = m.buildContentLines()
			// reset cursor to first visible
			for i := range m.pkgs {
				if !m.showMissingOnly || !m.pkgs[i].Installed {
					m.cursor = i
					break
				}
			}
			m.scrollOff = 0

		case "i":
			var pacmanPkgs, aurPkgs, pipxPkgs []string
			for _, p := range m.pkgs {
				if !p.Selected || p.Installed {
					continue
				}
				if p.InPipx {
					pipxPkgs = append(pipxPkgs, p.Name)
				} else if p.InPacman {
					pacmanPkgs = append(pacmanPkgs, p.Name)
				} else {
					aurPkgs = append(aurPkgs, p.Name)
				}
			}
			if len(pacmanPkgs) == 0 && len(aurPkgs) == 0 && len(pipxPkgs) == 0 {
				return m, nil
			}
			m.install = &installMsg{Pacman: pacmanPkgs, Aur: aurPkgs, Pipx: pipxPkgs}
			return m, tea.Quit
		}
	}

	return m, nil
}

func progressBar(current, total, width int) string {
	if total == 0 {
		return ""
	}
	ratio := float64(current+1) / float64(total)
	filled := int(ratio * float64(width))
	if filled > width {
		filled = width
	}
	bar := ""
	for i := 0; i < filled; i++ {
		bar += barFilled.Render("█")
	}
	for i := filled; i < width; i++ {
		bar += barEmpty.Render("█")
	}
	return bar
}

func (m model) scanningView() string {
	title := titleStyle.Render("check-packages  ")
	titleLine := lipgloss.PlaceHorizontal(m.width, lipgloss.Center, title)

	var b strings.Builder
	b.WriteString(titleLine + "\n\n\n")

	if m.scanTotal == 0 {
		m.scanTotal = len(packageDB)
	}

	bar := progressBar(m.scanIdx, m.scanTotal, 40)
	status := fmt.Sprintf("  Scanning packages...  %d/%d", m.scanIdx+1, m.scanTotal)
	b.WriteString(checkingStyle.Render(status) + "\n\n")

	centered := lipgloss.PlaceHorizontal(m.width, lipgloss.Center, bar)
	b.WriteString(centered + "\n\n")

	if m.scanIdx >= 0 && m.scanIdx < len(packageDB) {
		name := packageDB[m.scanIdx].Name
		b.WriteString(grayStyle.Render("  Checking: " + name) + "\n")
	}

	return b.String()
}

// buildContentLines returns all content lines and maps each package to its line number
func (m *model) buildContentLines() (lines []string, pkgNums []int) {
	pkgNums = make([]int, len(m.pkgs))
	lineNum := 0

	groups := map[string][]int{"core": nil, "optional": nil, "userapp": nil}
	for i, p := range m.pkgs {
		groups[p.Group] = append(groups[p.Group], i)
	}
	groupOrder := []struct{ key, label string }{
		{"core", "Core packages"},
		{"optional", "Optional packages"},
		{"userapp", "User apps"},
	}

	for _, g := range groupOrder {
		idxs := groups[g.key]
		if len(idxs) == 0 {
			continue
		}

		missing := 0
		visibleInGroup := 0
		for _, i := range idxs {
			if !m.pkgs[i].Installed {
				missing++
			}
			if !m.showMissingOnly || !m.pkgs[i].Installed {
				visibleInGroup++
			}
		}
		if visibleInGroup == 0 {
			continue
		}

		lines = append(lines, groupStyle.Render(g.label))
		lineNum++

		for _, i := range idxs {
			p := m.pkgs[i]
			if m.showMissingOnly && p.Installed {
				continue
			}
			pkgNums[i] = lineNum

			var cb string
			switch {
			case p.Installed:
				cb = doneCheckbox
			case p.Selected:
				cb = checkboxOn
			default:
				cb = checkboxOff
			}
			var src string
			if p.InPipx {
				src = pipxLabel.Render("pipx")
			} else if p.InPacman {
				src = pacmanLabel.Render("pacman")
			} else {
				src = aurLabel.Render("AUR")
			}
			var status string
			if p.Installed {
				status = okLabel.Render("ok")
			} else {
				status = missingLabel.Render("missing")
			}

			li := fmt.Sprintf(" %s %-30s %s %s", cb, p.Name, src, status)
			if i == m.cursor {
				li = cursorStyle.Render(">") + li[1:]
			} else {
				li = " " + li[1:]
			}
			lines = append(lines, li)
			lineNum++
		}
		summary := fmt.Sprintf(" %d/%d installed\n", len(idxs)-missing, len(idxs))
		lines = append(lines, summary)
		lineNum++
	}
	return lines, pkgNums
}

func (m model) listView() string {
	title := titleStyle.Render("check-packages  ")
	titleLine := lipgloss.PlaceHorizontal(m.width, lipgloss.Center, title)

	content, _ := m.buildContentLines()

	visible := m.height - 4
	if visible < 1 {
		visible = 1
	}

	start := m.scrollOff
	end := start + visible
	if end > len(content) {
		end = len(content)
	}
	if start > 0 && start > len(content)-visible {
		start = len(content) - visible
	}
	if start < 0 {
		start = 0
	}

	var pacmanCount, aurCount, pipxCount int
	for _, p := range m.pkgs {
		if p.Selected && !p.Installed {
			if p.InPipx {
				pipxCount++
			} else if p.InPacman {
				pacmanCount++
			} else {
				aurCount++
			}
		}
	}

	filterLabel := ""
	if m.showMissingOnly {
		filterLabel = " [missing only]"
	}
	footer := footerStyle.Render(fmt.Sprintf(
		"j/k:nav  space:toggle  ctrl+a:all  ctrl+d:none  m:filter%s  i:install (%dp/%da/%dx)  q:quit",
		filterLabel, pacmanCount, aurCount, pipxCount,
	))
	footerLine := lipgloss.PlaceHorizontal(m.width, lipgloss.Center, footer)

	var b strings.Builder
	b.WriteString(titleLine + "\n\n")
	for _, l := range content[start:end] {
		b.WriteString(l + "\n")
	}
	b.WriteString("\n" + footerLine)

	return b.String()
}

func (m model) View() string {
	if m.quitting && m.install == nil {
		return ""
	}
	if m.scanning {
		return m.scanningView()
	}
	return m.listView()
}

func doInstall(im installMsg, helper string) {
	if len(im.Pacman) > 0 {
		fmt.Printf("\n→ Installing %d packages via pacman...\n", len(im.Pacman))
		args := append([]string{"pacman", "-S", "--needed", "--noconfirm"}, im.Pacman...)
		cmd := exec.Command("sudo", args...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		if err := cmd.Run(); err != nil {
			fmt.Printf("pacman exited with error: %v\n", err)
		}
	}
	if len(im.Aur) > 0 {
		if helper == "" {
			fmt.Printf("\n⚠  No AUR helper (paru/yay). Skipping: %s\n", strings.Join(im.Aur, ", "))
		} else {
			fmt.Printf("\n→ Installing %d packages via %s...\n", len(im.Aur), helper)
			args := append([]string{"-S", "--needed", "--noconfirm"}, im.Aur...)
			cmd := exec.Command(helper, args...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Stdin = os.Stdin
			if err := cmd.Run(); err != nil {
				fmt.Printf("%s exited with error: %v\n", helper, err)
			}
		}
	}
	if len(im.Pipx) > 0 {
		for _, pkg := range im.Pipx {
			fmt.Printf("\n→ Installing %s via pipx...\n", pkg)
			cmd := exec.Command("pipx", "install", pkg)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Stdin = os.Stdin
			if err := cmd.Run(); err != nil {
				fmt.Printf("pipx install %s failed: %v\n", pkg, err)
			}
		}
	}
}

func main() {
	m := model{
		scanning:  true,
		scanIdx:   -1,
		aurHelper: findAurHelper(),
		width:     80,
		height:    40,
	}

	p := tea.NewProgram(&m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if fm, ok := final.(*model); ok && fm.install != nil {
		doInstall(*fm.install, fm.aurHelper)
		fmt.Println("\nDone.")
	}
}
