# vcpkg's builtin `yoga` port at the same upstream version, carrying one patch
# it does not have.
#
# Yoga's own `cmake/project-defaults.cmake` compiles the library with exceptions
# enabled and run-time type information disabled. An object compiled without
# run-time type information that throws or catches a standard exception emits a
# private, non-unique copy of that type's typeinfo, and the linker satisfies
# every other object's reference to the name with that copy. The handler search
# compares a typeinfo by address, so a consumer's
# `catch (const std::exception &)` then matches nothing the standard library
# throws -- in the whole image, not only in Yoga's own frames -- and the process
# terminates on an exception that had a handler written for it. The patch leaves
# run-time type information on and changes nothing else; exceptions stay as they
# are.
#
# Because the port name matches a builtin one, a consumer only gets this version
# if `"yoga"` is listed in this registry's `packages` array.

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO facebook/yoga
    REF "v${VERSION}"
    SHA512 41ca044dcc7e404d5d3b052a85a650713bd31950a010a14658e25b1d065fffa16239cb93d2b00845d4e8443169ae50a91ad36080305f1be93e53ed481603a78b
    HEAD_REF master
    PATCHES
        disable_tests.patch
        run-time-type-information.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT})

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
