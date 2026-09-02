# This port tracks the master branch, which is where Diligent lands finished work
# between its infrequent releases -- v2.5.6 is from September 2024, while master
# carries API version 256020 against that tag's 255001. There is no upstream
# version number for it, so it is dated after the pinned commit, matching vcpkg's
# convention for an untagged snapshot. The v2.5.6 release remains registered in
# the version database and can still be selected with an exact `overrides` pin.
#
# DiligentEngine is a superproject whose modules are git submodules that in turn
# vendor their third-party libraries the same way. Only release archives bundle
# all of those, so a master snapshot has to pin each submodule itself. They are
# fetched with vcpkg_from_git rather than vcpkg_from_github because the commit
# hash is already the integrity check, which avoids carrying 18 tarball SHA512s.
# DiligentSamples and its two submodules are deliberately absent: the samples are
# not built, and the root CMakeLists only descends into them on request.
#
# Upstream exports no CMake package config and installs its libraries into
# lib/<Module>/<CONFIG>/, so this port flattens the layout into the vcpkg one and
# supplies its own `unofficial-diligent-engine` config.

# Diligent builds a static and a shared flavour of each graphics backend and
# offers no switch to pick one, so the triplet decides which gets installed.
# DiligentCore, DiligentTools and DiligentFX are only ever static archives
# upstream, so they are installed either way -- a dynamic triplet gets those
# plus the backend shared libraries, which is the same shape a system-wide
# install of Diligent produces.
set(DILIGENT_SHARED_MODULE_NAMES
    GraphicsEngineOpenGL
    GraphicsEngineVk
    GraphicsEngineD3D11
    GraphicsEngineD3D12
    Archiver
)

vcpkg_from_git(
    OUT_SOURCE_PATH SOURCE_PATH
    URL https://github.com/DiligentGraphics/DiligentEngine.git
    REF 7e2507fe4ae0157cf563a8aa4d88ff8cf5eb7f00
)

# "<destination under SOURCE_PATH>|<DiligentGraphics repo>|<commit>", in order:
# a module has to land before the third-party submodules nested inside it,
# otherwise copying the module over the tree would wipe them out again.
set(DILIGENT_SUBMODULES
    "DiligentCore|DiligentCore|fa060f50549238578e1701b5d362d7cff2bf48c7"
    "DiligentTools|DiligentTools|260a1e47a743b0f07c9f50da3a7e31e11f815953"
    "DiligentFX|DiligentFX|eb616a8e30efa5193baba71ff1edae85bc6230a1"
    "DiligentCore/ThirdParty/SPIRV-Cross|SPIRV-Cross|1a6169566c73d3da552748fc372fe2bbb856e46e"
    "DiligentCore/ThirdParty/SPIRV-Headers|SPIRV-Headers|ad9184e76a66b1001c29db9b0a3e87f646c64de0"
    "DiligentCore/ThirdParty/SPIRV-Tools|SPIRV-Tools|0539c81f69a3daeb706fd3477dca61435b475156"
    "DiligentCore/ThirdParty/Vulkan-Headers|Vulkan-Headers|8864cdc896bbc2a9b6eb36b3218fc9ef57908d77"
    "DiligentCore/ThirdParty/glslang|glslang|275822a6261ee689aadb1da5f09a0ec2f058685c"
    "DiligentCore/ThirdParty/googletest|googletest|85087857ad10bd407cd6ed2f52f7ea9752db621f"
    "DiligentCore/ThirdParty/volk|volk|3ca312a4f38baa63d8006b6905abbeeb89c8087d"
    "DiligentCore/ThirdParty/xxHash|xxHash|66979328cf3f15cecdc61ea58c9f81e6071f8983"
    "DiligentTools/ThirdParty/args|args|6c223d46dbb1db72320a93404552117b12d0e7ab"
    "DiligentTools/ThirdParty/imgui|imgui|2744a710ba671a91b0d80a0e075cd9fcb8b1322d"
    "DiligentTools/ThirdParty/json|json|55f93686c01528224f448c19128836e7df245f72"
    "DiligentTools/ThirdParty/libpng|libpng|65bc84e803c0ccbf7aa1023e91b5808586ea1b66"
    "DiligentTools/ThirdParty/stb|stb|46fcb30365c5f35425751d275eecd8e5f8efc786"
    "DiligentTools/ThirdParty/zlib|zlib|0d8cda5065ba1bcea871f0b5ac1410186ea9405e"
)

