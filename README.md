# SwiftNIO

SwiftNIO is a cross-platform asynchronous event-driven network application framework
for rapid development of maintainable high performance protocol servers & clients.

It's like [Netty](https://netty.io), but written for Swift.

## Conceptual Overview

SwiftNIO is fundamentally a low-level tool for building high-performance networking applications in Swift. It particularly targets those use-cases where using a "thread-per-connection" model of concurrency is inefficient or untenable. This is a common limitation when building servers that use a large number of relatively low-utilisation connections, such as HTTP servers.

To achieve its goals SwiftNIO extensively uses "non-blocking I/O": hence the name! Non-blocking I/O differs from the more common blocking I/O model because the application does not wait for data to be sent to or received from the network: instead, SwiftNIO asks for the kernel to notify it when I/O operations can be performed without waiting.

SwiftNIO does not aim to provide high-level solutions like, for example, web frameworks do. Instead, SwiftNIO is focused on providing the low-level building blocks for these higher-level applications. When it comes to building a web application, most users will not want to use SwiftNIO directly: instead, they'll want to use one of the many great web frameworks available in the Swift ecosystem. Those web frameworks, however, may choose to use SwiftNIO under the covers to provide their networking support.

The following sections will describe the low-level tools that SwiftNIO provides, and provide a quick overview of how to work with them. If you feel comfortable with these concepts, then you can skip right ahead to the other sections of this README.

### Supported Platforms

SwiftNIO aims to support all of the platforms where Swift is supported. Currently, it is developed and tested on macOS and Linux, and is known to support the following operating system versions:

* Ubuntu 14.04+
* macOS 10.12+

### Basic Architecture

The basic building blocks of SwiftNIO are the following 6 types of objects:

- `EventLoopGroup`, a protocol
- `EventLoop`, a protocol
- `Channel`, a protocol
- `ChannelHandler`, a protocol
- `Bootstrap`, several related structures
- `ByteBuffer`, a struct
- `EventLoopPromise` and `EventLoopFuture`, two generic classes.

All SwiftNIO applications are ultimately constructed of these various components.

#### EventLoops and EventLoopGroups

The basic I/O primitive of SwiftNIO is the event loop. The event loop is an object that waits for events (usually I/O related events, such as "data received") to happen and then fires some kind of callback when they do. In almost all SwiftNIO applications there will be relatively few event loops: usually only one or two per CPU core the application wants to use. Generally speaking event loops run for the entire lifetime of your application, spinning in an endless loop dispatching events.

Event loops are gathered together into event loop *groups*. These groups provide a mechanism to distribute work around the event loops. For example, when listening for inbound connections the listening socket will be registered on one event loop. However, we don't want all connections that are accepted on that listening socket to be registered with the same event loop, as that would potentially overload one event loop while leaving the others empty. For that reason, the event loop group provides the ability to spread load across multiple event loops.

In SwiftNIO today there is one `EventLoopGroup` implementation, and two `EventLoop` implementations. For production applications there is the `MultiThreadedEventLoopGroup`, an `EventLoopGroup` that creates a number of threads (using the POSIX `pthreads` library) and places one `SelectableEventLoop` on each one. The `SelectableEventLoop` is an event loop that uses a selector (either `kqueue` or `epoll` depending on the target system) to manage I/O events from file descriptors and to dispatch work. Additionally, there is the `EmbeddedEventLoop`, which is a dummy event loop that is used primarily for testing purposes.

`EventLoop`s have a number of important properties. Most vitally, they are the way all work gets done in SwiftNIO applications. In order to ensure thread-safety, any work that wants to be done on almost any of the other objects in SwiftNIO must be dispatched via an `EventLoop`. `EventLoop` objects own almost all the other objects in a SwiftNIO application, and understanding their execution model is critical for building high-performance SwiftNIO applications.

#### Channels, Channel Handlers, Channel Pipelines, and Channel Contexts

While `EventLoop`s are critical to the way SwiftNIO works, most users will not interact with them substantially beyond asking them to create `EventLoopPromise`s and to schedule work. The parts of a SwiftNIO application most users will spend the most time interacting with are `Channel`s and `ChannelHandler`s.

Almost every file descriptor that a user interacts with in a SwiftNIO program is associated with a single `Channel`. The `Channel` owns this file descriptor, and is responsible for managing its lifetime. It is also responsible for processing inbound and outbound events on that file descriptor: whenever the event loop has an event that corresponds to a file descriptor, it will notify the `Channel` that owns that file descriptor.

