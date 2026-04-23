package core

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

type RouterRepository struct {
	path string
}

func NewRouterRepository(path string) *RouterRepository {
	return &RouterRepository{path: path}
}

func (r *RouterRepository) Path() string {
	return r.path
}

func (r *RouterRepository) GetRouters() ([]RouterProfile, error) {
	doc, err := r.readDocument()
	if err != nil {
		return nil, err
	}
	return doc.Routers, nil
}

func (r *RouterRepository) GetRouterByID(id string) (*RouterProfile, error) {
	doc, err := r.readDocument()
	if err != nil {
		return nil, err
	}
	for _, profile := range doc.Routers {
		if profile.ID == id {
			copy := profile
			return &copy, nil
		}
	}
	return nil, nil
}

func (r *RouterRepository) GetSelectedRouterID() (string, error) {
	doc, err := r.readDocument()
	if err != nil {
		return "", err
	}
	return doc.SelectedRouterID, nil
}

func (r *RouterRepository) SaveRouter(profile RouterProfile) error {
	doc, err := r.readDocument()
	if err != nil {
		return err
	}
	index := -1
	for i, existing := range doc.Routers {
		if existing.ID == profile.ID {
			index = i
			break
		}
	}
	if index == -1 {
		doc.Routers = append(doc.Routers, profile)
	} else {
		doc.Routers[index] = profile
	}
	return r.writeDocument(doc)
}

func (r *RouterRepository) DeleteRouter(id string) error {
	doc, err := r.readDocument()
	if err != nil {
		return err
	}
	filtered := make([]RouterProfile, 0, len(doc.Routers))
	for _, profile := range doc.Routers {
		if profile.ID != id {
			filtered = append(filtered, profile)
		}
	}
	doc.Routers = filtered
	if doc.SelectedRouterID == id {
		doc.SelectedRouterID = ""
	}
	return r.writeDocument(doc)
}

func (r *RouterRepository) SetSelectedRouterID(id string) error {
	doc, err := r.readDocument()
	if err != nil {
		return err
	}
	doc.SelectedRouterID = id
	return r.writeDocument(doc)
}

type routerStorageDocument struct {
	Version          int             `json:"version"`
	SelectedRouterID string          `json:"selected_router_id"`
	Routers          []RouterProfile `json:"routers"`
}

func (r *RouterRepository) readDocument() (routerStorageDocument, error) {
	contents, err := os.ReadFile(r.path)
	if errors.Is(err, os.ErrNotExist) {
		return routerStorageDocument{Routers: []RouterProfile{}}, nil
	}
	if err != nil {
		return routerStorageDocument{}, err
	}
	if len(contents) == 0 {
		return routerStorageDocument{Routers: []RouterProfile{}}, nil
	}

	var raw struct {
		Version          int               `json:"version"`
		SelectedRouterID string            `json:"selected_router_id"`
		Routers          []json.RawMessage `json:"routers"`
	}
	if err := json.Unmarshal(contents, &raw); err != nil {
		return routerStorageDocument{}, err
	}
	doc := routerStorageDocument{
		Version:          raw.Version,
		SelectedRouterID: raw.SelectedRouterID,
		Routers:          make([]RouterProfile, 0, len(raw.Routers)),
	}
	for _, item := range raw.Routers {
		var profile RouterProfile
		if err := json.Unmarshal(item, &profile); err != nil {
			return routerStorageDocument{}, err
		}
		if profile.ID == "" || profile.Name == "" || profile.Address == "" || profile.Login == "" {
			return routerStorageDocument{}, fmt.Errorf("invalid router profile in storage")
		}
		doc.Routers = append(doc.Routers, profile)
	}
	return doc, nil
}

func (r *RouterRepository) writeDocument(doc routerStorageDocument) error {
	doc.Version = 1
	if doc.Routers == nil {
		doc.Routers = []RouterProfile{}
	}
	if err := os.MkdirAll(filepath.Dir(r.path), 0o755); err != nil {
		return err
	}
	payload, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(r.path, append(payload, '\n'), 0o600)
}

