# Syphon exports no package config of its own, so this file declares the
# installed framework as an imported target.

get_filename_component(_syphon_prefix "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(_syphon_framework "${_syphon_prefix}/lib/Syphon.framework")

if(NOT EXISTS "${_syphon_framework}")
    set(unofficial-syphon_FOUND FALSE)
    set(unofficial-syphon_NOT_FOUND_MESSAGE
        "Syphon.framework is not at ${_syphon_framework}")
    return()
endif()

if(NOT TARGET unofficial::syphon::syphon)
    add_library(unofficial::syphon::syphon SHARED IMPORTED)
    set_target_properties(unofficial::syphon::syphon PROPERTIES
        FRAMEWORK TRUE
        IMPORTED_LOCATION "${_syphon_framework}/Syphon"
        # An include directory naming the bundle itself is what puts its
        # parent on the framework search path, which is how
        # <Syphon/SyphonMetalServer.h> resolves.
        INTERFACE_INCLUDE_DIRECTORIES "${_syphon_framework}"
    )
endif()

set(unofficial-syphon_FOUND TRUE)
