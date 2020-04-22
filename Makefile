export GO111MODULE=on
GOOS:=$(shell go env GOOS)

## Build
.PHONY: build qtdeploy check-has-go

VERSION?=1.2.6-git
REVISION:=$(shell git rev-parse --short=10 HEAD)
BUILD_TIME:=$(shell date +%FT%T%z)

BUILD_TAGS?=pmapi_prod
BUILD_FLAGS:=-tags='${BUILD_TAGS}'
BUILD_FLAGS_NOGUI:=-tags='${BUILD_TAGS} nogui'
GO_LDFLAGS:=$(addprefix -X main.,Version=${VERSION} Revision=${REVISION} BuildTime=${BUILD_TIME})
ifneq "${BUILD_LDFLAGS}" ""
    GO_LDFLAGS+= ${BUILD_LDFLAGS}
endif
GO_LDFLAGS:=-ldflags '${GO_LDFLAGS}'
BUILD_FLAGS+= ${GO_LDFLAGS}
BUILD_FLAGS_NOGUI+= ${GO_LDFLAGS}

DEPLOY_DIR:=cmd/Desktop-Bridge/deploy
ICO_FILES:=
EXE:=$(shell basename ${CURDIR})

ifeq "${GOOS}" "windows"
    EXE+=.exe
    ICO_FILES:=logo.ico icon.rc icon_windows.syso
endif
ifeq "${GOOS}" "darwin"
    DARWINAPP_CONTENTS:=${DEPLOY_DIR}/darwin/${EXE}.app/Contents
    EXE:=${EXE}.app/Contents/MacOS/${EXE}
endif
EXE_TARGET:=${DEPLOY_DIR}/${GOOS}/${EXE}
TGZ_TARGET:=bridge_${GOOS}_${REVISION}.tgz

build: ${TGZ_TARGET}

${TGZ_TARGET}: ${DEPLOY_DIR}/${GOOS}
	rm -f $@
	cd ${DEPLOY_DIR} && tar czf ../../../$@ ${GOOS}

${DEPLOY_DIR}/linux: ${EXE_TARGET}
	cp -pf ./internal/frontend/share/icons/logo.svg ${DEPLOY_DIR}/linux/
	cp -pf ./LICENSE ${DEPLOY_DIR}/linux/
	cp -pf ./Changelog.md ${DEPLOY_DIR}/linux/

${DEPLOY_DIR}/darwin: ${EXE_TARGET}
	cp ./internal/frontend/share/icons/Bridge.icns ${DARWINAPP_CONTENTS}/Resources/
	cp -r "utils/addcert.scpt" ${DARWINAPP_CONTENTS}/Resources/
	cp LICENSE ${DARWINAPP_CONTENTS}/Resources/
	rm -rf "${DARWINAPP_CONTENTS}/Frameworks/QtWebEngine.framework"
	rm -rf "${DARWINAPP_CONTENTS}/Frameworks/QtWebView.framework"
	rm -rf "${DARWINAPP_CONTENTS}/Frameworks/QtWebEngineCore.framework"

${DEPLOY_DIR}/windows: ${EXE_TARGET}
	cp ./internal/frontend/share/icons/logo.ico ${DEPLOY_DIR}/windows/

${EXE_TARGET}: check-has-go gofiles ${ICO_FILES} update-vendor
	rm -rf deploy ${GOOS} ${DEPLOY_DIR}
	cp cmd/Desktop-Bridge/main.go .
	qtdeploy ${BUILD_FLAGS} build desktop
	mv deploy cmd/Desktop-Bridge
	rm -rf ${GOOS} main.go

qtdeploy: check-has-go gofiles ${ICO_FILES}
	go mod vendor
	rm -rf deploy ${GOOS} ${DEPLOY_DIR}
	cp cmd/Desktop-Bridge/main.go .
	qtdeploy ${BUILD_FLAGS} build desktop
	mv deploy cmd/Desktop-Bridge
	rm -rf ${GOOS} main.go

logo.ico: ./internal/frontend/share/icons/logo.ico
	cp $^ .
icon.rc: ./internal/frontend/share/icon.rc
	cp $^ .
./internal/frontend/qt/icon_windows.syso: ./internal/frontend/share/icon.rc  logo.ico 
	windres $< $@
icon_windows.syso: ./internal/frontend/qt/icon_windows.syso
	cp $^ .


## Rules for therecipe/qt
.PHONY: prepare-vendor update-vendor
THERECIPE_QTVER:=$(shell grep "github.com/therecipe/qt " go.mod | sed -r 's;.* v[0-9\.]+-[0-9]+-([a-f0-9]*).*;\1;')
THERECIPE_ENV:=github.com/therecipe/env_${GOOS}_amd64_513

# vendor folder will be deleted by gomod hence we cache the big repo
# therecipe/env in order to download it only once
vendor-cache/${THERECIPE_ENV}:
	git clone https://${THERECIPE_ENV}.git vendor-cache/${THERECIPE_ENV}

LINKCMD:=ln -sf ${CURDIR}/vendor-cache/${THERECIPE_ENV} vendor/${THERECIPE_ENV}
ifeq "${GOOS}" "windows"
    WINDIR:=$(subst /c/,c:\\,${CURDIR})/vendor-cache/${THERECIPE_ENV}
    LINKCMD:=cmd //c 'mklink $(subst /,\,vendor\${THERECIPE_ENV} ${WINDIR})'
