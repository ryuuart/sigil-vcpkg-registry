# Syphon is an Xcode project that builds one macOS framework, with no CMake
# build and no package config. The releases predate the Metal server and
# client -- the only API this repository publishes frames through -- so the
# port tracks the main branch and is dated after the pinned commit, matching
# vcpkg's convention for an untagged snapshot.
#
# The framework is a dylib whatever the triplet says: a .framework is the only
# shape the project builds, and IOSurface sharing is a service one process
# publishes and others attach to, so there is nothing to link statically.

set(VCPKG_BUILD_TYPE release) # a released framework is what an app ships
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled) # headers live in the framework
# A framework is loaded by its bundle-relative install name
# (@rpath/Syphon.framework/Versions/A/Syphon). The Mach-O fixup rewrites an
# install name to @rpath/<file name>, which no bundle answers to, so the
# framework keeps the id the linker recorded.
set(VCPKG_FIXUP_MACHO_RPATH OFF)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Syphon/Syphon-Framework
    REF 71351d4b484cd2d1917867f7846a5cdca724552d
    SHA512 543f4caa1b34f5d1ef5d83e781b68a0eff1814b86be8e7e7351d2cae82fce49cf0d463addbc42715d5bb868df98802dbb2c0fc19ffa75e92aadb2330d640d096
    HEAD_REF main
)

# xcodebuild names architectures the way the compiler does, which is what
# every vcpkg triplet but x64 already spells.
set(SYPHON_ARCHS "${VCPKG_TARGET_ARCHITECTURE}")
if(SYPHON_ARCHS STREQUAL "x64")
    set(SYPHON_ARCHS x86_64)
endif()

set(SYPHON_BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
file(REMOVE_RECURSE "${SYPHON_BUILD_DIR}")
file(MAKE_DIRECTORY "${SYPHON_BUILD_DIR}")

set(SYPHON_SETTINGS
    "ARCHS=${SYPHON_ARCHS}"
    ONLY_ACTIVE_ARCH=NO
    # Nothing here is distributed as a signed product; an application signs
    # the copy it embeds.
    CODE_SIGNING_ALLOWED=NO
    "CONFIGURATION_BUILD_DIR=${SYPHON_BUILD_DIR}"
    "SYMROOT=${SYPHON_BUILD_DIR}/sym"
    "OBJROOT=${SYPHON_BUILD_DIR}/obj"
)
if(VCPKG_DETECTED_CMAKE_OSX_DEPLOYMENT_TARGET)
    list(APPEND SYPHON_SETTINGS
         "MACOSX_DEPLOYMENT_TARGET=${VCPKG_DETECTED_CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

vcpkg_execute_required_process(
    COMMAND xcodebuild
            -project "${SOURCE_PATH}/Syphon.xcodeproj"
            -target Syphon
            -configuration Release
            ${SYPHON_SETTINGS}
            build
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "build-${TARGET_TRIPLET}-rel"
)

# cp, because a framework is a directory of symbolic links around one copy of
# each file and copying it any other way multiplies it.
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib")
vcpkg_execute_required_process(
    COMMAND cp -R "${SYPHON_BUILD_DIR}/Syphon.framework" "${CURRENT_PACKAGES_DIR}/lib/"
    WORKING_DIRECTORY "${SYPHON_BUILD_DIR}"
    LOGNAME "install-${TARGET_TRIPLET}-rel"
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-syphon-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-syphon")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/License.txt")
