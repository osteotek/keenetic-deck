package core

import (
	"net/url"
	"testing"
	"time"
)

func TestResolveConnectionTargetPrefersLocalNetworkIP(t *testing.T) {
	api := fakeRouterAPI{authenticateResult: true}
	profile := RouterProfile{
		ID:          "router-1",
		Name:        "Home",
		Address:     "https://home.keenetic.link",
		Login:       "admin",
		NetworkIP:   "192.168.1.1",
		KeenDNSURLs: []string{"home.keenetic.link"},
		CreatedAt:   time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		UpdatedAt:   time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	}

	target, err := ResolveConnectionTarget(api, profile, "secret", []string{"192.168.1.0/24"})
	if err != nil {
		t.Fatalf("resolve target: %v", err)
	}
	if target.Kind != ConnectionLocalNetwork {
		t.Fatalf("expected local network, got %s", target.Kind)
	}
	if target.URI.String() != "http://192.168.1.1" {
		t.Fatalf("unexpected uri: %s", target.URI)
	}
}

func TestResolveConnectionTargetFallsBackToPreferredKeenDNS(t *testing.T) {
	api := fakeRouterAPI{authenticateResult: false}
	profile := RouterProfile{
		ID:          "router-1",
		Name:        "Home",
		Address:     "192.168.1.1",
		Login:       "admin",
		NetworkIP:   "10.0.0.1",
		KeenDNSURLs: []string{"hash123.keenetic.io", "nice-name.keenetic.link"},
		CreatedAt:   time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		UpdatedAt:   time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	}

	target, err := ResolveConnectionTarget(api, profile, "secret", []string{"192.168.1.0/24"})
	if err != nil {
		t.Fatalf("resolve target: %v", err)
	}
	if target.Kind != ConnectionKeenDNS {
		t.Fatalf("expected keenDNS, got %s", target.Kind)
	}
	if target.URI.String() != "https://nice-name.keenetic.link" {
		t.Fatalf("unexpected uri: %s", target.URI)
	}
}

type fakeRouterAPI struct {
	authenticateResult bool
}

func (f fakeRouterAPI) Authenticate(baseURI *url.URL, login, password string) (bool, error) {
	return f.authenticateResult, nil
}

func (fakeRouterAPI) GetKeenDNSURLs(baseURI *url.URL, login, password string) ([]string, error) {
	panic("not implemented")
}

func (fakeRouterAPI) GetNetworkIP(baseURI *url.URL, login, password string) (string, error) {
	panic("not implemented")
}

func (fakeRouterAPI) GetPolicies(baseURI *url.URL, login, password string) ([]VpnPolicy, error) {
	panic("not implemented")
}

func (fakeRouterAPI) GetClients(baseURI *url.URL, login, password string) ([]ClientDevice, error) {
	panic("not implemented")
}

func (fakeRouterAPI) ApplyPolicy(baseURI *url.URL, login, password, macAddress string, policyName *string) error {
	panic("not implemented")
}

func (fakeRouterAPI) BlockClient(baseURI *url.URL, login, password, macAddress string) error {
	panic("not implemented")
}

func (fakeRouterAPI) WakeOnLAN(baseURI *url.URL, login, password, macAddress string) error {
	panic("not implemented")
}

func (fakeRouterAPI) GetWireGuardPeers(baseURI *url.URL, login, password string) ([]WireGuardPeer, error) {
	panic("not implemented")
}
