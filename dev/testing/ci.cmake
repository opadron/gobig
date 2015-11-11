
set(CTEST_SOURCE_DIRECTORY "$ENV{CTEST_SOURCE_DIRECTORY}")
set(CTEST_BINARY_DIRECTORY "$ENV{CTEST_BINARY_DIRECTORY}")
set(FULL_VIRTUALIZATION "$ENV{FULL_VIRTUALIZATION}")

include(${CTEST_SOURCE_DIRECTORY}/CTestConfig.cmake)
set(CTEST_SITE "$ENV{CTEST_SITE}")
set(CTEST_BUILD_NAME
    "Linux-$ENV{BRANCH}-Ansible-$ENV{ANSIBLE_VERSION}-Boto-$ENV{BOTO_VERSION}")
set(CTEST_CMAKE_GENERATOR "Unix Makefiles")

ctest_start("Continuous")
ctest_configure()
ctest_build()
ctest_test(PARALLEL_LEVEL 1 RETURN_VALUE res)
ctest_coverage()
file(REMOVE "${CTEST_BINARY_DIRECTORY}/coverage.xml")
ctest_submit()

file(REMOVE "${CTEST_BINARY_DIRECTORY}/test_failed")
if(NOT res EQUAL 0)
    file(WRITE "${CTEST_BINARY_DIRECTORY}/test_failed" "error")
    message(FATAL_ERROR "Test failures occurred.")
endif()

