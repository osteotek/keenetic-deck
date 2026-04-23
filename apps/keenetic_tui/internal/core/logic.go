package core

import (
	"fmt"
	"net"
	"net/url"
	"slices"
	"strings"
	"sync"
	"time"
)

type Environment struct {
	Routers      *RouterRepository
	Secrets      *SecretRepository
	Preferences  *PreferencesRepository
	LocalDevice  LocalDeviceInfoService
	API          RouterAPI
	StoragePaths StoragePaths
}

func NewEnvironment() (*Environment, error) {
	paths, err := DefaultStoragePaths()
	if err != nil {
		return nil, err
	}
	return &Environment{
		Routers:      NewRouterRepository(paths.RoutersPath),
		Secrets:      NewSecretRepository(paths.SecretsPath),
		Preferences:  NewPreferencesRepository(paths.PreferencesPath),
		LocalDevice:  LocalDeviceInfoService{},
		API:          NewKeeneticAPI(),
		StoragePaths: paths,
	}, nil
}

func (e *Environment) LoadOverview() (RouterOverview, error) {
	routers, err := e.Routers.GetRouters()
	if err != nil {
		return RouterOverview{}, err
	}
	selectedRouterID, err := e.Routers.GetSelectedRouterID()
	if err != nil {
		return RouterOverview{}, err
	}
	passwordStored := make(map[string]bool, len(routers))
	for _, router := range routers {
		password, err := e.Secrets.ReadRouterPassword(router.ID)
		if err != nil {
			return RouterOverview{}, err
		}
		passwordStored[router.ID] = strings.TrimSpace(password) != ""
	}
	prefs, err := e.Preferences.Read()
	if err != nil {
		return RouterOverview{}, err
	}

	var selectedStatus *SelectedRouterStatus
	if selectedRouterID != "" {
		for index, router := range routers {
			if router.ID != selectedRouterID {
				continue
			}
			status, err := e.LoadSelectedRouterStatus(router)
			if err != nil {
				return RouterOverview{}, err
			}
			selectedStatus = &status
			routers[index] = status.Router
			break
		}
	}

	return RouterOverview{
		StoragePath:       e.StoragePaths.RoutersPath,
		Routers:           routers,
		SelectedRouterID:  selectedRouterID,
		PasswordStored:    passwordStored,
		SelectedStatus:    selectedStatus,
		AutoRefreshEnable: prefs.AutoRefreshEnabled,
	}, nil
}