`Channel`s by themselves, however, are not useful. After all, it is a rare application that doesn't want to anything with the data it sends or receives on a socket! So the other important part of the `Channel` is the `ChannelPipeline`.

A `ChannelPipeline` is a sequence of objects, called `ChannelHandler`s, that process events on a `Channel`. The `ChannelHandlers` process these events one after another, in order, mutating and transforming events as they go. This can be thought of as a data processing pipeline; hence the name `ChannelPipeline`.

All `ChannelHandler`s are either Inbound or Outbound handlers, or both. Inbound handlers process "inbound" events: events like reading data from a socket, reading socket close, or other kinds of events initiated by remote peers. Outbound handlers process "outbound" events, such as writes, connection attempts, and local socket closes.

Each handler processes the events in order. For example, read events are passed from the front of the pipeline to the back, one handler at a time, while write events are passed from the back of the pipeline to the front. Each handler may, at any time, generate either inbound or outbound events that will be sent to the next handler in whichever direction is appropriate. This allows handlers to split up reads, coalesce writes, delay connection attempts, and generally perform arbitrary transformations of events.

In general, `ChannelHandler`s are designed to be highly re-usable components. This means they tend to be designed to be as small as possible, performing one specific data transformation. This allows handlers to be composed together in novel and flexible ways, which helps with code reuse and encapsulation.

`ChannelHandler`s are able to keep track of where they are in a `ChannelPipeline` by using a `ChannelHandlerContext`. These objects contain references to the previous and next channel handler in the pipeline, ensuring that it is always possible for a `ChannelHandler` to emit events while it remains in a pipeline.

SwiftNIO ships with many `ChannelHandler`s built in that provide useful functionality, such as HTTP parsing. In addition, high-performance applications will want to provide as much of their logic as possible in `ChannelHandler`s, as it helps avoid problems with context switching.

Additionally, SwiftNIO ships with a few `Channel` implementations. In particular, it ships with `ServerSocketChannel`, a `Channel` for sockets that accept inbound connections; `SocketChannel`, a `Channel` for TCP connections; `DatagramChannel`, a `Channel` for UDP sockets; and `EmbeddedChannel`, a `Channel` primarily used for testing.

##### A Note on Blocking

One of the important notes about `ChannelPipeline`s is that they are not thread-safe. This is very important for writing SwiftNIO applications, as it allows you to write much simpler `ChannelHandler`s in the knowledge that they will not require synchronization.

However, this is achieved by dispatching all code on the `ChannelPipeline` on the same thread as the `EventLoop`. This means that, as a general rule, `ChannelHandler`s **must not** call blocking code without dispatching it to a background thread. If a `ChannelHandler` blocks for any reason, all `Channel`s attached to the parent `EventLoop` will be unable to progress until the blocking call completes.

This is a common concern while writing SwiftNIO applications. If it is useful to write code in a blocking style, it is highly recommended that you dispatch work to a different thread when you're done with it in your pipeline.

#### Bootstrap

While it is possible to configure and register `Channel`s with `EventLoop`s directly, it is generally more useful to have a higher-level abstraction to handle this work.

For this reason, SwiftNIO ships a number of `Bootstrap` objects whose purpose is to streamline the creation of channels. Some `Bootstrap` objects also provide other functionality, such as support for Happy Eyeballs for making TCP connection attempts.

Currently SwiftNIO ships with three `Bootstrap` objects: `ServerBootstrap`, for bootstrapping listening channels; `ClientBootstrap`, for bootstrapping client TCP channels; and `DatagramBootstrap` for bootstraping UDP channels.

#### ByteBuffer

The majority of the work in a SwiftNIO application involves shuffling buffers of bytes around. At the very least, data is sent and received to and from the network in the form of buffers of bytes. For this reason it's very important to have a high-performance data structure that is optimised for the kind of work SwiftNIO applications perform.

For this reason, SwiftNIO provides `ByteBuffer`, a fast copy-on-write byte buffer that forms a key building block of most SwiftNIO applications.

`ByteBuffer` provides a number of useful features, and in addition provides a number of hooks to use it in an "unsafe" mode. This turns off bounds checking for improved performance, at the cost of potentially opening your application up to memory correctness problems.

In general, it is highly recommended that you use the `ByteBuffer` in its safe mode at all times.

For more details on the API of `ByteBuffer`, please see our API documentation, linked below.

#### Promises and Futures

