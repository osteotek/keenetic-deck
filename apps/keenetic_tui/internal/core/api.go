package core

import (
	"bytes"
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

type RouterAPI interface {
	Authenticate(baseURI *url.URL, login, password string) (bool, error)
	GetKeenDNSURLs(baseURI *url.URL, login, password string) ([]string, error)
	GetNetworkIP(baseURI *url.URL, login, password string) (string, error)
	GetPolicies(baseURI *url.URL, login, password string) ([]VpnPolicy, error)
	GetClients(baseURI *url.URL, login, password string) ([]ClientDevice, error)
	ApplyPolicy(baseURI *url.URL, login, password, macAddress string, policyName *string) error
	BlockClient(baseURI *url.URL, login, password, macAddress string) error
	WakeOnLAN(baseURI *url.URL, login, password, macAddress string) error
	GetWireGuardPeers(baseURI *url.URL, login, password string) ([]WireGuardPeer, error)
}

type KeeneticAPI struct {
	client                *http.Client
	authenticationTimeout time.Duration
	requestTimeout        time.Duration
}

func NewKeeneticAPI() *KeeneticAPI {
	return &KeeneticAPI{
		client:                &http.Client{},
		authenticationTimeout: 2 * time.Second,
		requestTimeout:        5 * time.Second,
	}
}

func (k *KeeneticAPI) Authenticate(baseURI *url.URL, login, password string) (bool, error) {
	session := newSession(k.client, normalizeBaseURL(baseURI), login, password, k.authenticationTimeout, k.requestTimeout)
	return session.authenticate()
}

func (k *KeeneticAPI) GetKeenDNSURLs(baseURI *url.URL, login, password string) ([]string, error) {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return nil, err
	}
	response, err := session.get("rci/ip/http/ssl/acme/list/certificate")
	if err != nil {
		return nil, err
	}
	payload, err := decodeJSON(response.Body)
	if err != nil {
		return nil, err
	}
	items, ok := payload.([]any)
	if !ok {
		return nil, RouterParseError{Message: "expected list for KeenDNS certificate list"}
	}
	urls := make([]string, 0, len(items))
	for _, item := range items {
		entry, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if domain, ok := entry["domain"].(string); ok && domain != "" {
			urls = append(urls, domain)
		}
	}
	return urls, nil
}

func (k *KeeneticAPI) GetNetworkIP(baseURI *url.URL, login, password string) (string, error) {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return "", err
	}
	response, err := session.get("rci/sc/interface/Bridge0/ip/address")
	if err != nil {
		return "", err
	}
	payload, err := decodeJSON(response.Body)
	if err != nil {
		return "", err
	}
	entry, ok := payload.(map[string]any)
	if !ok {
		return "", RouterParseError{Message: "expected map for network IP payload"}
	}
	value, _ := entry["address"].(string)
	return value, nil
}

func (k *KeeneticAPI) GetPolicies(baseURI *url.URL, login, password string) ([]VpnPolicy, error) {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return nil, err
	}
	response, err := session.get("rci/show/rc/ip/policy")
	if err != nil {
		return nil, err
	}
	payload, err := decodeJSON(response.Body)
	if err != nil {
		return nil, err
	}
	items, ok := payload.(map[string]any)
	if !ok {
		return nil, RouterParseError{Message: "expected map for policy list"}
	}
	keys := make([]string, 0, len(items))
	for key := range items {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	policies := make([]VpnPolicy, 0, len(keys))
	for _, key := range keys {
		description := key
		if entry, ok := items[key].(map[string]any); ok {
			if value, ok := entry["description"].(string); ok && value != "" {
				description = value
			}
		}
		policies = append(policies, VpnPolicy{Name: key, Description: description})
	}
	return policies, nil
}