func (e *Environment) LoadSelectedRouterStatus(router RouterProfile) (SelectedRouterStatus, error) {
	localMACs, err := e.LocalDevice.GetLocalMACAddresses()
	if err != nil {
		localMACs = []string{}
	}
	password, err := e.Secrets.ReadRouterPassword(router.ID)
	if err != nil {
		return SelectedRouterStatus{}, err
	}
	if strings.TrimSpace(password) == "" {
		return SelectedRouterStatus{
			Router:            router,
			CheckedAt:         time.Now(),
			HasStoredPassword: false,
			LocalMACAddresses: localMACs,
			ErrorMessage:      "No saved password for the selected router.",
		}, nil
	}

	refreshedRouter, err := e.RefreshRouterMetadata(router, password)
	if err != nil {
		refreshedRouter = router
	}
	if routerMetadataChanged(router, refreshedRouter) {
		if saveErr := e.Routers.SaveRouter(refreshedRouter); saveErr != nil {
			return SelectedRouterStatus{}, saveErr
		}
	}

	localCIDRs, err := e.LocalDevice.GetLocalIPv4CIDRs()
	if err != nil {
		localCIDRs = []string{}
	}
	target, err := ResolveConnectionTarget(e.API, refreshedRouter, password, localCIDRs)
	if err != nil {
		return SelectedRouterStatus{
			Router:            refreshedRouter,
			CheckedAt:         time.Now(),
			HasStoredPassword: true,
			LocalMACAddresses: localMACs,
			ErrorMessage:      err.Error(),
		}, nil
	}

	authenticated, err := e.API.Authenticate(target.URI, refreshedRouter.Login, password)
	if err != nil || !authenticated {
		message := "Authentication failed for the selected connection target."
		if err != nil {
			message = err.Error()
		}
		return SelectedRouterStatus{
			Router:            refreshedRouter,
			CheckedAt:         time.Now(),
			HasStoredPassword: true,
			ConnectionTarget:  target,
			LocalMACAddresses: localMACs,
			ErrorMessage:      message,
		}, nil
	}

	type result struct {
		clients []ClientDevice
		policy  []VpnPolicy
		peers   []WireGuardPeer
		err     error
	}
	var (
		clients  []ClientDevice
		policies []VpnPolicy
		peers    []WireGuardPeer
		wg       sync.WaitGroup
		mu       sync.Mutex
		firstErr error
	)
	wg.Add(3)
	go func() {
		defer wg.Done()
		values, err := e.API.GetClients(target.URI, refreshedRouter.Login, password)
		mu.Lock()
		defer mu.Unlock()
		if err != nil && firstErr == nil {
			firstErr = err
			return
		}
		clients = values
	}()
	go func() {
		defer wg.Done()
		values, err := e.API.GetPolicies(target.URI, refreshedRouter.Login, password)
		mu.Lock()
		defer mu.Unlock()
		if err != nil && firstErr == nil {
			firstErr = err
			return
		}
		policies = values
	}()
	go func() {
		defer wg.Done()
		values, err := e.API.GetWireGuardPeers(target.URI, refreshedRouter.Login, password)
		mu.Lock()
		defer mu.Unlock()
		if err != nil && firstErr == nil {
			firstErr = err
			return
		}
		peers = values
	}()
	wg.Wait()
	if firstErr != nil {
		return SelectedRouterStatus{
			Router:            refreshedRouter,
			CheckedAt:         time.Now(),
			HasStoredPassword: true,
			LocalMACAddresses: localMACs,
			ErrorMessage:      firstErr.Error(),
		}, nil
	}

	onlineCount := 0
	for _, client := range clients {
		if client.ConnectionState == ClientConnectionOnline {
			onlineCount++
		}
	}

	return SelectedRouterStatus{
		Router:             refreshedRouter,
		CheckedAt:          time.Now(),
		HasStoredPassword:  true,
		ConnectionTarget:   target,
		IsConnected:        true,
		LocalMACAddresses:  localMACs,
		Clients:            clients,
		Policies:           policies,
		WireGuardPeers:     peers,
		ClientCount:        len(clients),
		OnlineClientCount:  onlineCount,
		PolicyCount:        len(policies),
		WireGuardPeerCount: len(peers),
	}, nil
}

func (e *Environment) SaveRouter(result RouterFormInput, existing *RouterProfile) error {
	now := time.Now().UTC()
	routers, err := e.Routers.GetRouters()
	if err != nil {
		return err
	}
	var storedPassword string
	if existing != nil {
		storedPassword, err = e.Secrets.ReadRouterPassword(existing.ID)
		if err != nil {
			return err
		}
	}
	passwordToValidate := strings.TrimSpace(result.Password)
	if passwordToValidate == "" {
		passwordToValidate = storedPassword
	}
	if passwordToValidate == "" {
		return RouterAuthenticationError{Message: "a password is required to validate and save this router"}
	}

	profile := RouterProfile{
		ID:          RouterIDFor(result.Name, result.Address, routers),
		Name:        strings.TrimSpace(result.Name),
		Address:     strings.TrimSpace(result.Address),
		Login:       strings.TrimSpace(result.Login),
		CreatedAt:   now,
		UpdatedAt:   now,
		KeenDNSURLs: []string{},
	}
	if existing != nil {
		profile.ID = existing.ID
		profile.NetworkIP = existing.NetworkIP
		profile.KeenDNSURLs = append([]string(nil), existing.KeenDNSURLs...)
		profile.CreatedAt = existing.CreatedAt
	}
	prepared, err := e.ValidateAndPrepareRouter(profile, passwordToValidate)
	if err != nil {
		return err
	}
	if err := e.Routers.SaveRouter(prepared); err != nil {
		return err
	}
	if strings.TrimSpace(result.Password) != "" {
		if err := e.Secrets.WriteRouterPassword(prepared.ID, result.Password); err != nil {
			return err
		}
	} else if storedPassword != "" {
		if err := e.Secrets.WriteRouterPassword(prepared.ID, storedPassword); err != nil {
			return err
		}
	}
	selectedRouterID, err := e.Routers.GetSelectedRouterID()
	if err != nil {
		return err
	}
	if selectedRouterID == "" {
		return e.Routers.SetSelectedRouterID(prepared.ID)
	}
	return nil
}

type RouterFormInput struct {
	Name     string
	Address  string
	Login    string
	Password string
}

