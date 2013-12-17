
set(PLUGIN_NAME zoom)

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

vala_precompile(ZOOM_VALA_C
	Main.vala
PACKAGES
	clutter-1.0
	libgala
OPTIONS
    ${MUTTER36_FLAGS}
    ${MUTTER38_FLAGS}
    ${MUTTER310_FLAGS}
    ${MUTTER312_FLAGS}
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
	--vapidir=${CMAKE_BINARY_DIR}
)

# include(GSettings)
# add_schema ("org.pantheon.desktop.gala.plugins.zoom.gschema.xml")

add_library(${PLUGIN_NAME} MODULE ${ZOOM_VALA_C})
target_link_libraries(${PLUGIN_NAME} ${LIB_NAME})
install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR})
add_dependencies(${PLUGIN_NAME} ${LIB_NAME})

message("-- Compiling plugin ${PLUGIN_NAME}")