func (k *KeeneticAPI) GetClients(baseURI *url.URL, login, password string) ([]ClientDevice, error) {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return nil, err
	}
	clientsResponse, err := session.get("rci/show/ip/hotspot/host")
	if err != nil {
		return nil, err
	}
	policiesResponse, err := session.get("rci/show/rc/ip/hotspot/host")
	if err != nil {
		return nil, err
	}

	clientsPayload, err := decodeJSON(clientsResponse.Body)
	if err != nil {
		return nil, err
	}
	clientsList, ok := clientsPayload.([]any)
	if !ok {
		return nil, RouterParseError{Message: "expected list for client list"}
	}
	policiesPayload, err := decodeJSON(policiesResponse.Body)
	if err != nil {
		return nil, err
	}
	policiesList, ok := policiesPayload.([]any)
	if !ok {
		return nil, RouterParseError{Message: "expected list for client policies"}
	}

	accumulators := map[string]clientAccumulator{}
	for _, item := range clientsList {
		entry, ok := item.(map[string]any)
		if !ok {
			continue
		}
		mac := normalizeMAC(asString(entry["mac"]))
		if mac == "" {
			continue
		}
		accumulators[mac] = clientAccumulator{
			Name:       defaultString(asString(entry["name"]), "Unknown"),
			IPAddress:  asString(entry["ip"]),
			MACAddress: mac,
			RawData:    entry,
		}
	}

	for _, item := range policiesList {
		entry, ok := item.(map[string]any)
		if !ok {
			continue
		}
		mac := normalizeMAC(asString(entry["mac"]))
		if mac == "" {
			continue
		}
		current, exists := accumulators[mac]
		if !exists {
			current = clientAccumulator{Name: "Unknown", MACAddress: mac}
		}
		current.PolicyName = asString(entry["policy"])
		current.Access = parseAccessMode(asString(entry["access"]))
		current.IsDenied = asBool(entry["deny"])
		current.IsPermitted = asBool(entry["permit"])
		current.Priority = asIntPtr(entry["priority"])
		accumulators[mac] = current
	}

	keys := make([]string, 0, len(accumulators))
	for key := range accumulators {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	clients := make([]ClientDevice, 0, len(keys))
	for _, key := range keys {
		client := accumulators[key]
		state := ClientConnectionOffline
		if isOnline(client.RawData) {
			state = ClientConnectionOnline
		}
		clients = append(clients, ClientDevice{
			Name:             client.Name,
			MACAddress:       client.MACAddress,
			IPAddress:        client.IPAddress,
			PolicyName:       client.PolicyName,
			Access:           client.Access,
			IsDenied:         client.IsDenied,
			IsPermitted:      client.IsPermitted,
			Priority:         client.Priority,
			ConnectionState:  state,
			AccessPointName:  asString(pickClientField(client.RawData, "ap")),
			WiFiBand:         wifiBandFor(asString(pickClientField(client.RawData, "ap"))),
			SignalRSSI:       asIntPtr(pickClientField(client.RawData, "rssi")),
			TxRateMbps:       asIntPtr(pickClientField(client.RawData, "txrate")),
			Encryption:       asString(pickClientField(client.RawData, "security")),
			WirelessMode:     asString(pickClientField(client.RawData, "mode")),
			WiFiStandard:     formatWiFiStandard(pickClientField(client.RawData, "_11")),
			SpatialStreams:   asIntPtr(pickClientField(client.RawData, "txss")),
			ChannelWidthMHz:  asIntPtr(pickClientField(client.RawData, "ht")),
			EthernetSpeedMps: asIntPtr(client.RawData["speed"]),
			EthernetPort:     asIntPtr(client.RawData["port"]),
		})
	}
	return clients, nil
}

func (k *KeeneticAPI) ApplyPolicy(baseURI *url.URL, login, password, macAddress string, policyName *string) error {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return err
	}
	policyValue := any(false)
	if policyName != nil && strings.TrimSpace(*policyName) != "" {
		policyValue = *policyName
	}
	_, err = session.post("rci/ip/hotspot/host", map[string]any{
		"mac":      macAddress,
		"policy":   policyValue,
		"permit":   true,
		"schedule": false,
	})
	return err
}

func (k *KeeneticAPI) BlockClient(baseURI *url.URL, login, password, macAddress string) error {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return err
	}
	_, err = session.post("rci/ip/hotspot/host", map[string]any{
		"mac":      macAddress,
		"schedule": false,
		"deny":     true,
	})
	return err
}

func (k *KeeneticAPI) WakeOnLAN(baseURI *url.URL, login, password, macAddress string) error {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return err
	}
	_, err = session.post("rci/ip/hotspot/wake", map[string]any{
		"mac": macAddress,
	})
	return err
}