foreach(submodule IN LISTS DILIGENT_SUBMODULES)
    string(REPLACE "|" ";" submodule "${submodule}")
    list(GET submodule 0 submodule_dest)
    list(GET submodule 1 submodule_repo)
    list(GET submodule 2 submodule_ref)

    vcpkg_from_git(
        OUT_SOURCE_PATH submodule_source
        URL "https://github.com/DiligentGraphics/${submodule_repo}.git"
        REF "${submodule_ref}"
    )
    file(REMOVE_RECURSE "${SOURCE_PATH}/${submodule_dest}")
    file(COPY "${submodule_source}/" DESTINATION "${SOURCE_PATH}/${submodule_dest}")
endforeach()

# On master DiligentFX pulls entt in with FetchContent, which cannot work under
# vcpkg: vcpkg_cmake_configure sets FETCHCONTENT_FULLY_DISCONNECTED=ON, so the
# fetch is skipped and configuration then fails on the empty source directory.
# Providing the tree ourselves and pointing FetchContent at it keeps the build
# hermetic. entt is only used by Hydrogent, whose headers are not installed, so
# it stays a build-time dependency and never reaches consumers.
vcpkg_from_git(
    OUT_SOURCE_PATH ENTT_SOURCE_PATH
    URL https://github.com/skypjack/entt.git
    REF b4e58bdd364ad72246c123a0c28538eab3252672  # v3.16.0, the tag DiligentFX declares
)

# The RenderStateNotation generator pretty-prints the parser headers it emits
# using a clang-format binary vendored in the tree, which is fragile to depend on
# (release archives even drop its execute bit) and is a decade-old x86-64 build.
# Pointing CLANG_FORMAT_EXECUTABLE somewhere that does not exist takes the
# documented "clang-format executable is not found" branch, skipping the
# formatting only -- the generated headers themselves are unaffected. Overriding
# the variable from the command line is not an option: it is set unconditionally
# as CACHE INTERNAL. The other consumer, add_format_validation_target, is already
# off via DILIGENT_NO_FORMAT_VALIDATION below.
vcpkg_replace_string("${SOURCE_PATH}/DiligentCore/BuildTools/CMakeLists.txt"
    "/FormatValidation/clang-format"
    "/FormatValidation/vcpkg-formatting-disabled-clang-format"
)