func (e *Environment) DeleteRouter(router RouterProfile) error {
	if err := e.Routers.DeleteRouter(router.ID); err != nil {
		return err
	}
	return e.Secrets.DeleteRouterPassword(router.ID)
}

func (e *Environment) HasStoredPassword(router *RouterProfile) (bool, error) {
	if router == nil {
		return false, nil
	}
	password, err := e.Secrets.ReadRouterPassword(router.ID)
	if err != nil {
		return false, err
	}
	return strings.TrimSpace(password) != "", nil
}

func (e *Environment) SetSelectedRouterID(id string) error {
	return e.Routers.SetSelectedRouterID(id)
}

func (e *Environment) SetAutoRefreshEnabled(enabled bool) error {
	return e.Preferences.Write(Preferences{AutoRefreshEnabled: enabled})
}

func (e *Environment) RunClientAction(status SelectedRouterStatus, request ClientActionRequest) error {
	password, err := e.Secrets.ReadRouterPassword(status.Router.ID)
	if err != nil {
		return err
	}
	if strings.TrimSpace(password) == "" {
		return RouterAuthenticationError{Message: "No saved password for the selected router."}
	}
	target := status.ConnectionTarget
	if target == nil {
		localCIDRs, err := e.LocalDevice.GetLocalIPv4CIDRs()
		if err != nil {
			localCIDRs = []string{}
		}
		target, err = ResolveConnectionTarget(e.API, status.Router, password, localCIDRs)
		if err != nil {
			return err
		}
	}
	switch request.Kind {
	case ClientActionSetDefaultPolicy:
		return e.API.ApplyPolicy(target.URI, status.Router.Login, password, request.MACAddress, nil)
	case ClientActionSetNamedPolicy:
		return e.API.ApplyPolicy(target.URI, status.Router.Login, password, request.MACAddress, &request.PolicyName)
	case ClientActionBlock:
		return e.API.BlockClient(target.URI, status.Router.Login, password, request.MACAddress)
	case ClientActionWakeOnLAN:
		return e.API.WakeOnLAN(target.URI, status.Router.Login, password, request.MACAddress)
	default:
		return fmt.Errorf("unsupported client action")
	}
}

func (e *Environment) ValidateAndPrepareRouter(profile RouterProfile, password string) (RouterProfile, error) {
	baseURI, err := NormalizeAddress(profile.Address)
	if err != nil {
		return RouterProfile{}, err
	}
	authenticated, err := e.API.Authenticate(baseURI, profile.Login, password)
	if err != nil {
		return RouterProfile{}, err
	}
	if !authenticated {
		return RouterProfile{}, RouterAuthenticationError{Message: "Please check the router address, login, and password."}
	}
	networkIP := profile.NetworkIP
	keenDNSURLs := append([]string(nil), profile.KeenDNSURLs...)
	if value, err := e.API.GetNetworkIP(baseURI, profile.Login, password); err == nil && strings.TrimSpace(value) != "" {
		networkIP = value
	}
	if values, err := e.API.GetKeenDNSURLs(baseURI, profile.Login, password); err == nil && len(values) > 0 {
		keenDNSURLs = values
	}
	profile.Address = CanonicalAddressString(baseURI)
	profile.NetworkIP = networkIP
	profile.KeenDNSURLs = keenDNSURLs
	profile.UpdatedAt = time.Now().UTC()
	return profile, nil
}

func (e *Environment) RefreshRouterMetadata(profile RouterProfile, password string) (RouterProfile, error) {
	baseURI, err := NormalizeAddress(profile.Address)
	if err != nil {
		return profile, err
	}
	networkIP := profile.NetworkIP
	keenDNSURLs := append([]string(nil), profile.KeenDNSURLs...)
	if value, err := e.API.GetNetworkIP(baseURI, profile.Login, password); err == nil && strings.TrimSpace(value) != "" {
		networkIP = value
	}
	if values, err := e.API.GetKeenDNSURLs(baseURI, profile.Login, password); err == nil && len(values) > 0 {
		keenDNSURLs = values
	}
	profile.NetworkIP = networkIP
	profile.KeenDNSURLs = keenDNSURLs
	profile.UpdatedAt = time.Now().UTC()
	return profile, nil
}

