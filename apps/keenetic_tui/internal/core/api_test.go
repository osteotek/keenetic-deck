package core

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestAuthenticatePerformsChallengeResponseLogin(t *testing.T) {
	t.Helper()
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		switch {
		case r.URL.Path == "/auth" && r.Method == http.MethodGet:
			w.Header().Set("x-ndm-realm", "Keenetic")
			w.Header().Set("x-ndm-challenge", "abc123")
			w.WriteHeader(http.StatusUnauthorized)
		case r.URL.Path == "/auth" && r.Method == http.MethodPost:
			var body map[string]any
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Fatalf("decode body: %v", err)
			}
			if body["login"] != "admin" {
				t.Fatalf("expected login admin, got %#v", body["login"])
			}
			password, _ := body["password"].(string)
			if len(password) != 64 {
				t.Fatalf("expected 64-byte digest, got %q", password)
			}
			http.SetCookie(w, &http.Cookie{Name: "sid", Value: "session123", Path: "/"})
			w.WriteHeader(http.StatusOK)
		default:
			t.Fatalf("unexpected request %s %s", r.Method, r.URL)
		}
	}))
	defer server.Close()

	api := NewKeeneticAPI()
	baseURL, _ := url.Parse(server.URL)
	ok, err := api.Authenticate(baseURL, "admin", "secret")
	if err != nil {
		t.Fatalf("authenticate error: %v", err)
	}
	if !ok {
		t.Fatal("expected authenticate to succeed")
	}
	if requests != 2 {
		t.Fatalf("expected 2 requests, got %d", requests)
	}
}

func TestGetClientsMergesHostAndPolicyDatasets(t *testing.T) {
	hostsFixture := readFixture(t, "client_hosts.json")
	policiesFixture := readFixture(t, "client_policies.json")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/auth" && r.Method == http.MethodGet:
			w.Header().Set("x-ndm-realm", "Keenetic")
			w.Header().Set("x-ndm-challenge", "abc123")
			w.WriteHeader(http.StatusUnauthorized)
		case r.URL.Path == "/auth" && r.Method == http.MethodPost:
			http.SetCookie(w, &http.Cookie{Name: "sid", Value: "session123", Path: "/"})
			w.WriteHeader(http.StatusOK)
		case r.URL.Path == "/rci/show/ip/hotspot/host":
			if !strings.Contains(r.Header.Get("Cookie"), "sid=session123") {
				t.Fatalf("expected auth cookie, got %q", r.Header.Get("Cookie"))
			}
			_, _ = w.Write(hostsFixture)
		case r.URL.Path == "/rci/show/rc/ip/hotspot/host":
			if !strings.Contains(r.Header.Get("Cookie"), "sid=session123") {
				t.Fatalf("expected auth cookie, got %q", r.Header.Get("Cookie"))
			}
			_, _ = w.Write(policiesFixture)
		default:
			t.Fatalf("unexpected request %s %s", r.Method, r.URL)
		}
	}))
	defer server.Close()

	api := NewKeeneticAPI()
	baseURL, _ := url.Parse(server.URL)
	clients, err := api.GetClients(baseURL, "admin", "secret")
	if err != nil {
		t.Fatalf("get clients error: %v", err)
	}
	if len(clients) != 3 {
		t.Fatalf("expected 3 clients, got %d", len(clients))
	}

	laptop := clientByMAC(t, clients, "aa:bb:cc:dd:ee:ff")
	if laptop.Name != "Laptop" {
		t.Fatalf("expected Laptop, got %q", laptop.Name)
	}
	if laptop.PolicyName != "work-vpn" {
		t.Fatalf("expected work-vpn, got %q", laptop.PolicyName)
	}
	if laptop.ConnectionState != ClientConnectionOnline {
		t.Fatalf("expected laptop online, got %q", laptop.ConnectionState)
	}
	if !laptop.IsWireless() {
		t.Fatal("expected laptop to be wireless")
	}
	if laptop.WiFiBand != "2.4 GHz" {
		t.Fatalf("expected 2.4 GHz, got %q", laptop.WiFiBand)
	}

	unknown := clientByMAC(t, clients, "77:88:99:aa:bb:cc")
	if !unknown.IsDenied {
		t.Fatal("expected unknown client to be denied")
	}
	if unknown.ConnectionState != ClientConnectionOffline {
		t.Fatalf("expected unknown offline, got %q", unknown.ConnectionState)
	}
}

func TestRouterRepositoryRoundTrip(t *testing.T) {
	dir := t.TempDir()
	repo := NewRouterRepository(filepath.Join(dir, "routers.v1.json"))

	profile := RouterProfile{
		ID:          "home",
		Name:        "Home",
		Address:     "http://192.168.1.1",
		Login:       "admin",
		NetworkIP:   "192.168.1.1",
		KeenDNSURLs: []string{"home.keenetic.link"},
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	if err := repo.SaveRouter(profile); err != nil {
		t.Fatalf("save router: %v", err)
	}
	if err := repo.SetSelectedRouterID(profile.ID); err != nil {
		t.Fatalf("set selected router: %v", err)
	}

	routers, err := repo.GetRouters()
	if err != nil {
		t.Fatalf("get routers: %v", err)
	}
	if len(routers) != 1 || routers[0].ID != "home" {
		t.Fatalf("unexpected routers: %#v", routers)
	}
	selectedID, err := repo.GetSelectedRouterID()
	if err != nil {
		t.Fatalf("get selected router: %v", err)
	}
	if selectedID != "home" {
		t.Fatalf("expected home selected, got %q", selectedID)
	}
}

func clientByMAC(t *testing.T, clients []ClientDevice, mac string) ClientDevice {
	t.Helper()
	for _, client := range clients {
		if client.MACAddress == mac {
			return client
		}
	}
	t.Fatalf("client %s not found", mac)
	return ClientDevice{}
}

func readFixture(t *testing.T, name string) []byte {
	t.Helper()
	path := filepath.Join("..", "..", "..", "..", "packages", "router_core", "test", "fixtures", name)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read fixture %s: %v", name, err)
	}
	return data
}
