// Test-only GoFish adapter. No device-mutating API is used.
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

type record struct {
	URI   string  `json:"uri"`
	ID    string  `json:"id"`
	Name  string  `json:"name"`
	Type  string  `json:"type"`
	Power *string `json:"power"`
}

func project(uri, id, name, kind, power string) record {
	r := record{URI: uri, ID: id, Name: name, Type: kind}
	if power != "" {
		r.Power = &power
	}
	return r
}

func must(err error, stage string) {
	if err != nil {
		// GoFish errors can retain raw response bodies. Never print them here.
		panic("comparison stage failed: " + stage)
	}
}

func status(err error) int {
	var e *schemas.Error
	if errors.As(err, &e) {
		return e.HTTPReturnedStatusCode
	}
	return 0
}

func systems(c *gofish.APIClient) []record {
	items, err := c.Service.Systems()
	must(err, "systems")
	result := []record{}
	for _, r := range items {
		result = append(result, project(r.ODataID, r.ID, r.Name, r.ODataType, string(r.PowerState)))
	}
	return result
}

func inventory(c *gofish.APIClient) any {
	s := c.Service
	chassis, err := s.Chassis()
	must(err, "chassis")
	ch := []record{}
	for _, r := range chassis {
		ch = append(ch, project(r.ODataID, r.ID, r.Name, r.ODataType, string(r.PowerState)))
	}
	managers, err := s.Managers()
	must(err, "managers")
	ma := []record{}
	for _, r := range managers {
		ma = append(ma, project(r.ODataID, r.ID, r.Name, r.ODataType, string(r.PowerState)))
	}
	return map[string]any{
		"root":    project(s.ODataID, s.ID, s.Name, s.ODataType, ""),
		"systems": systems(c), "chassis": ch, "managers": ma,
	}
}

func protocol(ctx context.Context, config gofish.ClientConfig) any {
	config.Username, config.Password = "synthetic-user", "synthetic-wrong"
	_, err := gofish.ConnectContext(ctx, config)
	wrong := status(err)
	config.Password = "synthetic-password"
	c, err := gofish.ConnectContext(ctx, config)
	must(err, "session login")
	// Logout has no error return. The server-side runner verifies cleanup occurred.
	defer c.Logout()
	items := systems(c)
	chassis, err := c.Service.Chassis()
	must(err, "empty chassis")
	_, err = c.Get("/redfish/v1/Forbidden")
	var forbidden *schemas.Error
	if !errors.As(err, &forbidden) {
		panic("missing structured HTTP error")
	}
	ids := []string{}
	for _, info := range forbidden.ExtendedInfos {
		ids = append(ids, info.MessageID)
	}
	_, err = c.Get("/redfish/v1/Missing")
	missing := status(err)
	_, err = schemas.GetComputerSystem(c, "/redfish/v1/Invalid")
	var syntax *json.SyntaxError
	invalid := errors.As(err, &syntax)
	_, err = schemas.GetCollectionObjects[schemas.ComputerSystem](c, "/redfish/v1/Cycle")
	var collection *schemas.CollectionError
	cycle := errors.As(err, &collection) && len(collection.Failures) == 1 &&
		collection.Failures["/redfish/v1/Cycle"] != nil &&
		collection.Failures["/redfish/v1/Cycle"].Error() == "collection pagination loop"
	return map[string]any{
		"wrong_password": wrong, "systems": items, "empty_chassis": len(chassis),
		"forbidden": map[string]any{"status": forbidden.HTTPReturnedStatusCode, "code": forbidden.Code, "message_ids": ids},
		"missing":   missing, "invalid_json": invalid, "pagination_cycle": cycle,
	}
}

func main() {
	if len(os.Args) != 4 {
		panic("run via python3 tools/test_gofish.py")
	}
	endpoint, err := url.Parse(os.Args[2])
	if err != nil || endpoint.Hostname() != "127.0.0.1" || endpoint.User != nil ||
		(endpoint.Scheme != "http" && endpoint.Scheme != "https") || endpoint.Path != "" || endpoint.RawQuery != "" || endpoint.Fragment != "" {
		panic("comparison requires numeric loopback")
	}
	tlsConfig := &tls.Config{MinVersion: tls.VersionTLS12}
	if os.Args[3] != "-" {
		pem, err := os.ReadFile(os.Args[3])
		must(err, "read synthetic CA")
		tlsConfig.RootCAs = x509.NewCertPool()
		if !tlsConfig.RootCAs.AppendCertsFromPEM(pem) {
			panic("invalid synthetic CA")
		}
	}
	// Do not inherit proxy settings or follow redirects outside the local fixture.
	httpClient := &http.Client{
		Timeout:       10 * time.Second,
		Transport:     &http.Transport{TLSClientConfig: tlsConfig},
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse },
	}
	config := gofish.ClientConfig{Endpoint: os.Args[2], HTTPClient: httpClient, NoModifyTransport: true}
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()
	var result any
	if os.Args[1] == "protocol" {
		result = protocol(ctx, config)
	} else {
		c, err := gofish.ConnectContext(ctx, config)
		if os.Args[1] == "reject_tls" {
			var untrusted x509.UnknownAuthorityError
			result = map[string]bool{"tls_rejected": errors.As(err, &untrusted)}
		} else if os.Args[1] == "parity" {
			must(err, "service root")
			result = parity(c)
		} else if os.Args[1] == "extended" {
			must(err, "service root")
			result = extended(c)
		} else if os.Args[1] == "hardware" {
			must(err, "service root")
			result = hardware(c)
		} else if os.Args[1] == "inventory" {
			must(err, "service root")
			result = inventory(c)
		} else {
			panic("unknown comparison mode")
		}
	}
	data, err := json.Marshal(result)
	must(err, "encode selected fields")
	fmt.Println(string(data))
}