func ResolveConnectionTarget(api RouterAPI, profile RouterProfile, password string, localIPv4CIDRs []string) (*ConnectionTarget, error) {
	inLocalNetwork := isRouterInLocalNetwork(profile.NetworkIP, localIPv4CIDRs)
	if len(profile.KeenDNSURLs) == 0 && strings.TrimSpace(profile.NetworkIP) == "" {
		uri, err := NormalizeAddress(profile.Address)
		if err != nil {
			return nil, err
		}
		return &ConnectionTarget{Kind: ConnectionDirect, URI: uri}, nil
	}
	if inLocalNetwork && strings.TrimSpace(profile.NetworkIP) != "" {
		uri, err := NormalizeAddress(profile.NetworkIP)
		if err != nil {
			return nil, err
		}
		return &ConnectionTarget{Kind: ConnectionLocalNetwork, URI: uri}, nil
	}
	if strings.TrimSpace(profile.NetworkIP) != "" {
		uri, err := NormalizeAddress(profile.NetworkIP)
		if err != nil {
			return nil, err
		}
		authenticated, err := api.Authenticate(uri, profile.Login, password)
		if err == nil && authenticated {
			return &ConnectionTarget{Kind: ConnectionLocalNetwork, URI: uri}, nil
		}
	}
	if len(profile.KeenDNSURLs) > 0 {
		configuredHost := extractHost(profile.Address)
		if configuredHost != "" && slices.Contains(profile.KeenDNSURLs, configuredHost) {
			return &ConnectionTarget{
				Kind: ConnectionKeenDNS,
				URI:  httpsURI(configuredHost, profile.Address),
			}, nil
		}
		preferred := profile.KeenDNSURLs[0]
		for _, domain := range profile.KeenDNSURLs {
			if !strings.HasSuffix(domain, ".keenetic.io") {
				preferred = domain
				break
			}
		}
		return &ConnectionTarget{
			Kind: ConnectionKeenDNS,
			URI:  httpsURI(preferred, ""),
		}, nil
	}
	if strings.TrimSpace(profile.NetworkIP) != "" {
		uri, err := NormalizeAddress(profile.NetworkIP)
		if err != nil {
			return nil, err
		}
		return &ConnectionTarget{Kind: ConnectionLocalNetwork, URI: uri}, nil
	}
	uri, err := NormalizeAddress(profile.Address)
	if err != nil {
		return nil, err
	}
	return &ConnectionTarget{Kind: ConnectionDirect, URI: uri}, nil
}

func NormalizeAddress(rawAddress string) (*url.URL, error) {
	trimmed := strings.TrimSpace(rawAddress)
	parsed, err := url.Parse(trimmed)
	if err == nil && parsed.Scheme != "" && parsed.Host != "" {
		if parsed.Path == "/" {
			parsed.Path = ""
		}
		parsed.RawFragment = ""
		return parsed, nil
	}
	if err == nil && parsed.Scheme == "" && parsed.Host == "" && parsed.Path != "" {
		return url.Parse("http://" + parsed.Path)
	}
	if strings.HasPrefix(trimmed, "http://") || strings.HasPrefix(trimmed, "https://") {
		return url.Parse(trimmed)
	}
	return url.Parse("http://" + trimmed)
}

func CanonicalAddressString(uri *url.URL) string {
	copy := *uri
	if copy.Path == "/" {
		copy.Path = ""
	}
	copy.Fragment = ""
	return copy.String()
}

func httpsURI(host, originalAddress string) *url.URL {
	if originalAddress != "" {
		if parsed, err := url.Parse(originalAddress); err == nil && parsed.Host == host && parsed.Scheme != "" {
			return parsed
		}
	}
	return &url.URL{Scheme: "https", Host: host}
}

func extractHost(address string) string {
	parsed, err := url.Parse(address)
	if err != nil {
		return ""
	}
	if parsed.Host != "" {
		return parsed.Host
	}
	return parsed.Path
}

func isRouterInLocalNetwork(routerIP string, localCIDRs []string) bool {
	if strings.TrimSpace(routerIP) == "" {
		return false
	}
	ip := net.ParseIP(routerIP)
	if ip == nil {
		return false
	}
	for _, cidr := range localCIDRs {
		_, network, err := net.ParseCIDR(cidr)
		if err != nil {
			continue
		}
		if network.Contains(ip) {
			return true
		}
	}
	return false
}

func routerMetadataChanged(before, after RouterProfile) bool {
	if before.NetworkIP != after.NetworkIP {
		return true
	}
	if len(before.KeenDNSURLs) != len(after.KeenDNSURLs) {
		return true
	}
	for index := range before.KeenDNSURLs {
		if before.KeenDNSURLs[index] != after.KeenDNSURLs[index] {
			return true
		}
	}
	return false
}
