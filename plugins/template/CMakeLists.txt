
set(PLUGIN_NAME template)

# here we benefit from the fact that the variables from gala's
# build are still defined, so we can just reuse those. In fact,
# we wouldn't even need to call those functions. If you want to
# to build 'standalone', you'll need to get the deps together 
# yourself with pkg_check_modules.
add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

vala_precompile(TEMPLATE_VALA_C
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

# if you want to add settings, this is how to make cmake install them
# include(GSettings)
# add_schema ("org.pantheon.desktop.gala.plugins.template.gschema.xml")

add_library(${PLUGIN_NAME} MODULE ${TEMPLATE_VALA_C})
target_link_libraries(${PLUGIN_NAME} ${LIB_NAME})
install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR})
add_dependencies(${PLUGIN_NAME} ${LIB_NAME})

message("-- Compiling plugin ${PLUGIN_NAME}")
