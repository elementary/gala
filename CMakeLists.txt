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
set (VERSION "0.1.0")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "-ggdb")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")

set(CPACK_SOURCE_GENERATOR "TBZ2")
set(CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${VERSION}")
set(CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;~$;.bzrignore;${CPACK_SOURCE_IGNORE_FILES}")
include(CPack)
add_custom_target(dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

configure_file (${CMAKE_SOURCE_DIR}/src/Config.vala.cmake ${CMAKE_BINARY_DIR}/src/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED libmutter>=3.4 granite clutter-1.0>=1.9.16 clutter-gtk-1.0 libbamf3 xfixes gee-1.0 plank)

set (MUTTER36_FLAGS "")
pkg_check_modules(MUTTER36 QUIET libmutter>=3.5.3)
if (MUTTER36_FOUND)
	set (MUTTER36_FLAGS "--define=HAS_MUTTER36")
endif (MUTTER36_FOUND)

set (MUTTER38_FLAGS "")
pkg_check_modules(MUTTER38 QUIET libmutter>=3.7.91)
if (MUTTER38_FOUND)
	set (MUTTER38_FLAGS "--define=HAS_MUTTER38")
endif (MUTTER38_FOUND)

set (MUTTER310_FLAGS "")
pkg_check_modules(MUTTER310 QUIET libmutter>=3.9.1)
if (MUTTER310_FOUND)
	set (MUTTER310_FLAGS "--define=HAS_MUTTER310")
endif (MUTTER310_FOUND)

add_definitions(${DEPS_CFLAGS})

link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.1" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C
    src/DBus.vala
    src/Main.vala
    src/Plugin.vala
    src/Settings.vala
    src/TextShadowEffect.vala
    src/Utils.vala
    src/Zooming.vala
    src/Widgets/AppIcon.vala
    src/Widgets/WindowOverview.vala
    src/Widgets/WindowSwitcher.vala
    src/Widgets/WindowThumb.vala
    src/Widgets/WorkspaceThumb.vala
    src/Widgets/WorkspaceView.vala
    ${CMAKE_BINARY_DIR}/src/Config.vala
PACKAGES
    granite
    libbamf3
    libmutter
    plank
    clutter-gtk-1.0
    gdk-x11-3.0
    gdesktopenums-3.0
    xfixes-4.0
OPTIONS
    -g
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi/
    ${MUTTER36_FLAGS}
    ${MUTTER38_FLAGS}
    ${MUTTER310_FLAGS}
    )

#add_subdirectory (po)

include(GSettings)
add_schema ("data/org.pantheon.desktop.gala.gschema.xml")

add_executable(gala ${VALA_C})#src/main.c)
target_link_libraries(gala m)

install(TARGETS gala RUNTIME DESTINATION bin)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/gala.desktop DESTINATION share/applications)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/gala.css DESTINATION ${PKGDATADIR})
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/texture.png DESTINATION ${PKGDATADIR})
