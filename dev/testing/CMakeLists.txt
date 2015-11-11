
# Set this variable to the minimum coverage percentage to be considered passing
set(COVERAGE_MINIMUM_PASS 90)

testlib_init()

add_python_style_test(ansible_filters_analysis
                      "${PROJECT_SOURCE_DIR}/filter_plugins")

add_vagrant_pod(basic3 basic-3)

# add_ansible_test("ssh-known-hosts" POD basic3 "ssh-known-hosts")
add_ansible_test("dummy" POD basic3 "dummy")

