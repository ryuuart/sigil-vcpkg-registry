# Example portfile — replace the body with how YOUR package is built.
#
# The most common pattern is to fetch a tagged release from GitHub and build
# it with CMake. To fill in SHA512: run the port once with a bogus hash
# ("0") and vcpkg will print the actual SHA512 it downloaded.
#
# vcpkg_from_github(
#     OUT_SOURCE_PATH SOURCE_PATH
#     REPO your-org/example-lib
#     REF "v${VERSION}"
#     SHA512 0  # replace with the real hash printed on first build
#     HEAD_REF main
# )
#
# vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
# vcpkg_cmake_install()
# vcpkg_cmake_config_fixup(PACKAGE_NAME example-lib)
#
# vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
#
# ---------------------------------------------------------------------------
# The stub below lets `vcpkg install example-lib` succeed with no download,
# so you can verify the registry wiring end-to-end before wiring a real source.

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright"
     "Example placeholder port. Replace with a real license file.\n")
