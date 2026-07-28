# Aidevix CLI — ishlab chiqish (development) buyruqlari.
#
#   make test      — bats testlarini ishga tushiradi
#   make lint      — shellcheck (agar o'rnatilgan bo'lsa)
#   make syntax    — barcha skriptlarda `bash -n` sintaksis tekshiruvi
#   make check     — syntax + lint + test (CI bilan bir xil)
#   make install-dev — bats'ni npm orqali o'rnatadi

SHELL := /usr/bin/env bash

# lib/ui.sh va i18n fayllari HAM shu ro'yxatda bo'lishi shart — aks holda
# dizayn tizimi (500+ qator) umuman lint/sintaksis tekshiruvidan o'tmaydi.
SCRIPTS := bootstrap.sh install.sh uninstall.sh bin/ai-selector.sh \
           lib/common.sh lib/ui.sh lib/i18n.sh lib/i18n/en.sh \
           completions/aidevix.bash

.PHONY: test lint syntax check install-dev help

help:
	@echo "Buyruqlar: test · lint · syntax · check · install-dev"

test:
	@bats --print-output-on-failure tests/

lint:
	@command -v shellcheck >/dev/null 2>&1 \
		&& shellcheck -e SC1091 $(SCRIPTS) && echo "✓ shellcheck toza" \
		|| echo "! shellcheck topilmadi — o'tkazib yuborildi"

syntax:
	@set -e; for f in $(SCRIPTS); do echo "→ $$f"; bash -n "$$f"; done; \
		echo "✓ Barcha skriptlar sintaktik to'g'ri."

check: syntax lint test

install-dev:
	@npm install -g bats && bats --version