func (k *KeeneticAPI) GetWireGuardPeers(baseURI *url.URL, login, password string) ([]WireGuardPeer, error) {
	session, err := k.authenticateSession(baseURI, login, password)
	if err != nil {
		return nil, err
	}
	response, err := session.get("rci/show/interface/Wireguard")
	if err != nil {
		var requestErr RouterRequestError
		if ok := asRequestError(err, &requestErr); ok {
			return []WireGuardPeer{}, nil
		}
		return nil, err
	}
	payload, err := decodeJSON(response.Body)
	if err != nil {
		return nil, err
	}
	interfaces, ok := payload.(map[string]any)
	if !ok {
		return nil, RouterParseError{Message: "expected map for WireGuard interfaces"}
	}
	peers := []WireGuardPeer{}
	interfaceNames := make([]string, 0, len(interfaces))
	for name := range interfaces {
		interfaceNames = append(interfaceNames, name)
	}
	sort.Strings(interfaceNames)
	for _, interfaceName := range interfaceNames {
		interfaceData, ok := interfaces[interfaceName].(map[string]any)
		if !ok {
			continue
		}
		peerMap, ok := interfaceData["peer"].(map[string]any)
		if !ok {
			continue
		}
		peerNames := make([]string, 0, len(peerMap))
		for name := range peerMap {
			peerNames = append(peerNames, name)
		}
		sort.Strings(peerNames)
		for _, peerName := range peerNames {
			peer := WireGuardPeer{
				InterfaceName: interfaceName,
				PeerName:      peerName,
				IsEnabled:     true,
			}
			if peerData, ok := peerMap[peerName].(map[string]any); ok {
				peer.AllowedIPs = parseStringList(firstValue(peerData, "allowed_ips", "allowed-ips"))
				peer.Endpoint = asString(peerData["endpoint"])
				if value, ok := peerData["enabled"].(bool); ok {
					peer.IsEnabled = value
				}
			}
			peers = append(peers, peer)
		}
	}
	return peers, nil
}

func (k *KeeneticAPI) authenticateSession(baseURI *url.URL, login, password string) (*keeneticSession, error) {
	session := newSession(k.client, normalizeBaseURL(baseURI), login, password, k.authenticationTimeout, k.requestTimeout)
	ok, err := session.authenticate()
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, RouterAuthenticationError{}
	}
	return session, nil
}

type keeneticSession struct {
	client                *http.Client
	baseURI               *url.URL
	login                 string
	password              string
	authenticationTimeout time.Duration
	requestTimeout        time.Duration
	cookies               map[string]string
}

func newSession(client *http.Client, baseURI *url.URL, login, password string, authTimeout, requestTimeout time.Duration) *keeneticSession {
	return &keeneticSession{
		client:                client,
		baseURI:               baseURI,
		login:                 login,
		password:              password,
		authenticationTimeout: authTimeout,
		requestTimeout:        requestTimeout,
		cookies:               map[string]string{},
	}
}

func (s *keeneticSession) authenticate() (bool, error) {
	initial, err := s.send(http.MethodGet, "auth", nil, s.authenticationTimeout, false)
	if err != nil {
		return false, err
	}
	defer initial.Body.Close()
	if initial.StatusCode == http.StatusOK {
		return true, nil
	}
	if initial.StatusCode != http.StatusUnauthorized {
		return false, nil
	}
	realm := initial.Header.Get("x-ndm-realm")
	challenge := initial.Header.Get("x-ndm-challenge")
	if realm == "" || challenge == "" {
		return false, nil
	}

	md5Bytes := md5.Sum([]byte(fmt.Sprintf("%s:%s:%s", s.login, realm, s.password)))
	md5Digest := hex.EncodeToString(md5Bytes[:])
	shaBytes := sha256.Sum256([]byte(challenge + md5Digest))
	passwordDigest := hex.EncodeToString(shaBytes[:])

	authResponse, err := s.send(http.MethodPost, "auth", map[string]any{
		"login":    s.login,
		"password": passwordDigest,
	}, s.requestTimeout, false)
	if err != nil {
		return false, err
	}
	defer authResponse.Body.Close()
	return authResponse.StatusCode == http.StatusOK, nil
}

func (s *keeneticSession) get(endpoint string) (*http.Response, error) {
	return s.send(http.MethodGet, endpoint, nil, s.requestTimeout, true)
}

func (s *keeneticSession) post(endpoint string, body map[string]any) (*http.Response, error) {
	return s.send(http.MethodPost, endpoint, body, s.requestTimeout, true)
}

func (s *keeneticSession) send(method, endpoint string, body any, timeout time.Duration, checkStatus bool) (*http.Response, error) {
	var requestBody io.Reader
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}
		requestBody = bytes.NewReader(encoded)
	}
	request, err := http.NewRequest(method, s.baseURI.ResolveReference(&url.URL{Path: endpoint}).String(), requestBody)
	if err != nil {
		return nil, err
	}
	request.Header.Set("accept", "application/json")
	if body != nil {
		request.Header.Set("content-type", "application/json")
	}
	if len(s.cookies) > 0 {
		pairs := make([]string, 0, len(s.cookies))
		for key, value := range s.cookies {
			pairs = append(pairs, key+"="+value)
		}
		sort.Strings(pairs)
		request.Header.Set("cookie", strings.Join(pairs, "; "))
	}

	response, err := s.client.Do(request)
	if err != nil {
		return nil, err
	}
	s.captureCookies(response)
	if checkStatus && response.StatusCode != http.StatusOK {
		defer response.Body.Close()
		return nil, RouterRequestError{
			StatusCode: response.StatusCode,
			Message:    fmt.Sprintf("unexpected status code %d for %s", response.StatusCode, request.URL),
		}
	}
	return response, nil
}

