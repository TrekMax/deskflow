# SPDX-FileCopyrightText: (C) 2024 Chris Rizzitello <sithlord48@gmail.com>
# SPDX-License-Identifier: MIT

# HACK This is set when the files is included so its the real path
# calling CMAKE_CURRENT_LIST_DIR after include would return the wrong scope var
set(MY_DIR ${CMAKE_CURRENT_LIST_DIR})
set(OSX_BUNDLE ${BUILD_OSX_BUNDLE})

set(OS_STRING "macos-${BUILD_ARCHITECTURE}")

if (OSX_BUNDLE)
  # Ad-hoc signatures have no Team ID and cannot satisfy Hardened Runtime's
  # same-team library validation on a receiving Mac.
  set(_codesign_options "-codesign=-")
  if (APPLE_CODESIGN_DEV AND NOT APPLE_CODESIGN_DEV STREQUAL "-")
    set(_codesign_options "-hardened-runtime -timestamp \"-codesign=${APPLE_CODESIGN_DEV}\"")
  endif()
  install(CODE "execute_process(COMMAND
    \"${DEPLOYQT}\"
    \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_PROJECT_PROPER_NAME}.app\"
    ${_codesign_options}
    COMMAND_ERROR_IS_FATAL ANY
  )")
  set(CPACK_PACKAGE_ICON "${MY_DIR}/dmg-volume.icns")
  set(CPACK_DMG_BACKGROUND_IMAGE "${MY_DIR}/dmg-background.tiff")
  set(CPACK_DMG_DS_STORE_SETUP_SCRIPT "${MY_DIR}/generate_ds_store.applescript")
  set(CPACK_DMG_VOLUME_NAME "${CMAKE_PROJECT_PROPER_NAME}")
  set(CPACK_DMG_SLA_USE_RESOURCE_FILE_LICENSE ON)
  set(CPACK_GENERATOR "DragNDrop")
endif()
