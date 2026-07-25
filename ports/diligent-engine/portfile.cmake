# DiligentEngine is a superproject whose modules live in git submodules, which in
# turn have their own submodules for the vendored third-party libraries. The
# GitHub release archive is the only source drop that ships all of them, so the
# port fetches that rather than using vcpkg_from_github.
#
# Upstream exports no CMake package config and installs its libraries into
# lib/<Module>/<CONFIG>/, so this port flattens the layout into the vcpkg one and
# supplies its own `unofficial-diligent-engine` config.

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/DiligentGraphics/DiligentEngine/releases/download/v${VERSION}/DiligentEngine_v${VERSION}.zip"
    FILENAME "DiligentEngine_v${VERSION}.zip"
    SHA512 435b67a62fd67b5a4fdfd4af084a5a14b092aaa93a473533ee85c0a0d7112a1d5284f753daf174f75e1d3059b1ec1b5a3cea85b1b3dd20555faf26b1912ad31e
)

vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# The release zip stores the bundled clang-format binaries without the execute
# bit, so the RenderStateNotation generator dies with "Permission denied" when it
# tries to pretty-print the parser headers it just generated. Pointing
# CLANG_FORMAT_EXECUTABLE at a path that does not exist takes the documented
# "clang-format executable is not found" branch, which skips formatting only --
# the generated headers themselves are unaffected. Overriding the variable from
# the command line is not an option: it is set unconditionally as CACHE INTERNAL.
# The other consumer, add_format_validation_target, is already off via
# DILIGENT_NO_FORMAT_VALIDATION below.
vcpkg_replace_string("${SOURCE_PATH}/DiligentCore/BuildTools/CMakeLists.txt"
    "/FormatValidation/clang-format"
    "/FormatValidation/vcpkg-formatting-disabled-clang-format"
)

# Diligent expresses backends as opt-outs, so the feature flags are inverted.
vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        fx      DILIGENT_BUILD_FX
        tools   DILIGENT_BUILD_TOOLS
    INVERTED_FEATURES
        d3d11       DILIGENT_NO_DIRECT3D11
        d3d12       DILIGENT_NO_DIRECT3D12
        opengl      DILIGENT_NO_OPENGL
        vulkan      DILIGENT_NO_VULKAN
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DDILIGENT_BUILD_SAMPLES=OFF
        -DDILIGENT_BUILD_TESTS=OFF
        -DDILIGENT_BUILD_DOCS=OFF
        -DDILIGENT_INSTALL_CORE=ON
        -DDILIGENT_INSTALL_TOOLS=ON
        -DDILIGENT_INSTALL_FX=ON
        -DDILIGENT_INSTALL_SAMPLES=OFF
        -DDILIGENT_INSTALL_PDB=OFF
        -DDILIGENT_NO_FORMAT_VALIDATION=ON
        # Not optional: GraphicsAccessories.hpp, a public header, includes
        # Archiver/interface/Archiver.h unconditionally, so an install without
        # the archiver ships a header set that cannot compile.
        -DDILIGENT_NO_ARCHIVER=OFF
        # The Metal backend ships only in the closed-source DiligentCorePro module.
        -DDILIGENT_NO_METAL=ON
        -DDILIGENT_NO_WEBGPU=ON
        # DiligentTools vendors libpng, whose options.awk is rejected by the BWK
        # awk that ships with macOS ("bad line (10): com"). Leaving AWK empty
        # takes libpng's documented no-awk path, which uses the checked-in
        # scripts/pnglibconf.h.prebuilt. Diligent customises no libpng options,
        # so that prebuilt config is what the generator would have produced.
        -DAWK=
    MAYBE_UNUSED_VARIABLES
        AWK
        DILIGENT_BUILD_DOCS
        DILIGENT_INSTALL_PDB
        DILIGENT_INSTALL_SAMPLES
        DILIGENT_NO_DIRECT3D11
        DILIGENT_NO_DIRECT3D12
        DILIGENT_NO_METAL
        DILIGENT_NO_WEBGPU
)

vcpkg_cmake_install()

# Upstream installs to lib/<Module>/<CONFIG>/. Flatten that into lib/ (and
# debug/lib/), which is what vcpkg and the accompanying config file expect.
function(diligent_flatten_libdir libdir)
    if(NOT IS_DIRECTORY "${libdir}")
        return()
    endif()
    file(GLOB module_dirs LIST_DIRECTORIES true "${libdir}/*")
    foreach(module_dir IN LISTS module_dirs)
        if(NOT IS_DIRECTORY "${module_dir}")
            continue()
        endif()
        file(GLOB_RECURSE libs "${module_dir}/*")
        foreach(lib IN LISTS libs)
            get_filename_component(lib_name "${lib}" NAME)
            file(RENAME "${lib}" "${libdir}/${lib_name}")
        endforeach()
        file(REMOVE_RECURSE "${module_dir}")
    endforeach()
endfunction()

diligent_flatten_libdir("${CURRENT_PACKAGES_DIR}/lib")
diligent_flatten_libdir("${CURRENT_PACKAGES_DIR}/debug/lib")

