.PHONY: format format-check check test dev run

format:
	cd stdx && gleam format
	cd protocol && gleam format
	cd shiroko && gleam format

format-check:
	cd stdx && gleam format --check
	cd protocol && gleam format --check
	cd shiroko && gleam format --check

check:
	cd shiroko && gleam check

test:
	cd stdx && gleam test
	cd protocol && gleam test
	cd shiroko && gleam test

dev:
	cd shiroko && gleam dev

run:
	cd shiroko && gleam run
