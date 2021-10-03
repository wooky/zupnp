# Zig UPnP Library (ZUPnP)
ZUPnP is a [Zig](https://ziglang.org/) library which features:
* UPnP/DLNA server
* Web server
* Web client
* XML parser
* Misc. utilities, such as UUID generator

This library is a high-level wrapper around the ubiquitous [pupnp](https://pupnp.sourceforge.io/) (Portable SDK for UPnP Devices, AKA libupnp) library, featuring a convenient API with some Zig-specific specialties thrown in.

## Prerequisites
* libupnp 1.14.x and libixml
  * You will also need these libraries during runtime, unless you statically link them to your application
* Zig 0.8.x
* libupnp-dev 1.14.x

When working with the library in your own code, you should add these lines to your build.zig's build() function:
```zig
const exe = b.addExecutable(...);
exe.addIncludeDir("/usr/include/upnp");
exe.linkLibC();
exe.linkSystemLibrary("upnp");
exe.linkSystemLibrary("ixml");
exe.addPackagePath("zupnp", "zupnp/src/lib.zig");
...
```

## Documentation
Detailed documentation is in progress. For now, check the [test](test) directory to see how some features work.

## Examples
Some examples are included in the [samples](samples) directory. Those include:
* [mediaserver](samples/mediaserver) - serve contents to DLNA receivers
* [website](samples/website) - basic demonstration of static content, GET, and POST requests

## License
Licensed under the MIT license.