# Keep only the three combined Diligent archives. Everything else upstream drops
# in lib/ is a duplicate: the per-backend shared libraries restate what the
# static DiligentCore archive already holds, and the vendored third-party
# archives (libpng16, ZLib, LibJpeg, LibTiff, glslang, SPIRV*, glew) are already
# merged into the combined libraries by install_combined_static_lib. Shipping
# them separately is not just redundant, it breaks installation: Diligent's
# libpng16.a collides with vcpkg's own libpng port, which `skia` depends on, so
# the two ports could not coexist in one install tree.
function(diligent_keep_only_combined_libs libdir)
    if(NOT IS_DIRECTORY "${libdir}")
        return()
    endif()
    file(GLOB libs "${libdir}/*")
    foreach(lib IN LISTS libs)
        get_filename_component(lib_name "${lib}" NAME)
        # libDiligentCore.a / DiligentCore.lib / libDiligentFX.a ...
        if(NOT lib_name MATCHES "^(lib)?Diligent")
            file(REMOVE_RECURSE "${lib}")
        endif()
    endforeach()
endfunction()

diligent_keep_only_combined_libs("${CURRENT_PACKAGES_DIR}/lib")
diligent_keep_only_combined_libs("${CURRENT_PACKAGES_DIR}/debug/lib")

# Tools link the shared backends that were just removed.
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
)

file(GLOB_RECURSE installed_libs
    "${CURRENT_PACKAGES_DIR}/lib/*"
    "${CURRENT_PACKAGES_DIR}/debug/lib/*"
)
if(NOT installed_libs)
    message(FATAL_ERROR "DiligentEngine installed no libraries; the combined static library step failed.")
endif()

# DiligentFX installs its shader sources to a top-level Shaders/ directory, which
# is not a layout vcpkg understands. Move it under share/ and drop the debug copy.
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/${PORT}")
if(IS_DIRECTORY "${CURRENT_PACKAGES_DIR}/Shaders")
    file(RENAME "${CURRENT_PACKAGES_DIR}/Shaders" "${CURRENT_PACKAGES_DIR}/share/${PORT}/Shaders")
endif()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/Shaders")

# Some of the installed directories end up empty (their contents are compiled
# into the libraries instead), and vcpkg rejects empty directories. Repeat until
# stable so that a directory left empty by pruning its children goes too.
function(diligent_prune_empty_dirs root)
    set(pruned TRUE)
    while(pruned)
        set(pruned FALSE)
        file(GLOB_RECURSE dirs LIST_DIRECTORIES true "${root}/*")
        foreach(dir IN LISTS dirs)
            if(IS_DIRECTORY "${dir}")
                file(GLOB contents "${dir}/*")
                if(NOT contents)
                    file(REMOVE_RECURSE "${dir}")
                    set(pruned TRUE)
                endif()
            endif()
        endforeach()
    endwhile()
endfunction()

# Mirror of DiligentCore/CMakeLists.txt's Diligent-PublicBuildSettings target:
# the platform macro plus one flag per backend. Diligent derives the backend set
# from the platform and then subtracts DILIGENT_NO_*, which is what the feature
# checks below reproduce.
if(VCPKG_TARGET_IS_WINDOWS)
    set(DILIGENT_PUBLIC_DEFINITIONS PLATFORM_WIN32=1)
elseif(VCPKG_TARGET_IS_OSX)
    set(DILIGENT_PUBLIC_DEFINITIONS PLATFORM_MACOS=1 PLATFORM_APPLE=1)
elseif(VCPKG_TARGET_IS_LINUX)
    set(DILIGENT_PUBLIC_DEFINITIONS PLATFORM_LINUX=1)
else()
    message(FATAL_ERROR "No platform macro known for this target; see the `supports` expression in vcpkg.json.")
endif()

foreach(backend_def D3D11_SUPPORTED D3D12_SUPPORTED GL_SUPPORTED VULKAN_SUPPORTED)
    set(${backend_def} 0)
endforeach()
if("d3d11" IN_LIST FEATURES)
    set(D3D11_SUPPORTED 1)
endif()
if("d3d12" IN_LIST FEATURES)
    set(D3D12_SUPPORTED 1)
endif()
if("opengl" IN_LIST FEATURES)
    set(GL_SUPPORTED 1)
endif()
if("vulkan" IN_LIST FEATURES)
    set(VULKAN_SUPPORTED 1)
endif()

list(APPEND DILIGENT_PUBLIC_DEFINITIONS
    D3D11_SUPPORTED=${D3D11_SUPPORTED}
    D3D12_SUPPORTED=${D3D12_SUPPORTED}
    GL_SUPPORTED=${GL_SUPPORTED}
    VULKAN_SUPPORTED=${VULKAN_SUPPORTED}
    # GLES is Android/iOS/Emscripten only, Metal needs DiligentCorePro, and
    # WebGPU is switched off above -- none of them can be on for this port.
    GLES_SUPPORTED=0
    METAL_SUPPORTED=0
    WEBGPU_SUPPORTED=0
    ARCHIVER_SUPPORTED=1
)

configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/unofficial-diligent-engine-config.cmake.in"
    "${CURRENT_PACKAGES_DIR}/share/unofficial-diligent-engine/unofficial-diligent-engine-config.cmake"
    @ONLY
)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/Licenses"
    "${CURRENT_PACKAGES_DIR}/Licenses"
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/License.txt")

# Last, so that anything emptied by the cleanup above is caught too.
diligent_prune_empty_dirs("${CURRENT_PACKAGES_DIR}")
