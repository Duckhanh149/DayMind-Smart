cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "floating_companion.cpp"
  "secure_store.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "shell32.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "crypt32.lib" "ole32.lib" "uuid.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "gdiplus.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Native gate probes are built for CI but stay outside the distributed bundle.
add_executable(daymind_companion_policy_tests "companion_policy_test.cpp")
apply_standard_settings(daymind_companion_policy_tests)
target_compile_definitions(daymind_companion_policy_tests PRIVATE "NOMINMAX")
set_target_properties(daymind_companion_policy_tests PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/companion-tests/$<CONFIG>")
add_executable(daymind_companion_window_probe "companion_window_probe.cpp")
apply_standard_settings(daymind_companion_window_probe)
target_compile_definitions(daymind_companion_window_probe PRIVATE "NOMINMAX")
target_link_libraries(daymind_companion_window_probe PRIVATE "user32.lib")
set_target_properties(daymind_companion_window_probe PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/companion-tests/$<CONFIG>")
