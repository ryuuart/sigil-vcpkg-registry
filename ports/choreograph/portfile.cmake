# Upstream ships no build system (it predates its Cinder-block usage being
# split out), so the port supplies its own CMakeLists that builds the three
# TUs under src/choreograph and installs the headers with their include
# structure (<choreograph/Choreograph.h>) intact.

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO sansumbrella/Choreograph
    REF 34631980702f5d3745ac29d262712dd81b594ade
    SHA512 6648308a1b210c952e6d40db42fb63a81239f34f544a80c8fadcd1636ada69d96b484fefa66cdad75ee108815e410f121d6c3ef61451f782bc9f0a58ec645be5
)

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/choreograph")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.md")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
