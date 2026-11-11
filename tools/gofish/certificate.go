// Synthetic certificate metadata/navigation only; no cryptographic or control operations.
package main

import (
	"encoding/json"
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

func certificateIdentifier(item schemas.CertificateIdentifier) any {
	return parityValue(map[string]any{
		"City":                          parityValue(item.City),
		"CommonName":                    parityValue(item.CommonName),
		"Country":                       parityValue(item.Country),
		"DisplayString":                 parityValue(item.DisplayString),
		"Email":                         parityValue(item.Email),
		"Organization":                  parityValue(item.Organization),
		"OrganizationalUnit":            parityValue(item.OrganizationalUnit),
		"State":                         parityValue(item.State),
		"AdditionalCommonNames":         bootStrings(item.AdditionalCommonNames),
		"AdditionalOrganizationalUnits": bootStrings(item.AdditionalOrganizationalUnits),
		"AlternativeNames":              bootStrings(item.AlternativeNames),
		"DomainComponents":              bootStrings(item.DomainComponents),
	})
}
func certificateJSON(item *schemas.Certificate) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"CertificateString":        parityValue(item.CertificateString),
		"CertificateType":          parityValue(item.CertificateType),
		"Fingerprint":              parityValue(item.Fingerprint),
		"FingerprintHashAlgorithm": parityValue(item.FingerprintHashAlgorithm),
		"SerialNumber":             parityValue(item.SerialNumber),
		"SignatureAlgorithm":       parityValue(item.SignatureAlgorithm),
		"UefiSignatureOwner":       parityValue(item.UefiSignatureOwner),
		"ValidNotAfter":            parityValue(item.ValidNotAfter),
		"ValidNotBefore":           parityValue(item.ValidNotBefore),
		"CertificateUsageTypes":    bootStrings(item.CertificateUsageTypes),
		"KeyUsage":                 bootStrings(item.KeyUsage),
		"Issuer":                   certificateIdentifier(item.Issuer), "Subject": certificateIdentifier(item.Subject), "Status": pcieHealth(item.Status),
	}}
}
func certificateInventory(c *gofish.APIClient) any {
	resp, err := c.Get("/redfish/v1/CertificateTests")
	must(err, "certificate manifest")
	defer schemas.DeferredCleanupHTTPResponse(resp)
	var manifest struct {
		Cases []struct{ ID, URI, Kind string }
	}
	must(json.NewDecoder(resp.Body).Decode(&manifest), "certificate manifest JSON")
	out := map[string]any{}
	for _, probe := range manifest.Cases {
		var val any
		var err error
		switch probe.Kind {
		case "certificate", "subjects":
			var owner *schemas.Certificate
			owner, err = schemas.GetCertificate(c, probe.URI)
			if err == nil {
				if probe.Kind == "certificate" {
					val = certificateJSON(owner)
				} else {
					var items []*schemas.Certificate
					items, err = owner.Subjects()
					val = bootItems(items, certificateJSON)
				}
			}
		case "service":
			var root *gofish.Service
			root, err = schemas.GetObject[gofish.Service](c, probe.URI)
			if err == nil {
				var item *schemas.CertificateService
				item, err = root.CertificateService()
				if item == nil {
					val = map[string]any{"state": "nil"}
				} else {
					val = parityValue(taskEntity(&item.Entity))
				}
			}
		case "locations":
			var owner *schemas.CertificateService
			owner, err = schemas.GetCertificateService(c, probe.URI)
			if err == nil {
				var item *schemas.CertificateLocations
				item, err = owner.CertificateLocations()
				if item == nil {
					val = map[string]any{"state": "nil"}
				} else {
					val = parityValue(taskEntity(&item.Entity))
				}
			}
		case "located":
			var owner *schemas.CertificateLocations
			owner, err = schemas.GetCertificateLocations(c, probe.URI)
			if err == nil {
				var items []*schemas.Certificate
				items, err = owner.Certificates()
				val = bootItems(items, certificateJSON)
			}
		case "database_certificates":
			var owner *schemas.SecureBootDatabase
			owner, err = schemas.GetSecureBootDatabase(c, probe.URI)
			if err == nil {
				var items []*schemas.Certificate
				items, err = owner.Certificates()
				val = bootItems(items, certificateJSON)
			}
		case "system_certificates", "boot_certificates":
			var owner *schemas.ComputerSystem
			owner, err = schemas.GetComputerSystem(c, probe.URI)
			if err == nil {
				var items []*schemas.Certificate
				if probe.Kind == "boot_certificates" {
					items, err = owner.Boot.Certificates(c)
				} else {
					items, err = owner.Certificates()
				}
				val = bootItems(items, certificateJSON)
			}
		default:
			panic("invalid certificate operation")
		}
		out[probe.ID] = map[string]any{"ok": err == nil, "error": parityError(err), "value": val}
	}
	return map[string]any{"cases": out}
}
