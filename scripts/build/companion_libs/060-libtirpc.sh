# This file adds the functions to build the libtirpc library
# Copyright 2017 Alexey Neyman
# Licensed under the GPL v2. See COPYING in the root of this package

do_libtirpc_get() { :; }
do_libtirpc_extract() { :; }
do_libtirpc_for_build() { :; }
do_libtirpc_for_host() { :; }
do_libtirpc_for_target() { :; }

# Overide functions depending on configuration
if [ "${CT_LIBTIRPC}" = "y" ]; then

# Download libtirpc
do_libtirpc_get() {
    CT_Fetch LIBTIRPC
}

# Extract libtirpc
do_libtirpc_extract() {
    CT_ExtractPatch LIBTIRPC
}

# Build libtirpc for running on build
# - always build statically
# - install in build-tools prefix
do_libtirpc_for_build() {
    local -a libtirpc_opts

    case "${CT_TOOLCHAIN_TYPE}" in
        native|cross)   return 0;;
    esac

    CT_DoStep INFO "Installing libtirpc for build"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libtirpc-build-${CT_BUILD}"

    libtirpc_opts+=( "host=${CT_BUILD}" )
    libtirpc_opts+=( "prefix=${CT_BUILDTOOLS_PREFIX_DIR}" )
    libtirpc_opts+=( "cflags=${CT_CFLAGS_FOR_BUILD}" )
    libtirpc_opts+=( "ldflags=${CT_LDFLAGS_FOR_BUILD}" )
    do_libtirpc_backend "${libtirpc_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build libtirpc for running on host
do_libtirpc_for_host() {
    local -a libtirpc_opts

    CT_DoStep INFO "Installing libtirpc for host"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libtirpc-host-${CT_HOST}"

    libtirpc_opts+=( "target=${CT_TARGET}" )
    libtirpc_opts+=( "prefix=${CT_HOST_COMPLIBS_DIR}" )
    libtirpc_opts+=( "cflags=${CT_CFLAGS_FOR_HOST}" )
    libtirpc_opts+=( "ldflags=${CT_LDFLAGS_FOR_HOST}" )
    do_libtirpc_backend "${libtirpc_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build libtirpc for running on target
do_libtirpc_for_target() {
    local -a libtirpc_opts

    CT_DoStep INFO "Installing libtirpc for target"
    CT_mkdir_pushd "${CT_BUILD_DIR}/build-libtirpc-target-${CT_TARGET}"

    libtirpc_opts+=( "host=${CT_TARGET}" )
    libtirpc_opts+=( "prefix=${CT_PREFIX_DIR}" )
    libtirpc_opts+=( "cflags=${CT_CFLAGS_FOR_TARGET}" )
    libtirpc_opts+=( "ldflags=${CT_LDFLAGS_FOR_TARGET}" )
    extra_config+=( "--host=${host}" )
    extra_config+=( "CC=${host}-gcc" )
    do_libtirpc_backend "${libtirpc_opts[@]}"

    CT_Popd
    CT_EndStep
}

# Build libtirpc
#     Parameter     : description               : type      : default
#     host          : machine to run on         : tuple     : (none)
#     prefix        : prefix to install into    : dir       : (none)
#     cflags        : cflags to use             : string    : (empty)
#     ldflags       : ldflags to use            : string    : (empty)
do_libtirpc_backend() {
    local host
    local prefix
    local cflags
    local ldflags
    local arg
    local -a extra_config
    local -a extra_make

    for arg in "$@"; do
        eval "${arg// /\\ }"
    done

    case "${host}" in
    *-mingw32)
        # libtirpc treats mingw host differently and requires using a different
        # makefile rather than configure+make. It also does not support
        # out-of-tree building.
        cp -av "${CT_SRC_DIR}/libtirpc/." .
        extra_make=( -f win32/Makefile.gcc \
            PREFIX="${host}-" \
            SHAREDLIB= \
            IMPLIB= \
            LIBRARY_PATH="${prefix}/lib" \
            INCLUDE_PATH="${prefix}/include" \
            BINARY_PATH="${prefix}/bin" \
            prefix="${prefix}" \
            )
        ;;

    *)
        CT_DoLog EXTRA "Configuring libtirpc"

        CT_DoExecLog CFG                                  \
        CFLAGS="${cflags}"                                \
        LDFLAGS="${ldflags}"                              \
        CHOST="${host}"                                   \
        ${CONFIG_SHELL}                                   \
        "${CT_SRC_DIR}/libtirpc/configure"                \
            --prefix="${prefix}"                          \
            --disable-gssapi                              \
            "${extra_config[@]}"
        ;;
    esac

    CT_DoLog EXTRA "Building libtirpc"
    CT_DoExecLog ALL make "${extra_make[@]}" ${CT_JOBSFLAGS}

    if [ "${CT_COMPLIBS_CHECK}" = "y" ]; then
        if [ "${host}" = "${CT_BUILD}" ]; then
            CT_DoLog EXTRA "Checking libtirpc"
            CT_DoExecLog ALL make "${extra_make[@]}" -s test
        else
            # Cannot run host binaries on build in a canadian cross
            CT_DoLog EXTRA "Skipping check for libtirpc on the host"
        fi
    fi

    CT_DoLog EXTRA "Installing libtirpc"
    CT_DoExecLog ALL make "${extra_make[@]}" install
}

fi # CT_LIBTIRPC
