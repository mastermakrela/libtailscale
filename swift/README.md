# tailscale

The tailscale Swift package provides an embedded network interface that can be
used to listen for and dial connections to other [Tailscale](https://tailscale.com) nodes.

The interfaces are similar in design to NWConnection, but are Swift 6 compliant and
designed to be used in modern async/await style code.

## Build and Install

Build Requirements:
  - xCode 16.1 or newer

Building Tailscale.framework:

From /swift 
    $ make build

Will build Tailscale.framework into /swift/build/Build/Products.

Separate frameworks will be built for macOS and iOS.  All dependencies (libtailscale.a)
are built automatically.  Swift 6 is supported.

Alternatively, you may build from xCode using the Tailscale scheme.

Non-apple builds are not supported yet, but the wrappers are dependency
free and compiling the swift sources for other platforms should be possible.

Use xCode to run the tests.

## Usage

The node will need to be authorized in order to function. Set an auth key via
the config.authKey parameter, or watch the log stream and respond to the printed
authorization URL.

## Contributing

Pull requests are welcome on GitHub at https://github.com/tailscale/libtailscale

Please file any issues about this code or the hosted service on
[the issue tracker](https://github.com/tailscale/tailscale/issues).
