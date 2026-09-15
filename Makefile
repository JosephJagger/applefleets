.PHONY: ios-project mac-build mac-test demo install install-with-codex uninstall

ios-project:
	xcodegen generate

mac-build:
	cd Mac && swift build -c release

mac-test:
	cd Mac && swift test

demo: mac-build
	cd Mac && .build/release/applefleets demo

install:
	./scripts/install-mac-agent.sh

install-with-codex:
	./scripts/install-mac-agent.sh --codex

uninstall:
	./scripts/uninstall-mac-agent.sh

