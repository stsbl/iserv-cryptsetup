LOCALE_DISABLE_POOTLE_DOWNLOAD=1

TEST_TARGETS += integration_tests

.PHONY: integration_tests
integration_tests:
	tests/integration_test.sh
