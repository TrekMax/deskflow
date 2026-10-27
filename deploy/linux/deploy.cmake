# SPDX-FileCopyrightText: (C) 2024 Chris Rizzitello <sithlord48@gmail.com>
# SPDX-License-Identifier: MIT

# HACK This is set when the files is included so its the real path
# calling CMAKE_CURRENT_LIST_DIR after include would return the wrong scope var
set(MY_DIR ${CMAKE_CURRENT_LIST_DIR})

# Install our desktop file
install(
  FILES ${MY_DIR}/${CMAKE_PROJECT_REV_FQDN}.desktop
  DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

# Install our icon
install(FILES ${MY_DIR}/org.deskflow.deskflow.png DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/512x512/apps/)

# Install our symbolic icon
install(
  FILES ${CMAKE_SOURCE_DIR}/src/apps/res/icons/deskflow-light/apps/64/org.deskflow.deskflow-symbolic.svg
  DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/symbolic/apps/
)

# Install our metainfo
install(
  FILES ${MY_DIR}/${CMAKE_PROJECT_REV_FQDN}.metainfo.xml
  DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo/
)

# Prepare PKGBUILD for Arch Linux
configure_file(
  ${MY_DIR}/arch/PKGBUILD.in
  ${CMAKE_BINARY_DIR}/PKGBUILD
  @ONLY
)

set(CPACK_DEBIAN_PACKAGE_SECTION "utils")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_RECOMMENDS "qt6-svg-plugins")
set(CPACK_RPM_PACKAGE_LICENSE "GPLv2")
set(CPACK_RPM_PACKAGE_GROUP "Applications/System")