type SecretRepository struct {
	path string
}

func NewSecretRepository(path string) *SecretRepository {
	return &SecretRepository{path: path}
}

func (s *SecretRepository) ReadRouterPassword(routerID string) (string, error) {
	doc, err := s.readDocument()
	if err != nil {
		return "", err
	}
	return doc.Passwords[routerID], nil
}

func (s *SecretRepository) WriteRouterPassword(routerID, password string) error {
	doc, err := s.readDocument()
	if err != nil {
		return err
	}
	doc.Passwords[routerID] = password
	return s.writeDocument(doc)
}

func (s *SecretRepository) DeleteRouterPassword(routerID string) error {
	doc, err := s.readDocument()
	if err != nil {
		return err
	}
	delete(doc.Passwords, routerID)
	return s.writeDocument(doc)
}

type secretDocument struct {
	Version   int               `json:"version"`
	Passwords map[string]string `json:"passwords"`
}

func (s *SecretRepository) readDocument() (secretDocument, error) {
	contents, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return secretDocument{Passwords: map[string]string{}}, nil
	}
	if err != nil {
		return secretDocument{}, err
	}
	if len(contents) == 0 {
		return secretDocument{Passwords: map[string]string{}}, nil
	}
	var doc secretDocument
	if err := json.Unmarshal(contents, &doc); err != nil {
		return secretDocument{}, err
	}
	if doc.Passwords == nil {
		doc.Passwords = map[string]string{}
	}
	return doc, nil
}

func (s *SecretRepository) writeDocument(doc secretDocument) error {
	doc.Version = 1
	if doc.Passwords == nil {
		doc.Passwords = map[string]string{}
	}
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	payload, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, append(payload, '\n'), 0o600)
}

type PreferencesRepository struct {
	path string
}

func NewPreferencesRepository(path string) *PreferencesRepository {
	return &PreferencesRepository{path: path}
}

func (p *PreferencesRepository) Read() (Preferences, error) {
	contents, err := os.ReadFile(p.path)
	if errors.Is(err, os.ErrNotExist) {
		return Preferences{}, nil
	}
	if err != nil {
		return Preferences{}, err
	}
	if len(contents) == 0 {
		return Preferences{}, nil
	}
	var prefs Preferences
	if err := json.Unmarshal(contents, &prefs); err != nil {
		return Preferences{}, err
	}
	return prefs, nil
}

func (p *PreferencesRepository) Write(prefs Preferences) error {
	if err := os.MkdirAll(filepath.Dir(p.path), 0o755); err != nil {
		return err
	}
	payload, err := json.MarshalIndent(struct {
		Version            int  `json:"version"`
		AutoRefreshEnabled bool `json:"auto_refresh_enabled"`
	}{
		Version:            1,
		AutoRefreshEnabled: prefs.AutoRefreshEnabled,
	}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(p.path, append(payload, '\n'), 0o600)
}

func DefaultStoragePaths() (StoragePaths, error) {
	base, err := os.UserConfigDir()
	if err != nil {
		return StoragePaths{}, err
	}
	root := filepath.Join(base, "keenetic-deck-tui")
	return StoragePaths{
		BaseDir:         root,
		RoutersPath:     filepath.Join(root, "routers.v1.json"),
		SecretsPath:     filepath.Join(root, "router_secrets.v1.json"),
		PreferencesPath: filepath.Join(root, "app_preferences.v1.json"),
	}, nil
}

func NormalizeRouterProfileTimes(profile RouterProfile) RouterProfile {
	if profile.CreatedAt.IsZero() {
		profile.CreatedAt = time.Now().UTC()
	}
	if profile.UpdatedAt.IsZero() {
		profile.UpdatedAt = profile.CreatedAt
	}
	return profile
}