endif

prepare-vendor:
	go install -v -tags=no_env github.com/therecipe/qt/cmd/...
	go mod vendor

# update-vendor is PHONY because we need to make sure that we always have updated vendor
update-vendor: vendor-cache/${THERECIPE_ENV} prepare-vendor
	${LINKCMD}


## Dev dependencies
.PHONY: install-devel-tools install-linter install-go-mod-outdated
LINTVER:="v1.23.6"
LINTSRC:="https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh"

install-dev-dependencies: install-devel-tools install-linter install-go-mod-outdated

install-devel-tools: check-has-go
	go get -v github.com/golang/mock/gomock
	go get -v github.com/golang/mock/mockgen
	go get -v github.com/go-delve/delve

install-linter: check-has-go
	curl -sfL $(LINTSRC) | sh -s -- -b $(shell go env GOPATH)/bin $(LINTVER)

install-go-mod-outdated:
	which go-mod-outdated || go get -u github.com/psampaz/go-mod-outdated


## Checks, mocks and docs
.PHONY: check-has-go check-license test bench coverage mocks lint updates doc
check-has-go:
	@which go || (echo "Install Go-lang!" && exit 1)

check-license:
	find . -not -path "./vendor/*" -not -name "*mock*.go" -regextype posix-egrep -regex ".*\.go|.*\.qml" -exec grep -L "Copyright (c) 2020 Proton Technologies AG" {} \;

test: gofiles
	@# Listing packages manually to not run Qt folder (which needs to run qtsetup first) and integration tests.
	go test -coverprofile=/tmp/coverage.out -run=${TESTRUN} \
		./internal/api/... \
		./internal/bridge/... \
		./internal/events/... \
		./internal/frontend/autoconfig/... \
		./internal/frontend/cli/... \
		./internal/imap/... \
		./internal/preferences/... \
		./internal/smtp/... \
		./internal/store/... \
		./pkg/...

bench:
	go test -run '^$$' -bench=. -memprofile bench_mem.pprof -cpuprofile bench_cpu.pprof ./internal/store
	go tool pprof -png -output bench_mem.png bench_mem.pprof
	go tool pprof -png -output bench_cpu.png bench_cpu.pprof

coverage: test
	go tool cover -html=/tmp/coverage.out -o=coverage.html

mocks:
	mockgen --package mocks github.com/ProtonMail/proton-bridge/internal/bridge Configer,PreferenceProvider,PanicHandler,PMAPIProvider,CredentialsStorer > internal/bridge/mocks/mocks.go
	mockgen --package mocks github.com/ProtonMail/proton-bridge/internal/store PanicHandler,BridgeUser > internal/store/mocks/mocks.go
	mockgen --package mocks github.com/ProtonMail/proton-bridge/pkg/listener Listener > internal/store/mocks/utils_mocks.go

lint:
	which golangci-lint || $(MAKE) install-linter
	golangci-lint run ./...

updates: install-go-mod-outdated
	# Uncomment the "-ci" to fail the job if something can be updated.
	go list -u -m -json all | go-mod-outdated -update -direct #-ci

doc:
	godoc -http=:6060

.PHONY: gofiles
# Following files are for the whole app so it makes sense to have them in bridge package.
# (Options like cmd or internal were considered and bridge package is the best place for them.)
gofiles: ./internal/bridge/credits.go ./internal/bridge/release_notes.go
./internal/bridge/credits.go: ./utils/credits.sh go.mod
	cd ./utils/ && ./credits.sh
./internal/bridge/release_notes.go: ./utils/release-notes.sh ./release-notes/notes.txt ./release-notes/bugs.txt
	cd ./utils/ && ./release-notes.sh


## Run and debug
.PHONY: run run-qt run-qt-cli run-nogui run-nogui-cli run-debug qmlpreview qt-fronted-clean clean
VERBOSITY?=debug-client
RUN_FLAGS:=-m -l=${VERBOSITY}

run: run-nogui-cli

run-qt: ${EXE_TARGET}
	PROTONMAIL_ENV=dev ./$< ${RUN_FLAGS} | tee last.log
run-qt-cli: ${EXE_TARGET}
	PROTONMAIL_ENV=dev ./$< ${RUN_FLAGS} -c

run-nogui: clean-vendor gofiles
	PROTONMAIL_ENV=dev go run ${BUILD_FLAGS_NOGUI} cmd/Desktop-Bridge/main.go ${RUN_FLAGS} | tee last.log
run-nogui-cli: clean-vendor gofiles
	PROTONMAIL_ENV=dev go run ${BUILD_FLAGS_NOGUI} cmd/Desktop-Bridge/main.go ${RUN_FLAGS} -c

run-debug:
	PROTONMAIL_ENV=dev dlv debug --build-flags "${BUILD_FLAGS_NOGUI}" cmd/Desktop-Bridge/main.go -- ${RUN_FLAGS}

run-qml-preview:
	make -C internal/frontend/qt -f Makefile.local qmlpreview

clean-frontend-qt:
	make -C internal/frontend/qt -f Makefile.local clean

clean-vendor: clean-frontend-qt
	rm -rf ./vendor

clean: clean-frontend-qt
	rm -rf vendor-cache
	rm -rf cmd/Desktop-Bridge/deploy
	rm -f build last.log mem.pprof