One major difference between writing concurrent code and writing synchronous code is that not all actions will complete immediately. For example, when you write data on a channel, it is possible that the event loop will not be able to immediately flush that write out to the network. For this reason, SwiftNIO provides `EventLoopPromise<T>` and `EventLoopFuture<T>` to manage operations that complete *asynchronously*.

An `EventLoopFuture<T>` is essentially a container for the return value of a function that will be populated *at some time in the future*. Each `EventLoopFuture<T>` has a corresponding `EventLoopPromise<T>`, which is the object that the result will be put into. When the promise is succeeded, the future will be fulfilled.

If you had to poll the future to detect when it completed that would be quite inefficient, so `EventLoopFuture<T>` is designed to have managed callbacks. Essentially, you can hang callbacks off the future that will be executed when a result is available. The `EventLoopFuture<T>` will even carefully arrange the scheduling to ensure that these callbacks always execute on the event loop that initially created the promise, which helps ensure that you don't need too much synchronization around `EventLoopFuture<T>` callbacks.

There are several functions for applying callbacks to `EventLoopFuture<T>`, depening on how and when you want them to execute. Details of these functions is left to the API documentation.

### Design Philosophy

SwiftNIO is designed to be a powerful tool for building networked applications and frameworks, but it is not intended to be the perfect solution for all levels of abstraction. SwiftNIO is tightly focused on providing the basic I/O primitives and protocol implementations at low levels of abstraction, leaving more expressive but slower abstractions to the wider community to build. The intention is that SwiftNIO will be a building block for server-side applications, not necessarily the framework those applications will use directly.

Applications that need extremely high performance from their networking stack may choose to use SwiftNIO directly in order to reduce the overhead of their abstractions. These applications should be able to maintain extremely high performance with relatively little maintenance cost. SwiftNIO also focuses on providing useful abstractions for this use-case, such that extremely high performance network servers can be built directly.

The core SwiftNIO repository will contain a few extremely important protocol implementations, such as HTTP, directly in tree. However, we believe that most protocol implementations should be decoupled from the release cycle of the underlying networking stack, as the release cadence is likely to be very different (either much faster or much slower). For this reason, we actively encourage the community to develop and maintain their protocol implementations out-of-tree. Indeed, some first-party SwiftNIO protocol implementations, including our TLS and HTTP/2 bindings, are developed out-of-tree!

## Useful Protocol Implementations

The following projects contain useful protocol implementations that do not live in-tree in SwiftNIO:

- [swift-nio-ssl](https://github.com/apple/swift-nio-ssl)
- swift-nio-http2 (coming soon)

## Documentation

 - [API documentation](https://apple.github.io/swift-nio/docs/current/NIO/index.html)


## Getting Started

SwiftNIO primarily uses [SwiftPM](https://swift.org/package-manager/) as its build tool, so we recommend using that as well. If you want to depend on SwiftNIO in your own project, it's as simple as adding a `dependencies` clause to your `Package.swift`:

    dependencies: [
        .package(url: "https://github.com/apple/swift-nio-zlib-support.git", from: "1.0.0")
    ]

and then adding the appropriate SwiftNIO module(s) to your target dependencies.

To work on SwiftNIO itself, or to investigate some of the demonstration applications, you can clone the repository directly and use SwiftPM to help build it. For example, you can run the folloiwng commands to compile and run the example echo server:

    swift build
    swift test
    swift run NIOEchoServer

To verify that it is working, you can use another shell to attempt to connect to it:

    echo "Hello SwiftNIO" | nc localhost 9999

If all goes well, you'll see the message echoed back to you.

### An alternative: using `docker-compose`

Alternatively, you may want to develop or test with `docker-compose`.

To do that, first `cd docker` and then run the following commands:

- `docker-compose up test`

  Will create a base image with Swift 4.0 (if missing), compile SwiftNIO and run the tests

- `docker-compose up echo`

  Will create a base image, compile SwiftNIO, and run a sample `NIOEchoServer` on
  `localhost:9999`. Test it by `echo Hello SwiftNIO | nc localhost 9999`.

- `docker-compose up http`

  Will create a base image, compile SwiftNIO, and run a sample `NIOHTTP1Server` on
  `localhost:8888`. Test it by `curl http://localhost:8888`


## Developing SwiftNIO

For the most part, SwiftNIO development is as straightforward as any other SwiftPM project. With that said, we do have a few processes that are worth understanding before you contribute. For details, please see `CONTRIBUTING.md` in this repository.
