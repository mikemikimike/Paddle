# Copyright (c) 2016 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

IF(MOBILE_INFERENCE OR NOT WITH_DISTRIBUTE)
    return()
ENDIF()

include (ExternalProject)

SET(GRPC_SOURCES_DIR ${THIRD_PARTY_PATH}/grpc)
SET(GRPC_INSTALL_DIR ${THIRD_PARTY_PATH}/install/grpc)
SET(GRPC_INCLUDE_DIR "${GRPC_INSTALL_DIR}/include/" CACHE PATH "grpc include directory." FORCE)
SET(GRPC_CPP_PLUGIN "${GRPC_INSTALL_DIR}/bin/grpc_cpp_plugin" CACHE FILEPATH "GRPC_CPP_PLUGIN" FORCE)

include(ProcessorCount)
ProcessorCount(NUM_OF_PROCESSOR)

IF(APPLE)
  SET(BUILD_CMD make -n HAS_SYSTEM_PROTOBUF=false -s -j ${NUM_OF_PROCESSOR} static grpc_cpp_plugin | sed "s/-Werror//g" | sh)
ELSE()
  SET(BUILD_CMD make HAS_SYSTEM_PROTOBUF=false -s -j ${NUM_OF_PROCESSOR} static grpc_cpp_plugin)
ENDIF()

# FIXME(wuyi): do not build zlib cares protobuf twice, find a way to build grpc with them
ExternalProject_Add(
    extern_grpc
    DEPENDS protobuf zlib
    # NOTE(wuyi):
    # this package is generated by following steps:
    # 1. git clone -b v1.8.x https://github.com/grpc/grpc.git
    # 2. git submodule update --init
    # 3. keep only zlib, cares, protobuf, boringssl under "third_party",
    #    checkout and clean other dirs under third_party
    # 4. remove .git, and package the directory.
    URL "http://paddlepaddledeps.bj.bcebos.com/grpc-v1.10.x.tar.gz"
    URL_MD5  "1f268a2aff6759839dccd256adcc91cf"
    PREFIX          ${GRPC_SOURCES_DIR}
    UPDATE_COMMAND  ""
    CONFIGURE_COMMAND ""
    PATCH_COMMAND "git apply ${PADDLE_SOURCE_DIR}/patches/grpc/fix_too_early_destory.patch"
    # NOTE(yuyang18):
    # Disable -Werror, otherwise the compile will fail in MacOS.
    # It seems that we cannot configure that by make command.
    # Just dry run make command and remove `-Werror`, then use a shell to run make commands
    BUILD_COMMAND  ${BUILD_CMD}
    INSTALL_COMMAND make prefix=${GRPC_INSTALL_DIR} install
)

ADD_LIBRARY(grpc++_unsecure STATIC IMPORTED GLOBAL)
SET_PROPERTY(TARGET grpc++_unsecure PROPERTY IMPORTED_LOCATION
             "${GRPC_INSTALL_DIR}/lib/libgrpc++_unsecure.a")

ADD_LIBRARY(grpc++ STATIC IMPORTED GLOBAL)
SET_PROPERTY(TARGET grpc++ PROPERTY IMPORTED_LOCATION
            "${GRPC_INSTALL_DIR}/lib/libgrpc++.a")
ADD_LIBRARY(gpr STATIC IMPORTED GLOBAL)
SET_PROPERTY(TARGET gpr PROPERTY IMPORTED_LOCATION
            "${GRPC_INSTALL_DIR}/lib/libgpr.a")

ADD_LIBRARY(grpc_unsecure STATIC IMPORTED GLOBAL)
SET_PROPERTY(TARGET grpc_unsecure PROPERTY IMPORTED_LOCATION
            "${GRPC_INSTALL_DIR}/lib/libgrpc_unsecure.a")

include_directories(${GRPC_INCLUDE_DIR})
ADD_DEPENDENCIES(grpc++_unsecure extern_grpc)
