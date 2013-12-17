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
set (PLUGINDIR "${PKGDATADIR}/plugins")
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

configure_file (${CMAKE_SOURCE_DIR}/lib/Config.vala.cmake ${CMAKE_BINARY_DIR}/lib/Config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\" -DGNOME_DESKTOP_USE_UNSTABLE_API -w)

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED libmutter>=3.4 granite clutter-1.0>=1.9.16 clutter-gtk-1.0 libbamf3 xfixes gee-1.0 plank gnome-desktop-3.0)

set (MUTTER36_FLAGS "")
pkg_check_modules(MUTTER36 QUIET libmutter>=3.5)
if (MUTTER36_FOUND)
	pkg_check_modules(MUTTER36 REQUIRED libmutter>=3.6.3)
	set (MUTTER36_FLAGS "--define=HAS_MUTTER36")
endif (MUTTER36_FOUND)

set (MUTTER38_FLAGS "")
pkg_check_modules(MUTTER38 QUIET libmutter>=3.7)
if (MUTTER38_FOUND)
	pkg_check_modules(MUTTER38 REQUIRED libmutter>=3.8.4)
	set (MUTTER38_FLAGS "--define=HAS_MUTTER38")
endif (MUTTER38_FOUND)

set (MUTTER310_FLAGS "")
pkg_check_modules(MUTTER310 QUIET libmutter>=3.9)
if (MUTTER310_FOUND)
	pkg_check_modules(MUTTER310 REQUIRED libmutter>=3.10.3)
	set (MUTTER310_FLAGS "--define=HAS_MUTTER310")
endif (MUTTER310_FOUND)

set (MUTTER312_FLAGS "")
pkg_check_modules(MUTTER312 QUIET libmutter>=3.11)
if (MUTTER312_FOUND)
	pkg_check_modules(MUTTER310 REQUIRED libmutter>=3.11.5)
	set (MUTTER312_FLAGS "--define=HAS_MUTTER312")
endif (MUTTER312_FOUND)

add_definitions(${DEPS_CFLAGS})

link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16.1" MINIMUM)

include(ValaPrecompile)

set(VALA_OPTIONS 
    -g
    --vapidir=${CMAKE_CURRENT_SOURCE_DIR}/vapi/
    ${MUTTER36_FLAGS}
    ${MUTTER38_FLAGS}
    ${MUTTER310_FLAGS}
    ${MUTTER312_FLAGS}
	)

# libgala
set(LIB_NAME libgala)
set(LIB_VERSION 0)
set(SOVERSION 0)

set (LIB_DEPS
	libmutter
	libbamf3
	plank
	granite
	clutter-gtk-1.0
)

# get a deps file from the dependencies
set(DEPS_STR "")
foreach (LIB ${LIB_DEPS})
	set(DEPS_STR "${DEPS_STR}${LIB}\n")
endforeach(LIB)
file(WRITE ${CMAKE_BINARY_DIR}/${LIB_NAME}.deps ${DEPS_STR})

vala_precompile(LIB_VALA_C
	lib/Plugin.vala
	lib/Utils.vala
	lib/WindowManager.vala
    ${CMAKE_BINARY_DIR}/lib/Config.vala
PACKAGES
	${LIB_DEPS}
OPTIONS
	${VALA_OPTIONS}
	-X -shared
	-X -fPIX
GENERATE_VAPI
	${LIB_NAME}
GENERATE_HEADER
	${LIB_NAME}
)

add_library(${LIB_NAME} SHARED ${LIB_VALA_C})
set_target_properties(${LIB_NAME} PROPERTIES PREFIX "") # prevent cmake from adding another 'lib'
set_target_properties(${LIB_NAME} PROPERTIES
	VERSION ${LIB_VERSION}.0
	SOVERSION ${SOVERSION}
)
target_link_libraries(${LIB_NAME} ${DEPS_LIBRARIES})

# gala itself
vala_precompile(VALA_C
    src/DBus.vala
    src/DragDropAction.vala
	src/InternalUtils.vala
    src/Main.vala
	src/PluginManager.vala
    src/ScreenSaver.vala
    src/Settings.vala
    src/TextShadowEffect.vala
	src/WindowManager.vala
    src/Background/Background.vala
    src/Background/BackgroundCache.vala
    src/Background/BackgroundManager.vala
    src/Background/SlideShow.vala
    src/Background/SystemBackground.vala
    src/Widgets/AppIcon.vala
    src/Widgets/WindowOverview.vala
    src/Widgets/WindowSwitcher.vala
    src/Widgets/WindowThumb.vala
    src/Widgets/WorkspaceThumb.vala
    src/Widgets/WorkspaceView.vala
PACKAGES
    granite
    libbamf3
    libmutter
    plank
    clutter-gtk-1.0
    gdk-x11-3.0
    gdesktopenums-3.0
    gnome-desktop-3.0
    xfixes-4.0
	gmodule-2.0
	${LIB_NAME}
OPTIONS
    ${VALA_OPTIONS}
	--vapidir=${CMAKE_BINARY_DIR}
    )

# add default plugins
set(PLUGIN_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/plugins)
file(GLOB plugins RELATIVE ${PLUGIN_SOURCE_DIR} plugins/*)
foreach(plugin ${plugins})
	if (NOT ${plugin} STREQUAL "template" AND
		IS_DIRECTORY ${PLUGIN_SOURCE_DIR}/${plugin})
		add_subdirectory(${PLUGIN_SOURCE_DIR}/${plugin})
	endif()
endforeach()

#add_subdirectory (po)

include(GSettings)
add_schema ("data/org.pantheon.desktop.gala.gschema.xml")

add_executable(gala ${VALA_C})
target_link_libraries(gala m ${LIB_NAME})

install(TARGETS ${LIB_NAME} DESTINATION lib)
install(FILES ${CMAKE_BINARY_DIR}/${LIB_NAME}.vapi DESTINATION share/vala/vapi)
install(FILES ${CMAKE_BINARY_DIR}/${LIB_NAME}.deps DESTINATION share/vala/vapi)
install(FILES ${CMAKE_BINARY_DIR}/${LIB_NAME}.h DESTINATION include/${LIB_NAME}/)

install(TARGETS gala RUNTIME DESTINATION bin)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/gala.desktop DESTINATION share/applications)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/gala.css DESTINATION ${PKGDATADIR})
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/texture.png DESTINATION ${PKGDATADIR})
