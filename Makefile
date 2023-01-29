MAKEFILE_PATH		:= $(realpath $(firstword $(MAKEFILE_LIST)))
GIT_ROOT		:= $(shell dirname $(MAKEFILE_PATH))
VENV_ROOT		:= $(GIT_ROOT)/.venv

PACKAGE_NAME		:= gevent
REQUIREMENTS_FILE	:= dev-requirements.txt

PACKAGE_PATH		:= $(GIT_ROOT)/$(PACKAGE_NAME)
REQUIREMENTS_PATH	:= $(GIT_ROOT)/$(REQUIREMENTS_FILE)
export VENV		?= $(VENV_ROOT)


# Weirdly, this has to be a top-level key, not ``defaults.env``
export PYTHONHASHSEED			:=	8675309
export PYTHONUNBUFFERED		:=	1
export PYTHONDONTWRITEBYTECODE		:=	1
export PIP_UPGRADE_STRATEGY		:=	eager
export PIP_NO_PYTHON_VERSION_WARNING	:=	1
export PIP_NO_WARN_SCRIPT_LOCATION	:=	1
export GEVENTSETUP_EV_VERIFY		:=	1
export CFLAGS				:=	-O3 -pipe -Wno-strict-aliasing -Wno-comment -Wno-parentheses-equality
export CPPFLAGS			:=	-DEV_VERIFY=1
export TWINE_USERNAME			:=	__token__
export CCACHE_DIR			:=	$(HOME)/.ccache
export CC				:=	"ccache gcc"
export CCACHE_NOCPP2			:=	true
export CCACHE_SLOPPINESS		:=	file_macro,time_macros,include_file_ctime,include_file_mtime
export CCACHE_NOHASHDIR		:=	true

######################################################################
# Phony targets (only exist for typing convenience and don't represent
#                real paths as Makefile expects)
######################################################################


all: | venv dependencies tests  # default target when running `make` without arguments

help:
	@egrep -h '^[^:]+:\s#\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?# "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build:
	export BUILD_LIBS="$HOME/.libs/"
	mkdir -p $BUILD_LIBS
	export LDFLAGS=-L$BUILD_LIBS/lib
	export CPPFLAGS="-I$BUILD_LIBS/include"
	env | sort
	echo which sed? `which sed`
	echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$BUILD_LIBS/lib >>$GITHUB_ENV
	(pushd deps/libev && sh ./configure -C --prefix=$BUILD_LIBS && make install && popd)
	(pushd deps/c-ares && sh ./configure -C --prefix=$BUILD_LIBS && make -j4 install && popd)
	(pushd deps/libuv && ./autogen.sh && sh ./configure -C --disable-static --prefix=$BUILD_LIBS && make -j4 install && popd)
	rm -rf $BUILD_LIBS/share/man/
	ls -l $BUILD_LIBS $BUILD_LIBS/lib $BUILD_LIBS/include
	python setup.py bdist_wheel
	pip uninstall -y gevent
	pip install -U `ls dist/*whl`[test]
	objdump -p build/lib*/gevent/libev/_corecffi*so | grep "NEEDED.*libev.so"
	objdump -p build/lib*/gevent/libev/corecext*so | grep "NEEDED.*libev.so"
	objdump -p build/lib*/gevent/libuv/_corecffi*so | grep "NEEDED.*libuv.so"
	objdump -p build/lib*/gevent/resolver/cares*so | grep "NEEDED.*libcares.so"

# creates virtualenv
venv: | $(VENV)

# updates pip and setuptools to their latest version
develop: | $(VENV)/bin/python $(VENV)/bin/pip

# installs the requirements and the package dependencies
setup: | dependencies

# Convenience target to ensure that the venv exists and all
# requirements are installed
dependencies:
	$(MAKE) develop setup

# Run all tests, separately
tests:
	python -c 'import gevent.libev.corecffi as CF; assert not CF.LIBEV_EMBED'
	python -c 'import gevent.libuv.loop as CF; assert not CF.libuv.LIBUV_EMBED'
	python -mgevent.tests --second-chance


# Convenience target to delete the virtualenv
clean:
	@rm -rf $(VENV)

##############################################################
# Real targets (only run target if its file has been "made" by
#               Makefile yet)
##############################################################

# creates virtual env if necessary and installs pip and setuptools
$(VENV): | $(REQUIREMENTS_PATH)  # creates $(VENV) folder if does not exist
	@echo "Creating virtualenv in $(VENV_ROOT)" && python3 -mvenv $(VENV)

# installs pip and setuptools in their latest version, creates virtualenv if necessary
$(VENV)/bin/python $(VENV)/bin/pip: # installs latest pip
	@test -e $(VENV)/bin/python || $(MAKE) $(VENV)
	@test -e $(VENV)/bin/pip || $(MAKE) $(VENV)
	@echo "Installing latest version of pip and setuptools"
	@$(VENV)/bin/pip install -U pip setuptools

 # installs latest version of the "black" code formatting tool
$(VENV)/bin/black: | $(VENV)/bin/pip
	$(VENV)/bin/pip install -U black

# installs this package in "edit" mode after ensuring its requirements are installed

# ensure that REQUIREMENTS_PATH exists
$(REQUIREMENTS_PATH):
	@echo "The requirements file $(REQUIREMENTS_PATH) does not exist"
	@echo ""
	@echo "To fix this issue:"
	@echo "  edit the variable REQUIREMENTS_NAME inside of the file:"
	@echo "  $(MAKEFILE_PATH)."
	@echo ""
	@exit 1

###############################################################
# Declare all target names that exist for convenience and don't
# represent real paths, which is what Make expects by default:
###############################################################

.PHONY: \
	all \
	black \
	clean \
	dependencies \
	develop \
	setup \
	run \
	tests \
	unit \
	functional


.DEFAULT_GOAL	:= help
