# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

project (gala)
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)

#
# Base bits
#

enable_testing ()

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/gala")
set (GETTEXT_PACKAGE "gala")
set (RELEASE_NAME "")
set (VERSION "0.1")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "-ggdb")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED libmutter granite clutter-1.0 clutter-gtk-1.0 libbamf3 xfixes)

add_definitions(${DEPS_CFLAGS})

link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.0" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C
    src/Main.vala
    src/Settings.vala
    src/TextShadowEffect.vala
    src/Widgets/WindowSwitcher.vala
    src/Widgets/WorkspaceView.vala
    ${CMAKE_BINARY_DIR}/src/Config.vala
PACKAGES
    granite
    libmutter
    clutter-gtk-1.0
    gdk-x11-3.0
    gdesktopenums-3.0
    xfixes-4.0
    bamf
OPTIONS
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi/
    )

#add_subdirectory (po)

include(GSettings)
add_schema ("data/org.pantheon.desktop.gala.gschema.xml")

add_executable(gala ${VALA_C})#src/main.c)

install(TARGETS gala RUNTIME DESTINATION bin)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/gala.desktop DESTINATION share/applications)
