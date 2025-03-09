# SPDX-FileCopyrightText: (C) 2026 Deskflow Developers
# SPDX-FileCopyrightText: (C) 2024 - 2026 Chris Rizzitello <sithlord48@gmail.com>
# SPDX-FileCopyrightText: (C) 2012 - 2025 Symless Ltd
# SPDX-FileCopyrightText: (C) 2009 - 2012 Nick Bolton
# SPDX-License-Identifier: MIT

# set(ENV{http_proxy} "http://127.0.0.1:8889")
# set(ENV{https_proxy} "http://127.0.0.1:8889")
find_package(CLI11 QUIET)
if(CLI11_FOUND)
  message(STATUS "CLI11 [System] Version: ${CLI11_VERSION}")
  set(cli11_lib CLI11::CLI11)
else()
  #Be sure to update the version and MD5 together
  set(CLI11_VERSION 2.4.2)
  set(CLI11_MD5 d7923d1ca06d03e2299e55cad532d126)
  message(STATUS "Downloading CLI11 ${CLI11_VERSION} URL: \"https://github.com/CLIUtils/CLI11/releases/download/v${CLI11_VERSION}/CLI11.hpp\"")
  file(
    DOWNLOAD "https://github.com/CLIUtils/CLI11/releases/download/v${CLI11_VERSION}/CLI11.hpp"
    "${CMAKE_BINARY_DIR}/include/CLI/CLI.hpp"
    EXPECTED_MD5 ${CLI11_MD5}
  )
  set(cli11_inc_dir "${CMAKE_BINARY_DIR}/include")
  message(STATUS "CLI11 [Downloaded] Version: ${CLI11_VERSION}")
  message(STATUS "CLI11 INC_DIR: ${cli11_inc_dir}")
endif()

find_package(tomlplusplus QUIET)
if(tomlplusplus_FOUND)
  message(STATUS "tomlplusplus [System] Version: ${tomlplusplus_VERSION}")
  set(tomlPP_lib tomlplusplus::tomlplusplus)
else()
  # Be sure to update the version and MD5 together
  # Save our copy with .h not .hpp for compatibliy with system version < 3.4
  set(TOMLPP_VERSION 3.4.0)
  set(TOMLPP_MD5 caefb3b60119731fb4b4d24b6339e7fb)
  file(
    DOWNLOAD "https://raw.githubusercontent.com/marzer/tomlplusplus/refs/tags/v${TOMLPP_VERSION}/toml.hpp"
    "${CMAKE_BINARY_DIR}/include/toml++/toml.h"
    SHOW_PROGRESS
    EXPECTED_MD5 ${TOMLPP_MD5}
  )
  set(tomlPP_inc_dir "${CMAKE_BINARY_DIR}/include")
  message(STATUS "tomlplusplus [Downloaded] Version: 3.4.0")
  message(STATUS "tomlplusplus INC DIR: ${tomlPP_inc_dir}")
endif()

if (WIN32)
  find_package(unofficial-wintoast CONFIG REQUIRED)
  set(wintoast-lib unofficial::wintoast::wintoast)
endif()

####################Start Making Library#########################
set(lib_name app)

# arch
if(WIN32)
  set(PLATFORM_CODE
    win32/AppUtilWindows.cpp
    win32/AppUtilWindows.h
  )
elseif(UNIX)
  set(PLATFORM_CODE
    unix/AppUtilUnix.cpp
    unix/AppUtilUnix.h
    unix/DeskflowXkbKeyboard.cpp
    unix/DeskflowXkbKeyboard.h
    unix/ISO639Table.h
    unix/XkbLayoutsParser.cpp
    unix/XkbLayoutsParser.h
  )
endif()

add_library(${lib_name} STATIC ${PLATFORM_CODE}
  App.cpp
  App.h
  AppUtil.cpp
  AppUtil.h
  Chunk.cpp
  Chunk.h
  ClientApp.cpp
  ClientApp.h
  ClipboardTypes.h
  Clipboard.cpp
  Clipboard.h
  ClipboardChunk.cpp
  ClipboardChunk.h
  Computer.cpp
  Computer.h
  DeskflowException.cpp
  DeskflowException.h
  DisplayException.cpp
  DisplayException.h
  DisplayInvalidException.h
  IApp.h
  IClient.h
  IClipboard.cpp
  IClipboard.h
  IComputer.h
  IKeyState.cpp
  IKeyState.h
  IPlatformComputer.h
  IPrimaryComputer.cpp
  IPrimaryComputer.h
  IScreenSaver.h
  ISecondaryComputer.h
  KeyTypes.cpp
  KeyTypes.h
  KeyMap.cpp
  KeyMap.h
  KeyState.cpp
  KeyState.h
  MouseTypes.h
  OptionTypes.h
  PacketStreamFilter.cpp
  PacketStreamFilter.h
  PlatformComputer.cpp
  PlatformComputer.h
  ProtocolTypes.cpp
  ProtocolTypes.h
  ProtocolUtil.cpp
  ProtocolUtil.h
  ServerApp.cpp
  ServerApp.h
  StreamChunker.cpp
  StreamChunker.h
  KeyboardLayoutManager.cpp
  KeyboardLayoutManager.h
  ipc/IpcServer.cpp
  ipc/IpcServer.h
  ipc/DaemonIpcServer.cpp
  ipc/DaemonIpcServer.h
  ipc/CoreIpc.cpp
  ipc/CoreIpc.h
  ipc/CoreIpcServer.cpp
  ipc/CoreIpcServer.h
)

target_link_libraries(${lib_name}
  PUBLIC
    common
    Qt6::Network
  PRIVATE
    platform
)

if(UNIX AND NOT APPLE)
  target_link_libraries(${lib_name} PRIVATE server)
endif()
