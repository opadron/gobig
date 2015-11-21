
check_set() {
    var="$1" ; shift
    val="$*"

    if eval '[ -z "${'"$var"'+set}" ]' ; then
        export $var="$val"
    fi
}

__apt_wrap() {
    header="$1" ; shift
    if [ "$header" '=' 'sudo' ] ; then
        header="sudo -H"
    fi
    if [ "$header" '=' 'nosudo' ] ; then
        header=""
    fi

    if [ -z "$__apt_wrap_updated" ] ; then
        export __apt_wrap_updated=1
        $header apt-get update
    fi

    $header apt-get -qyy install "$@"
    return $?
}

__dpkg_wrap() {
    header="$1" ; shift
    if [ "$header" '=' 'sudo' ] ; then
        header="sudo -H"
    fi
    if [ "$header" '=' 'nosudo' ] ; then
        header=""
    fi

    $header dpkg -i "$@"
    return $?
}

__pip_wrap() {
    header="$1" ; shift
    if [ "$header" '=' 'sudo' ] ; then
        header="sudo -H"
    fi
    if [ "$header" '=' 'nosudo' ] ; then
        header=""
    fi

    if [ -z "$__pip_wrap_updated" ] ; then
        export __pip_wrap_updated=1
        $header pip install -U pip
        $header pip install -U setuptools
    fi

    $header pip install -U "$@"
    return $?
}

if [ "$TRAVIS" '=' 'true' ] ; then
    echo "TRAVIS CI DETECTED"
    echo

    check_set APT  "true"
    check_set DPKG "true"
    check_set PIP  "__pip_wrap nosudo"

    check_set PYTHON_VERSION         "${TRAVIS_PYTHON_VERSION:0:1}"
    check_set CTEST_SOURCE_DIRECTORY "$TRAVIS_BUILD_DIR"
    check_set CTEST_BINARY_DIRECTORY "$TRAVIS_BUILD_DIR/_build"
    check_set CTEST_SITE             "(travis-ci)"
    check_set FULL_VIRTUALIZATION    NO
    check_set EMULATION              NO
    check_set BRANCH                 "$TRAVIS_BRANCH"
else
    # test to see if we are in a VirtualBox VM
    if [ -d /dev/disk/by-id ] ; then
        if (ls -1 /dev/disk/by-id/ | grep -q VBOX &> /dev/null) ; then
            echo "VIRTUALBOX DETECTED"
            echo
            check_set FULL_VIRTUALIZATION NO
            check_set EMULATION           YES
        fi
    fi

    # test to see if we are in a Xen VM
    if [ -d /proc/xen ] ; then
        echo "XEN DETECTED"
        echo
        check_set FULL_VIRTUALIZATION NO
        check_set EMULATION           YES
    fi

    # check for a python virtualenv
    if [ -n "$VIRTUAL_ENV" ] ; then
        echo "PYTHON VIRTUALENV DETECTED"
        check_set PIP "__pip_wrap nosudo"
    fi

    # check for root
    if [ "$USER" '=' 'root' ] ; then
        echo "ROOT DETECTED"
        check_set APT  "__apt_wrap nosudo"
        check_set DPKG "__dpkg_wrap nosudo"
        check_set PIP  "__pip_wrap nosudo"
    fi

    check_set APT "__apt_wrap sudo"
    check_set DPKG "__dpkg_wrap sudo"
    check_set PIP "__pip_wrap sudo"

    tmp="$( python --version 2>&1 | cut -d\  -f 2 )"
    check_set PYTHON_VERSION         "${tmp:0:1}"
    check_set CTEST_SOURCE_DIRECTORY "$(pwd)"
    check_set CTEST_BINARY_DIRECTORY "$(pwd)/_build"
    check_set FULL_VIRTUALIZATION    YES
    check_set EMULATION              NO
    check_set CTEST_SITE "$(
        (hostname --fqdn || hostname --long || hostname) 2>/dev/null )"
    check_set BRANCH "$(
        git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')"
fi

if [ "$FULL_VIRTUALIZATION" '=' 'YES' -o "$EMULATION" '=' 'YES' ] ; then
    check_set PYTHON_COVERAGE ON
fi

if [ "$EMULATION" '=' 'YES' ] ; then
    check_set VAGRANT_DEFAULT_PROVIDER libvirt
fi

check_set PYTHON_COVERAGE OFF

check_set BOTO_VERSION "$(
    python -c "import boto; print(boto.Version)" 2>/dev/null )"

check_set ANSIBLE_VERSION "$(
    ( ansible --version 2>/dev/null ) | head -n 1 | cut -d\  -f 2 )"