# Diligent gives every target an explicit STATIC/SHARED and does not support
# BUILD_SHARED_LIBS. With it on -- which vcpkg_cmake_configure does for a dynamic
# triplet -- its internal helper libraries (Diligent-Primitives, Diligent-Common,
# Diligent-ApplePlatform, glslang, ...) become shared objects whose symbols are
# then hidden by -fvisibility=hidden, and every backend fails to link with
# undefined references. It has to be forced here rather than through OPTIONS
# because vcpkg_cmake_configure appends its own -DBUILD_SHARED_LIBS last.
# This does not cost us the shared backends: those are declared SHARED outright.
#
# The find_package(absl) is for master's new DiligentFX/Radient component, which
# links absl::flat_hash_map without ever providing Abseil itself -- it assumes an
# enclosing build already brought it in. Resolving it from vcpkg lets Radient
# build rather than switching it off with DILIGENT_NO_RADIENT.
vcpkg_replace_string("${SOURCE_PATH}/CMakeLists.txt"
    "project(DiligentEngine)"
    "project(DiligentEngine)\n\nset(BUILD_SHARED_LIBS OFF CACHE BOOL \"\" FORCE)\nfind_package(absl CONFIG REQUIRED)"
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
        "-DFETCHCONTENT_SOURCE_DIR_ENTT=${ENTT_SOURCE_PATH}"
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

foreach(dir lib debug/lib bin debug/bin)
    diligent_flatten_libdir("${CURRENT_PACKAGES_DIR}/${dir}")
endforeach()

# Reduces an installed file name to the Diligent module it belongs to, undoing
# the lib prefix and the _32r/_64d suffix set_dll_output_name adds on Windows:
# libGraphicsEngineVk.dylib and GraphicsEngineVk_64r.dll both -> GraphicsEngineVk.
function(diligent_module_name path out_var)
    get_filename_component(name "${path}" NAME)
    string(REGEX REPLACE "^lib" "" name "${name}")
    string(REGEX REPLACE "\\.(a|so|dylib|dll|lib)(\\.[0-9.]+)?$" "" name "${name}")
    string(REGEX REPLACE "_(32|64)[rd]$" "" name "${name}")
    set(${out_var} "${name}" PARENT_SCOPE)
endfunction()

# Upstream's install_combined_static_lib merges only Diligent's OWN modules —
# the vendored third-party archives (glslang + SPIRV* + spirv-cross + volk +
# glew + xxHash under Core, the image codecs under Tools) install as separate
# libraries and the combined archives reference their symbols. A static
# package must therefore merge them in before the loose copies are pruned
# (pruning alone shipped a libDiligentCore.a with dangling glslang/spirv-cross
# references — the port-version 1 fix). The prune itself stays mandatory:
# Diligent's libpng16.a collides with vcpkg's own libpng port, which `skia`
# depends on, so the two ports could not coexist in one install tree.

# Third-party archives to fold into each combined library, by module name
# (diligent_module_name form). Missing members are skipped silently — the
# feature set decides what upstream actually built.
set(DILIGENT_CORE_MERGE_MODULES
    glslang MachineIndependent GenericCodeGen OSDependent
    glslang-default-resource-limits SPIRV SPIRV-Tools SPIRV-Tools-opt
    SPIRV-Tools-diff spirv-cross-core spirv-cross-glsl volk glew-static
    xxhash)
# Merged so DiligentTools' TextureLoader links; consumers pairing Tools with
# their own libpng/zlib/libjpeg should mind the duplicated symbol families.
set(DILIGENT_TOOLS_MERGE_MODULES png16 png16d ZLib zlibstatic LibJpeg LibTiff)

function(diligent_merge_thirdparty libdir)
    if(NOT IS_DIRECTORY "${libdir}")
        return()
    endif()
    foreach(combined IN ITEMS DiligentCore DiligentTools)
        set(target "${libdir}/${CMAKE_STATIC_LIBRARY_PREFIX}${combined}${CMAKE_STATIC_LIBRARY_SUFFIX}")
        if(NOT EXISTS "${target}")
            continue()
        endif()
        set(members "")
        file(GLOB candidates "${libdir}/*${CMAKE_STATIC_LIBRARY_SUFFIX}")
        foreach(candidate IN LISTS candidates)
            diligent_module_name("${candidate}" module)
            if(combined STREQUAL "DiligentCore" AND module IN_LIST DILIGENT_CORE_MERGE_MODULES)
                list(APPEND members "${candidate}")
            elseif(combined STREQUAL "DiligentTools" AND module IN_LIST DILIGENT_TOOLS_MERGE_MODULES)
                list(APPEND members "${candidate}")
            endif()
        endforeach()
        if(NOT members)
            continue()
        endif()
        if(VCPKG_TARGET_IS_OSX)
            find_program(DILIGENT_LIBTOOL libtool REQUIRED)
            file(RENAME "${target}" "${target}.self")
            vcpkg_execute_required_process(
                COMMAND "${DILIGENT_LIBTOOL}" -static -o "${target}"
                        "${target}.self" ${members}
                WORKING_DIRECTORY "${libdir}"
                LOGNAME "merge-${combined}-${TARGET_TRIPLET}")
            file(REMOVE "${target}.self")
        elseif(VCPKG_TARGET_IS_WINDOWS)
            # lib.exe (or llvm-lib) concatenates archives directly.
            find_program(DILIGENT_LIB NAMES lib llvm-lib REQUIRED)
            file(RENAME "${target}" "${target}.self")
            vcpkg_execute_required_process(
                COMMAND "${DILIGENT_LIB}" "/OUT:${target}"
                        "${target}.self" ${members}
                WORKING_DIRECTORY "${libdir}"
                LOGNAME "merge-${combined}-${TARGET_TRIPLET}")
            file(REMOVE "${target}.self")
        else()
            # binutils/llvm ar both speak MRI scripts.
            set(mri "CREATE ${target}.merged\nADDLIB ${target}\n")
            foreach(member IN LISTS members)
                string(APPEND mri "ADDLIB ${member}\n")
            endforeach()
            string(APPEND mri "SAVE\nEND\n")
            file(WRITE "${libdir}/merge-${combined}.mri" "${mri}")
            find_program(DILIGENT_AR NAMES ar llvm-ar REQUIRED)
            execute_process(
                COMMAND "${DILIGENT_AR}" -M
                INPUT_FILE "${libdir}/merge-${combined}.mri"
                RESULT_VARIABLE mri_result)
            if(NOT mri_result EQUAL 0)
                message(FATAL_ERROR "ar -M merge failed for ${combined}")
            endif()
            file(REMOVE "${libdir}/merge-${combined}.mri")
            file(RENAME "${target}.merged" "${target}")
        endif()
    endforeach()
endfunction()

foreach(dir lib debug/lib)
    diligent_merge_thirdparty("${CURRENT_PACKAGES_DIR}/${dir}")
endforeach()
function(diligent_prune_dir dir keep_shared)
    if(NOT IS_DIRECTORY "${dir}")
        return()
    endif()
    file(GLOB entries "${dir}/*")
    foreach(entry IN LISTS entries)
        diligent_module_name("${entry}" module)
        set(keep FALSE)
        if(module MATCHES "^Diligent(Core|Tools|FX)$")
            set(keep TRUE)
        elseif(keep_shared AND module IN_LIST DILIGENT_SHARED_MODULE_NAMES)
            # Keeps the shared library and, on Windows, its import library too.
            set(keep TRUE)
        endif()
        if(NOT keep)
            file(REMOVE_RECURSE "${entry}")
        endif()
    endforeach()
endfunction()

set(keep_shared FALSE)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(keep_shared TRUE)
endif()

foreach(dir lib debug/lib bin debug/bin)
    diligent_prune_dir("${CURRENT_PACKAGES_DIR}/${dir}" ${keep_shared})
endforeach()

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

# The Vulkan backend reaches every entry point through volk, which is compiled
# into the combined DiligentCore archive. That copy is the engine's own: the
# volk port builds its static library with no platform definitions, so linking
# it here would leave the surface entry point the engine calls
# (vkCreateMetalSurfaceEXT on Apple, its Win32/XCB/Xlib/Wayland counterparts
# elsewhere) undefined. The port depends on volk for its headers instead, and
# for volk.c, which the volk port installs beside them: a process that has to
# point the engine at a loader the stock volkInitialize cannot reach replaces
# that function by compiling volk itself, and the definitions below are what it
# must compile with. Compiled with less, its volk is missing the surface entry
# point, the engine's own copy is pulled in beside it, and every loader symbol
# is then defined twice.
#
# Mirror of DiligentCore/BuildTools/CMake/VulkanUtils.cmake's
# get_vulkan_platform_definitions(), which is what the engine built its volk
# with. They travel on a target of their own rather than on DiligentCore:
# VK_USE_PLATFORM_WIN32_KHR needs windows.h ahead of vulkan.h and the Linux
# ones need the X11 and Wayland headers, which no consumer should inherit for
# naming a render device.
set(DILIGENT_USES_VOLK 0)
set(DILIGENT_VULKAN_PLATFORM_DEFINITIONS "")
if("vulkan" IN_LIST FEATURES)
    set(DILIGENT_USES_VOLK 1)
    if(VCPKG_TARGET_IS_WINDOWS)
        set(DILIGENT_VULKAN_PLATFORM_DEFINITIONS VK_USE_PLATFORM_WIN32_KHR=1)
    elseif(VCPKG_TARGET_IS_OSX)
        set(DILIGENT_VULKAN_PLATFORM_DEFINITIONS VK_USE_PLATFORM_METAL_EXT=1)
    elseif(VCPKG_TARGET_IS_LINUX)
        set(DILIGENT_VULKAN_PLATFORM_DEFINITIONS
            VK_USE_PLATFORM_XCB_KHR=1
            VK_USE_PLATFORM_XLIB_KHR=1
            VK_USE_PLATFORM_WAYLAND_KHR=1
        )
    endif()
endif()

# Locate an installed artifact belonging to `module`, as a prefix-relative path.
function(diligent_find_module_file dir module pattern out_var)
    set(result "")
    file(GLOB candidates "${CURRENT_PACKAGES_DIR}/${dir}/*")
    foreach(candidate IN LISTS candidates)
        diligent_module_name("${candidate}" candidate_module)
        if(candidate_module STREQUAL module AND candidate MATCHES "${pattern}")
            file(RELATIVE_PATH result "${CURRENT_PACKAGES_DIR}" "${candidate}")
            break()
        endif()
    endforeach()
    set(${out_var} "${result}" PARENT_SCOPE)
endfunction()

# Emit one _diligent_add_shared_module() call per backend that was actually
# installed, with the paths resolved here rather than guessed at find_package
# time -- only the port knows how this triplet named the artifacts.
set(DILIGENT_SHARED_MODULE_CALLS "")
if(keep_shared)
    set(shared_pattern "\\.(dylib|so|dll)($|\\.)")
    foreach(module IN LISTS DILIGENT_SHARED_MODULE_NAMES)
        # On Windows the runtime lives in bin/ and the import library in lib/;
        # elsewhere the shared library itself sits in lib/ and there is no implib.
        diligent_find_module_file(bin "${module}" "${shared_pattern}" rel_loc)
        if(NOT rel_loc)
            diligent_find_module_file(lib "${module}" "${shared_pattern}" rel_loc)
        endif()
        if(NOT rel_loc)
            continue()
        endif()
        diligent_find_module_file(debug/bin "${module}" "${shared_pattern}" dbg_loc)
        if(NOT dbg_loc)
            diligent_find_module_file(debug/lib "${module}" "${shared_pattern}" dbg_loc)
        endif()
        diligent_find_module_file(lib "${module}" "\\.lib$" rel_implib)
        diligent_find_module_file(debug/lib "${module}" "\\.lib$" dbg_implib)

        string(APPEND DILIGENT_SHARED_MODULE_CALLS
            "_diligent_add_shared_module(${module}"
            " \"${rel_loc}\" \"${dbg_loc}\""
            " \"${rel_implib}\" \"${dbg_implib}\")\n")
    endforeach()
endif()

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
