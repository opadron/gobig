
set(py_coverage_rc "${PROJECT_BINARY_DIR}/dev/testing/coveragerc")
set(flake8_config "${PROJECT_SOURCE_DIR}/dev/testing/flake8.cfg")
set(coverage_html_dir "${PROJECT_BINARY_DIR}/py_coverage")

if(PYTHON_BRANCH_COVERAGE)
    set(_py_branch_cov True)
else()
    set(_py_branch_cov False)
endif()

configure_file("${PROJECT_SOURCE_DIR}/dev/testing/coveragerc.in"
               "${py_coverage_rc}" @ONLY)

function(testlib_init)
    if(PYTHON_COVERAGE)
        add_test(NAME py_coverage_reset
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${PYTHON_COVERAGE_EXECUTABLE}" erase
                     "--rcfile=${py_coverage_rc}")

        add_test(NAME py_coverage_combine
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${PYTHON_COVERAGE_EXECUTABLE}" combine)

        add_test(NAME py_coverage
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${PYTHON_COVERAGE_EXECUTABLE}" report
                     "--fail-under=${COVERAGE_MINIMUM_PASS}")

        add_test(NAME py_coverage_html
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${PYTHON_COVERAGE_EXECUTABLE}" html
                     -d "${coverage_html_dir}" "--title=GoBig Coverage Report")

        add_test(NAME py_coverage_xml
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${PYTHON_COVERAGE_EXECUTABLE}" xml
                     -o "${PROJECT_BINARY_DIR}/coverage.xml")

        set_property(TEST py_coverage      PROPERTY DEPENDS py_coverage_combine)
        set_property(TEST py_coverage_html PROPERTY DEPENDS py_coverage)
        set_property(TEST py_coverage_xml  PROPERTY DEPENDS py_coverage)
    endif()
endfunction()

function(add_python_style_test name input)
    if(PYTHON_STATIC_ANALYSIS)
        add_test(NAME ${name}
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${FLAKE8_EXECUTABLE}"
                     "--config=${flake8_config}" "${input}")
    endif()
endfunction()

function(add_vagrant_pod alias cfg)
    if(FULL_VIRTUALIZATION)

        add_test(NAME vagrant_up_${alias}
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${VAGRANT_EXECUTABLE}" up --no-provision)

        set(vagrant_file "${PROJECT_SOURCE_DIR}/dev/testing/Vagrantfile")
        set(pod_file "${PROJECT_SOURCE_DIR}/dev/testing/${cfg}.yml")

        set_property(TEST vagrant_up_${alias} PROPERTY ENVIRONMENT
                     "VAGRANT_VAGRANTFILE=${vagrant_file}"
                     "VAGRANT_POD_FILE=${pod_file}")


        add_test(NAME vagrant_destroy_${alias}
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${VAGRANT_EXECUTABLE}" destroy -f)

        set_property(TEST vagrant_destroy_${alias} PROPERTY ENVIRONMENT
                     "VAGRANT_VAGRANTFILE=${vagrant_file}"
                     "VAGRANT_POD_FILE=${pod_file}")

        set_property(TEST vagrant_destroy_${alias} APPEND PROPERTY
                     DEPENDS vagrant_up_${alias})

        add_test(NAME vagrant_meta_${alias}
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND true)

        set_property(TEST vagrant_meta_${alias} APPEND PROPERTY
                     DEPENDS vagrant_up_${alias})

        set_property(TEST vagrant_meta_${alias} APPEND PROPERTY
                     DEPENDS vagrant_destroy_${alias})

        set_property(TEST vagrant_meta_${alias} PROPERTY
                     "VAGRANT_POD_FILE=${pod_file}")
    endif()
endfunction()

function(add_ansible_test alias mode alias2 test_case)
    if(mode STREQUAL "TEST")
        get_property(pod_alias TEST ansible_meta_${alias2}
                     PROPERTY VAGRANT_POD)
    elseif(mode STREQUAL "POD")
        set(pod_alias ${alias2})
    endif()

    if(FULL_VIRTUALIZATION)
        get_property(pod_file TEST vagrant_meta_${pod_alias}
                     PROPERTY VAGRANT_POD_FILE)
    endif()

    set(cases "${PROJECT_SOURCE_DIR}/dev/testing/cases")
    set(site_yml "${cases}/${test_case}/site.yml")
    set(unit_yml "${cases}/${test_case}/unit.yml")

    if(FULL_VIRTUALIZATION)
        set(inventory "${PROJECT_SOURCE_DIR}/.vagrant/provisioners/ansible")
        set(inventory "${inventory}/inventory/vagrant_ansible_inventory")
    else()
        set(inventory "/dev/null")
    endif()

    if(PYTHON_COVERAGE)
        add_test(NAME ansible_static_${alias}
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${PYTHON_COVERAGE_EXECUTABLE}"
                         run --append "--rcfile=${py_coverage_rc}"
                         "--source=${PROJECT_SOURCE_DIR}/filter_plugins"
                         "${ANSIBLE_PLAYBOOK_EXECUTABLE}" --syntax-check
                             -i "/dev/null"
                             "${site_yml}")
    else()
        add_test(NAME ansible_static_${alias}
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${ANSIBLE_PLAYBOOK_EXECUTABLE}" --syntax-check
                             -i "/dev/null"
                             "${site_yml}")
    endif()

    if(FULL_VIRTUALIZATION)
        if(PYTHON_COVERAGE)
                add_test(NAME ansible_provision_${alias}
                         WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                         COMMAND "${PYTHON_COVERAGE_EXECUTABLE}"
                                 run -p --append "--rcfile=${py_coverage_rc}"
                                 "--source=${PROJECT_SOURCE_DIR}/filter_plugins"
                                 "${ANSIBLE_PLAYBOOK_EXECUTABLE}"
                                     --become -u vagrant
                                     -i "${inventory}"
                                     "${site_yml}")
        else()
            add_test(NAME ansible_provision_${alias}
                     WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                     COMMAND "${ANSIBLE_PLAYBOOK_EXECUTABLE}"
                             --become -u vagrant
                             -i "${inventory}"
                             "${site_yml}")
        endif()

        set_property(TEST ansible_provision_${alias} APPEND PROPERTY
                     DEPENDS ansible_static_${alias})

        set_property(TEST ansible_provision_${alias} APPEND PROPERTY
                     DEPENDS vagrant_up_${pod_alias})

        if(mode STREQUAL "TEST")
            set_property(TEST ansible_provision_${alias} APPEND PROPERTY
                         DEPENDS ansible_provision_${alias2})
        endif()

        add_test(NAME ansible_idempotency_${alias}
                 WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                 COMMAND "${PROJECT_SOURCE_DIR}/dev/testing/test-idempotency"
                         "${ANSIBLE_PLAYBOOK_EXECUTABLE}"
                             --become -u vagrant
                             -i "${inventory}"
                             "${site_yml}")

        if(PYTHON_COVERAGE)
            set(pcexe "${PYTHON_COVERAGE_EXECUTABLE}")
            set_property(TEST ansible_idempotency_${alias} PROPERTY ENVIRONMENT
                         "PYTHON_COVERAGE_EXECUTABLE=${pcexe}"
                         "COVERAGE_RC=${py_coverage_rc}"
                         "PROJECT_SOURCE_DIR=${PROJECT_SOURCE_DIR}")
        endif()

        set_property(TEST ansible_idempotency_${alias} APPEND PROPERTY
                     DEPENDS ansible_provision_${alias})

        set_property(TEST ansible_idempotency_${alias} APPEND PROPERTY
                     DEPENDS vagrant_up_${pod_alias})

        if(PYTHON_COVERAGE)
            add_test(NAME ansible_unit_${alias}
                     WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                     COMMAND "${PYTHON_COVERAGE_EXECUTABLE}"
                             run -p --append "--rcfile=${py_coverage_rc}"
                             "--source=${PROJECT_SOURCE_DIR}/filter_plugins"
                             "${ANSIBLE_PLAYBOOK_EXECUTABLE}"
                                 --become -u vagrant
                                 -i "${inventory}"
                                 "${unit_yml}")
        else()
            add_test(NAME ansible_unit_${alias}
                     WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
                     COMMAND "${ANSIBLE_PLAYBOOK_EXECUTABLE}"
                             --become -u vagrant
                             -i "${inventory}"
                             "${unit_yml}")
        endif()

        set_property(TEST ansible_unit_${alias} APPEND PROPERTY
                     DEPENDS ansible_static_${alias})

        set_property(TEST ansible_unit_${alias} APPEND PROPERTY
                     DEPENDS ansible_provision_${alias})

        set_property(TEST ansible_unit_${alias} APPEND PROPERTY
                     DEPENDS vagrant_up_${pod_alias})
    endif()


    add_test(NAME ansible_meta_${alias}
             WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
             COMMAND true)

    set_property(TEST ansible_meta_${alias} APPEND PROPERTY
                 DEPENDS ansible_static_${alias})

    if(FULL_VIRTUALIZATION)
        set_property(TEST ansible_meta_${alias} APPEND PROPERTY
                     DEPENDS ansible_provision_${alias})
        set_property(TEST ansible_meta_${alias} APPEND PROPERTY
                     DEPENDS ansible_idempotency_${alias})
        set_property(TEST ansible_meta_${alias} APPEND PROPERTY
                     DEPENDS ansible_unit_${alias})

        set_property(TEST ansible_meta_${alias} PROPERTY
                     VAGRANT_POD "${pod_alias}")

        set_property(TEST vagrant_destroy_${pod_alias} APPEND PROPERTY
                     DEPENDS ansible_meta_${pod_alias})
    endif()

    if(PYTHON_COVERAGE)
        set_property(TEST ansible_meta_${alias} APPEND PROPERTY
                     DEPENDS py_coverage_reset)

        set_property(TEST py_coverage_combine APPEND PROPERTY
                     DEPENDS ansible_meta_${alias})
    endif()
endfunction()

