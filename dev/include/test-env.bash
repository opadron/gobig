
check_set() {
    var="$1" ; shift
    val="$*"

    if eval '[ -z "${'"$var"'+set}" ]' ; then
        export $var="$val"
    fi
}

if [ "$TRAVIS" '=' 'true' ] ; then
    echo "TRAVIS CI DETECTED"
    echo

    check_set APT_SUDO "sudo -H"
    check_set PIP_SUDO ""

    check_set PYTHON_VERSION         "${TRAVIS_PYTHON_VERSION:0:1}"
    check_set CTEST_SOURCE_DIRECTORY "$TRAVIS_BUILD_DIR"
    check_set CTEST_BINARY_DIRECTORY "$TRAVIS_BUILD_DIR/_build"
    check_set CTEST_SITE             "(travis-ci)"
    check_set FULL_VIRTUALIZATION    NO
    check_set BRANCH                 "$TRAVIS_BRANCH"
    check_set PYTHON_COVERAGE        OFF
else
    # test to see if we are in a VM
    if (ls -1 /dev/disk/by-id/ | grep -q VBOX &> /dev/null) ; then
        echo "VIRTUALBOX DETECTED"
        echo
        check_set FULL_VIRTUALIZATION NO
        check_set PYTHON_COVERAGE     OFF
    fi

    # check for root
    if [ "$USER" '=' 'root' ] ; then
        echo "ROOT DETECTED"
        check_set APT_SUDO ""
        check_set PIP_SUDO ""
    fi

    # check for a python virtualenv
    if [ -n "$VIRTUAL_ENV" ] ; then
        echo "PYTHON VIRTUALENV DETECTED"
        check_set PIP_SUDO ""
    fi

    check_set APT_SUDO "sudo -H"
    check_set PIP_SUDO "sudo -H"

    tmp="$( python --version 2>&1 | cut -d\  -f 2 )"
    check_set PYTHON_VERSION         "${tmp:0:1}"
    check_set CTEST_SOURCE_DIRECTORY "$(pwd)"
    check_set CTEST_BINARY_DIRECTORY "$(pwd)/_build"
    check_set FULL_VIRTUALIZATION    YES
    check_set CTEST_SITE "$(
        (hostname --fqdn || hostname --long || hostname) 2>/dev/null )"
    check_set BRANCH "$(
        git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')"
    check_set PYTHON_COVERAGE     ON
fi

check_set BOTO_VERSION "$(
    python -c "import boto; print(boto.Version)" 2>/dev/null )"

check_set ANSIBLE_VERSION "$(
    ( ansible --version 2>/dev/null ) | head -n 1 | cut -d\  -f 2 )"

