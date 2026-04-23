package core

import (
	"fmt"
	"net/url"
	"regexp"
	"strings"
	"time"
)

type RouterProfile struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Address     string    `json:"address"`
	Login       string    `json:"login"`
	NetworkIP   string    `json:"network_ip,omitempty"`
	KeenDNSURLs []string  `json:"keendns_urls,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type ClientConnectionState string

const (
	ClientConnectionOnline  ClientConnectionState = "online"
	ClientConnectionOffline ClientConnectionState = "offline"
	ClientConnectionUnknown ClientConnectionState = "unknown"
)

type ClientAccessMode string

const (
	ClientAccessAllow   ClientAccessMode = "allow"
	ClientAccessDeny    ClientAccessMode = "deny"
	ClientAccessUnknown ClientAccessMode = "unknown"
)

type ClientDevice struct {
	Name             string
	MACAddress       string
	IPAddress        string
	PolicyName       string
	Access           ClientAccessMode
	IsDenied         bool
	IsPermitted      bool
	Priority         *int
	ConnectionState  ClientConnectionState
	AccessPointName  string
	WiFiBand         string
	SignalRSSI       *int
	TxRateMbps       *int
	Encryption       string
	WirelessMode     string
	WiFiStandard     string
	SpatialStreams   *int
	ChannelWidthMHz  *int
	EthernetSpeedMps *int
	EthernetPort     *int
}

func (c ClientDevice) IsWireless() bool {
	return strings.TrimSpace(c.AccessPointName) != ""
}

type VpnPolicy struct {
	Name        string
	Description string
}

type WireGuardPeer struct {
	InterfaceName string
	PeerName      string
	AllowedIPs    []string
	Endpoint      string
	IsEnabled     bool
}

type ConnectionTargetKind string

const (
	ConnectionDirect       ConnectionTargetKind = "direct"
	ConnectionLocalNetwork ConnectionTargetKind = "localNetwork"
	ConnectionKeenDNS      ConnectionTargetKind = "keendns"
)

type ConnectionTarget struct {
	Kind ConnectionTargetKind
	URI  *url.URL
}

type SelectedRouterStatus struct {
	Router             RouterProfile
	CheckedAt          time.Time
	HasStoredPassword  bool
	ConnectionTarget   *ConnectionTarget
	IsConnected        bool
	LocalMACAddresses  []string
	Clients            []ClientDevice
	Policies           []VpnPolicy
	WireGuardPeers     []WireGuardPeer
	ClientCount        int
	OnlineClientCount  int
	PolicyCount        int
	WireGuardPeerCount int
	ErrorMessage       string
}

type Preferences struct {
	AutoRefreshEnabled bool `json:"auto_refresh_enabled"`
}

func (p Preferences) WithAutoRefreshEnabled(enabled bool) Preferences {
	p.AutoRefreshEnabled = enabled
	return p
}

type StoragePaths struct {
	BaseDir         string
	RoutersPath     string
	SecretsPath     string
	PreferencesPath string
}

type AppSection int

const (
	SectionRouters AppSection = iota
	SectionClients
	SectionPolicies
	SectionWireGuard
	SectionThisDevice
	SectionSettings
)

func (s AppSection) Label() string {
	switch s {
	case SectionRouters:
		return "Routers"
	case SectionClients:
		return "Clients"
	case SectionPolicies:
		return "Policies"
	case SectionWireGuard:
		return "WireGuard"
	case SectionThisDevice:
		return "This Device"
	case SectionSettings:
		return "Settings"
	default:
		return "Unknown"
	}
}

type RouterOverview struct {
	StoragePath       string
	Routers           []RouterProfile
	SelectedRouterID  string
	PasswordStored    map[string]bool
	SelectedStatus    *SelectedRouterStatus
	AutoRefreshEnable bool
}

func RouterIDFor(name, address string, routers []RouterProfile) string {
	source := strings.ToLower(strings.TrimSpace(name + "-" + address))
	re := regexp.MustCompile(`[^a-z0-9]+`)
	base := strings.Trim(re.ReplaceAllString(source, "-"), "-")
	if base == "" {
		base = fmt.Sprintf("router-%d", time.Now().UnixMicro())
	}
	used := make(map[string]struct{}, len(routers))
	for _, router := range routers {
		used[router.ID] = struct{}{}
	}
	candidate := base
	suffix := 2
	for {
		if _, exists := used[candidate]; !exists {
			return candidate
		}
		candidate = fmt.Sprintf("%s-%d", base, suffix)
		suffix++
	}
}

type RouterAPIError struct {
	Message string
}

func (e RouterAPIError) Error() string {
	return e.Message
}

type RouterAuthenticationError struct {
	Message string
}

func (e RouterAuthenticationError) Error() string {
	if e.Message == "" {
		return "authentication failed"
	}
	return e.Message
}

type RouterRequestError struct {
	StatusCode int
	Message    string
}

func (e RouterRequestError) Error() string {
	return e.Message
}

type RouterParseError struct {
	Message string
}

func (e RouterParseError) Error() string {
	return e.Message
}

type ClientActionKind string

const (
	ClientActionSetDefaultPolicy ClientActionKind = "setDefaultPolicy"
	ClientActionSetNamedPolicy   ClientActionKind = "setNamedPolicy"
	ClientActionBlock            ClientActionKind = "block"
	ClientActionWakeOnLAN        ClientActionKind = "wakeOnLan"
)

type ClientActionRequest struct {
	Kind       ClientActionKind
	MACAddress string
	PolicyName string
}

func SetDefaultPolicy(mac string) ClientActionRequest {
	return ClientActionRequest{Kind: ClientActionSetDefaultPolicy, MACAddress: mac}
}

func SetNamedPolicy(mac, policyName string) ClientActionRequest {
	return ClientActionRequest{
		Kind:       ClientActionSetNamedPolicy,
		MACAddress: mac,
		PolicyName: policyName,
	}
}

func BlockClient(mac string) ClientActionRequest {
	return ClientActionRequest{Kind: ClientActionBlock, MACAddress: mac}
}

func WakeOnLAN(mac string) ClientActionRequest {
	return ClientActionRequest{Kind: ClientActionWakeOnLAN, MACAddress: mac}
}
