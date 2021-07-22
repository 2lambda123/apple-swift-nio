#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the SwiftNIO open source project
##
## Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of SwiftNIO project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -eu

function make_package() {
    cat > "$tmpdir/syscallwrapper/Package.swift" <<"EOF"
// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "syscallwrapper",
    dependencies: [],
    targets: [
        .target(
            name: "syscallwrapper",
            dependencies: ["CNIOLinux", "CNIODarwin"]),
        .target(
            name: "CNIOLinux",
            dependencies: []),
        .target(
            name: "CNIODarwin",
            dependencies: []),
    ]
)
EOF
    cp "$here/../../Tests/NIOTests/SystemCallWrapperHelpers.swift" \
        "$here/../../Sources/NIOCore/BSDSocketAPI.swift" \
        "$here/../../Sources/NIO/BSDSocketAPICommon.swift" \
        "$here/../../Sources/NIO/BSDSocketAPIPosix.swift" \
        "$here/../../Sources/NIO/System.swift" \
        "$here/../../Sources/NIOCore/IO.swift" \
        "$tmpdir/syscallwrapper/Sources/syscallwrapper"
    cp "$here/../../Sources/NIO/IO.swift" "$tmpdir/syscallwrapper/Sources/syscallwrapper/NIOIO.swift"
    ln -s "$here/../../Sources/CNIOLinux" "$tmpdir/syscallwrapper/Sources"
    ln -s "$here/../../Sources/CNIODarwin" "$tmpdir/syscallwrapper/Sources"
}
