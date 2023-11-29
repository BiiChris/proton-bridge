// Copyright (c) 2023 Proton AG
//
// This file is part of Proton Mail Bridge.
//
// Proton Mail Bridge is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Mail Bridge is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Mail Bridge. If not, see <https://www.gnu.org/licenses/>.

package clientconfig

import (
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/ProtonMail/proton-bridge/v3/internal/useragent"
	"github.com/ProtonMail/proton-bridge/v3/pkg/mobileconfig"
	"golang.org/x/sys/execabs"
)

const (
	bigSurPreferencesPane  = "/System/Library/PreferencePanes/Profiles.prefPane"
	venturaPreferencesPane = "x-apple.systempreferences:com.apple.preferences.configurationprofiles"
)

type AppleMail struct{}

func (c *AppleMail) Configure(
	hostname string,
	imapPort, smtpPort int,
	imapSSL, smtpSSL bool,
	username, displayName, addresses string,
	password []byte,
) error {
	mc := prepareMobileConfig(hostname, imapPort, smtpPort, imapSSL, smtpSSL, username, displayName, addresses, password)

	confPath, err := saveConfigTemporarily(mc)
	if err != nil {
		return err
	}

	if useragent.IsBigSurOrNewer() {
		prefPane := bigSurPreferencesPane

		if useragent.IsVenturaOrNewer() {
			prefPane = venturaPreferencesPane
		}

		return execabs.Command("open", prefPane, confPath).Run() //nolint:gosec // G204 open command is safe, mobileconfig is generated by us
	}

	return execabs.Command("open", confPath).Run() //nolint:gosec // G204 open command is safe, mobileconfig is generated by us
}

func prepareMobileConfig(
	hostname string,
	imapPort, smtpPort int,
	imapSSL, smtpSSL bool,
	username, displayName, addresses string,
	password []byte,
) *mobileconfig.Config {
	return &mobileconfig.Config{
		DisplayName:        username,
		EmailAddress:       addresses,
		AccountName:        displayName,
		AccountDescription: username,
		Identifier:         "protonmail " + username + strconv.FormatInt(time.Now().Unix(), 10),
		IMAP: &mobileconfig.IMAP{
			Hostname: hostname,
			Port:     imapPort,
			TLS:      imapSSL,
			Username: username,
			Password: string(password),
		},
		SMTP: &mobileconfig.SMTP{
			Hostname: hostname,
			Port:     smtpPort,
			TLS:      smtpSSL,
			Username: username,
			Password: string(password),
		},
	}
}

func saveConfigTemporarily(mc *mobileconfig.Config) (fname string, err error) {
	dir, err := os.MkdirTemp("", "protonmail-autoconfig")
	if err != nil {
		return
	}

	// Make sure the temporary file is deleted.
	go func() {
		defer recover() //nolint:errcheck

		<-time.After(10 * time.Minute)
		_ = os.RemoveAll(dir)
	}()

	// Make sure the file is only readable for the current user.
	fname = filepath.Clean(filepath.Join(dir, "protonmail.mobileconfig"))
	f, err := os.OpenFile(fname, os.O_RDWR|os.O_CREATE, 0o600) //nolint:gosec
	if err != nil {
		return
	}

	mc.WriteOut(f)
	
	_ = f.Close()
	return
}
