# Port-supplied build for sansumbrella/Choreograph (upstream has no build
# system). Static library + installed headers + CMake package config.
cmake_minimum_required(VERSION 3.16)
project(choreograph CXX)

add_library(choreograph
  src/choreograph/Cue.cpp
  src/choreograph/Timeline.cpp
  src/choreograph/TimelineItem.cpp
)

target_compile_features(choreograph PUBLIC cxx_std_14)

target_include_directories(choreograph PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
  $<INSTALL_INTERFACE:include>
)

include(GNUInstallDirs)

install(TARGETS choreograph EXPORT choreograph-targets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(DIRECTORY src/choreograph
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
)

install(EXPORT choreograph-targets
  NAMESPACE choreograph::
  FILE choreograph-config.cmake
  DESTINATION share/choreograph
)