func (s *keeneticSession) captureCookies(response *http.Response) {
	for _, cookie := range response.Cookies() {
		s.cookies[cookie.Name] = cookie.Value
	}
}

type clientAccumulator struct {
	Name        string
	IPAddress   string
	MACAddress  string
	PolicyName  string
	Access      ClientAccessMode
	IsDenied    bool
	IsPermitted bool
	Priority    *int
	RawData     map[string]any
}

func normalizeBaseURL(input *url.URL) *url.URL {
	if input == nil {
		return mustParseURL("http://127.0.0.1/")
	}
	copy := *input
	if copy.Scheme == "" && copy.Host == "" && copy.Path != "" {
		copy.Scheme = "http"
		copy.Host = copy.Path
		copy.Path = "/"
	}
	if copy.Scheme == "" {
		copy.Scheme = "http"
	}
	if copy.Path == "" {
		copy.Path = "/"
	} else if !strings.HasSuffix(copy.Path, "/") {
		copy.Path += "/"
	}
	copy.RawQuery = ""
	copy.Fragment = ""
	return &copy
}

func mustParseURL(raw string) *url.URL {
	parsed, _ := url.Parse(raw)
	return parsed
}

func decodeJSON(body io.Reader) (any, error) {
	var payload any
	if err := json.NewDecoder(body).Decode(&payload); err != nil {
		return nil, RouterParseError{Message: fmt.Sprintf("invalid JSON payload: %v", err)}
	}
	return payload, nil
}

func parseAccessMode(value string) ClientAccessMode {
	switch value {
	case "permit", "allow":
		return ClientAccessAllow
	case "deny":
		return ClientAccessDeny
	default:
		return ClientAccessUnknown
	}
}

func asString(value any) string {
	if text, ok := value.(string); ok {
		return text
	}
	return ""
}

func defaultString(value, fallback string) string {
	if strings.TrimSpace(value) == "" {
		return fallback
	}
	return value
}

func asBool(value any) bool {
	flag, _ := value.(bool)
	return flag
}

func asIntPtr(value any) *int {
	switch typed := value.(type) {
	case float64:
		integer := int(typed)
		return &integer
	case int:
		integer := typed
		return &integer
	case string:
		var integer int
		if _, err := fmt.Sscanf(strings.TrimSpace(typed), "%d", &integer); err == nil {
			return &integer
		}
	}
	return nil
}

func pickClientField(rawData map[string]any, key string) any {
	if rawData == nil {
		return nil
	}
	if value, ok := rawData[key]; ok && value != nil {
		return value
	}
	if nested, ok := rawData["mws"].(map[string]any); ok {
		return nested[key]
	}
	return nil
}

func formatWiFiStandard(value any) string {
	switch typed := value.(type) {
	case []any:
		items := make([]string, 0, len(typed))
		for _, item := range typed {
			text := strings.TrimSpace(fmt.Sprint(item))
			if text != "" {
				items = append(items, text)
			}
		}
		return strings.Join(items, "/")
	case string:
		return typed
	default:
		return ""
	}
}

func wifiBandFor(accessPointName string) string {
	switch accessPointName {
	case "WifiMaster0/AccessPoint0":
		return "2.4 GHz"
	case "WifiMaster1/AccessPoint0":
		return "5 GHz"
	default:
		return ""
	}
}

func isOnline(rawData map[string]any) bool {
	if asString(rawData["link"]) == "up" {
		return true
	}
	if nested, ok := rawData["mws"].(map[string]any); ok {
		return asString(nested["link"]) == "up"
	}
	return false
}

func parseStringList(value any) []string {
	switch typed := value.(type) {
	case []any:
		items := make([]string, 0, len(typed))
		for _, item := range typed {
			text := asString(item)
			if text != "" {
				items = append(items, text)
			}
		}
		return items
	case []string:
		return append([]string(nil), typed...)
	case string:
		if typed != "" {
			return []string{typed}
		}
	}
	return []string{}
}

func firstValue(values map[string]any, keys ...string) any {
	for _, key := range keys {
		if value, ok := values[key]; ok {
			return value
		}
	}
	return nil
}

func asRequestError(err error, target *RouterRequestError) bool {
	value, ok := err.(RouterRequestError)
	if !ok {
		return false
	}
	if target != nil {
		*target = value
	}
	return true
}