if(BUNDLE_LINUX_RUNTIME)
  foreach(app IN ITEMS deskflow deskflow-core)
    # Include WaylandClient in Qt's deployment graph so its shell/buffer plugins
    # are deployed along with the GUI platform plugins.
    target_link_libraries(${app} PRIVATE Qt6::WaylandClient)
    qt6_import_plugins(${app}
      INCLUDE_BY_TYPE wayland-shell-integration Qt6::QWaylandXdgShellIntegrationPlugin
      INCLUDE_BY_TYPE wayland-graphics-integration-client Qt6::QWaylandEglClientBufferPlugin
      INCLUDE_BY_TYPE platforms
        Qt6::QXcbIntegrationPlugin Qt6::QWaylandIntegrationPlugin
        Qt6::QWaylandEglPlatformIntegrationPlugin Qt6::QOffscreenIntegrationPlugin
      EXCLUDE_BY_TYPE egldeviceintegrations
    )
    # These targets use add_executable, so explicitly finalize Qt's plugin list.
    qt6_finalize_target(${app})
    qt6_generate_deploy_script(TARGET ${app} OUTPUT_SCRIPT deploy_script CONTENT "
      # Qt 6.8's plugin RPATH adjustment does not account for CPack's DESTDIR.
      set(saved_prefix \"\${CMAKE_INSTALL_PREFIX}\")
      set(saved_destdir \"\$ENV{DESTDIR}\")
      set(CMAKE_INSTALL_PREFIX \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}\")
      set(ENV{DESTDIR} \"\")
      set(QT_DEPLOY_TRANSLATIONS_DIR lib/deskflow/bin/translations)
      qt6_deploy_runtime_dependencies(
        EXECUTABLE $<TARGET_FILE:${app}>
        GENERATE_QT_CONF
        PLUGINS_DIR lib/deskflow/plugins
      )
      set(CMAKE_INSTALL_PREFIX \"\${saved_prefix}\")
      set(ENV{DESTDIR} \"\${saved_destdir}\")
    ")
    install(SCRIPT ${deploy_script})
    install(CODE "
      file(MAKE_DIRECTORY \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/bin\")
      file(CREATE_LINK \"../lib/deskflow/bin/${app}\"
        \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/bin/${app}\" SYMBOLIC)
    ")
  endforeach()
  # SVG support comes from the bundled Qt plugins, not the distro's older Qt.
  unset(CPACK_DEBIAN_PACKAGE_RECOMMENDS)
  find_path(BUNDLED_DEPENDENCY_LICENSES libei.txt
    PATH_SUFFIXES share/licenses/deskflow-dependencies REQUIRED)
  install(DIRECTORY "${BUNDLED_DEPENDENCY_LICENSES}/"
    DESTINATION "${CMAKE_INSTALL_LICENSE_DIR}/dependencies")
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
  # Get Distro name information
  if(EXISTS "/etc/os-release")
    FILE(STRINGS "/etc/os-release" RELEASE_FILE_CONTENTS)
  else()
    message(FATAL_ERROR "Unable to read file /etc/os-release")
  endif()

  foreach(LINE IN LISTS RELEASE_FILE_CONTENTS)
    if( "${LINE}" MATCHES "^ID=")
      string(REGEX REPLACE "^ID=" "" DISTRO_NAME ${LINE})
      string(REGEX REPLACE "\"" "" DISTRO_NAME ${DISTRO_NAME})
      message(DEBUG "Distro Name :${DISTRO_NAME}")
    elseif( "${LINE}" MATCHES "^ID_LIKE=")
      string(REGEX REPLACE "^ID_LIKE=" "" DISTRO_LIKE "${LINE}")
      string(REGEX REPLACE "\"" "" DISTRO_LIKE ${DISTRO_LIKE})
      message(DEBUG "Distro Like :${DISTRO_LIKE}")
    elseif( "${LINE}" MATCHES "^VERSION_CODENAME=")
      string(REGEX REPLACE "^VERSION_CODENAME=" "" DISTRO_CODENAME "${LINE}")
      string(REGEX REPLACE "\"" "" DISTRO_CODENAME "${DISTRO_CODENAME}")
      message(DEBUG "Distro Codename:${DISTRO_CODENAME}")
    elseif( "${LINE}" MATCHES "^VERSION_ID=")
      string(REGEX REPLACE "^VERSION_ID=" "" DISTRO_VERSION_ID "${LINE}")
      string(REGEX REPLACE "\"" "" DISTRO_VERSION_ID "${DISTRO_VERSION_ID}")
      message(DEBUG "Distro VersionID:${DISTRO_VERSION_ID}")
    endif()
  endforeach()

  # Check if Debian-link
  string(REGEX MATCH debian|buntu DEBTYPE "${DISTRO_LIKE}")
  string(REGEX MATCH debian|deepin|uos DEBNAME "${DISTRO_NAME}")
  if((NOT ("${DEBTYPE}" STREQUAL "")) OR (NOT ("${DEBNAME}" STREQUAL "")))
    set(CPACK_GENERATOR "DEB")
  endif()

  # Check if Rpm-like
  string(REGEX MATCH suse|fedora|rhel RPMTYPE "${DISTRO_LIKE}")
  string(REGEX MATCH fedora|suse|rhel RPMNAME "${DISTRO_NAME}")
  if((NOT ("${RPMTYPE}" STREQUAL "")) OR (NOT ("${RPMNAME}" STREQUAL "")))
      set(CPACK_GENERATOR "RPM")
  endif()

  # Disto specific name adjustments
  if("${DISTRO_NAME}" STREQUAL "opensuse-tumbleweed")
    set(DISTRO_NAME "opensuse")
    set(DISTRO_CODENAME "tumbleweed")
  elseif("${DISTRO_NAME}" STREQUAL "arch")
    # Arch linux is rolling the version id reported is the date of last iso.
    set(DISTRO_VERSION_ID "")
  endif()

  # Determain the code name to be used if any
  if(NOT "${DISTRO_VERSION_ID}" STREQUAL "")
    set(CN_STRING "${DISTRO_VERSION_ID}-")
  endif()

  if(NOT "${DISTRO_CODENAME}" STREQUAL "")
    set(CN_STRING "${DISTRO_CODENAME}-")
  endif()

  if("${DISTRO_NAME}" STREQUAL "")
    set(DISTRO_NAME "linux")
  endif()
  set(OS_STRING "${DISTRO_NAME}-${CN_STRING}${BUILD_ARCHITECTURE}")

elseif(${CMAKE_SYSTEM_NAME} MATCHES "|.*BSD")
  message(STATUS "BSD packaging not yet supported")
  set(OS_STRING ${CMAKE_SYSTEM_NAME}-${BUILD_ARCHITECTURE})
endif()
