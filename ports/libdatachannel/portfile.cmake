# vcpkg's builtin `libdatachannel` port, carrying one patch it does not have.
# The library ends the whole process from threads it owns: the ICE state change
# that starts the DTLS transport throws when the handshake's first write fails,
# and the SCTP write callback throws when the protocol underneath is already
# shut down. Either throw travels up the C frames the library is called back
# through -- libjuice's poll sweep under the first, usrsctp's under the second
# -- where no frame of a consumer's stands, so nothing a consumer guards can
# catch it and the process aborts.
#
# A failed handshake start, or a write on a transport being torn down, is one
# connection's failure reported through its state and never the process's end.
# The patch gives the first the Failed state that ICE callback already gives a
# route nobody found, and refuses the second with -1 the way its neighbours do.
# Two ICE agents completing on one poll sweep provoke the first -- both ends of
# a conversation in one process is the arrangement that does it -- and teardown
# provokes the second.
#
# Both guards are catch-alls. The library's own guards on these two paths catch
# `const std::exception &`, which matches nothing in an image that carries a
# hidden `typeinfo for std::exception` of its own -- a static dependency
# compiled with hidden visibility emits one, and the handler search compares a
# type_info by address.

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO paullouisageneau/libdatachannel
    REF "v${VERSION}"
    SHA512 92a173e4d23c03a69d4b019ff92e0723538c6f2ee549a7bf602c65682954b7fc0f6c4b10a9be3ccf89e5b0bea115a5136d5f5afb04964cf26b9071e2d752ce1b
    HEAD_REF master
    PATCHES
        dependencies.diff
        uwp-warnings.patch
        guarded-threads.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        stdcall CAPI_STDCALL
    INVERTED_FEATURES
        ws      NO_WEBSOCKET
        srtp    NO_MEDIA
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DPREFER_SYSTEM_LIB=ON
        -DNO_EXAMPLES=ON
        -DNO_TESTS=ON
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/LibDataChannel)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/rtc/common.hpp" "#ifdef RTC_STATIC" "#if 1")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/rtc/rtc.h" "#ifdef RTC_STATIC" "#if 1")
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
