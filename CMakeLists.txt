
cmake_minimum_required(VERSION 2.8.0)

project(GoBig NONE)

include(CTest)
enable_testing()

set(PYTHON_VERSION "2.7" CACHE STRING "Python version used for testing")

find_package(PythonInterp ${PYTHON_VERSION} REQUIRED)

option(PYTHON_STATIC_ANALYSIS "Run Python static analysis tests with flake8" ON)
option(PYTHON_COVERAGE "Run tests with coverage.py" ON)
option(PYTHON_BRANCH_COVERAGE
       "Use branch-level coverage instead of line-level" OFF)

if(PYTHON_COVERAGE)
    find_program(PYTHON_COVERAGE_EXECUTABLE coverage)
endif()

if(PYTHON_STATIC_ANALYSIS)
    find_program(FLAKE8_EXECUTABLE flake8)
endif()

set(FULL_VIRTUALIZATION "$ENV{FULL_VIRTUALIZATION}")

if(FULL_VIRTUALIZATION)
    find_program(VAGRANT_EXECUTABLE vagrant)
endif()

find_program(ANSIBLE_PLAYBOOK_EXECUTABLE "ansible-playbook")

if(BUILD_TESTING)
    include(dev/testing/testlib.cmake)
    add_subdirectory(dev/testing)
endif()

