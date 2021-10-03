const std = @import("std");
const zupnp = @import("zupnp");

pub fn main() !void {
    var lib = try zupnp.ZUPnP.init(std.heap.page_allocator, .{});
    defer lib.deinit();
    lib.server.static_root_dir = "static";
    try lib.server.start();
    const zig_png = "/zig.png";
    const zig_png_url = try std.fmt.allocPrint(std.heap.page_allocator, "{s}{s}", .{lib.server.base_url, zig_png});
    defer std.heap.page_allocator.free(zig_png_url);

    var media_server = try lib.device_manager.createDevice(zupnp.upnp.device.MediaServer, .{
        .friendlyName = "ZUPnP Test",
        .manufacturer = "ZUPnP",
        .modelName = "Put something fun here",
        .iconList = .{
            .icon = &.{
                .{
                    .mimetype = "image/png",
                    .width = 48,
                    .height = 48,
                    .depth = 24,
                    .url = zig_png,
                },
            },
        },
    }, {});

    const videosId = "1";
    const imagesId = "2";
    const audioId = "3";
    try media_server.content_directory.containers.appendSlice(&.{
        .{
            .__attributes__ = .{
                .id = videosId,
            },
            .@"dc:title" = "Videos",
            .@"upnp:class" = "object.container",
        },
        .{
            .__attributes__ = .{
                .id = imagesId,
            },
            .@"dc:title" = "Images",
            .@"upnp:class" = "object.container",
        },
        .{
            .__attributes__ = .{
                .id = audioId,
            },
            .@"dc:title" = "Audio",
            .@"upnp:class" = "object.container",
        },
    });

    // TODO all type signatures are required, otherwise compiler crashes
    try media_server.content_directory.items.appendSlice(&[_] zupnp.upnp.definition.content_directory.Item {
        .{
            .__attributes__ = .{
                .id = "99",
            },
            .@"dc:title" = "Zig!",
            .@"upnp:class" = "object.item.imageItem.photo",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:image/png:*"
                    },
                    .__item__ = zig_png_url,
                },
            },
        },
        .{
            .__attributes__ = .{
                .id = "100",
                .parentID = videosId,
            },
            .@"dc:title" = "1MB MP4",
            .@"upnp:class" = "object.item.videoItem.movie",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:video/mp4:*"
                    },
                    .__item__ = "http://103.145.51.95/video123/mp4/720/big_buck_bunny_720p_1mb.mp4",
                },
            },
        },
        .{
            .__attributes__ = .{
                .id = "101",
                .parentID = videosId,
            },
            .@"dc:title" = "1MB FLV",
            .@"upnp:class" = "object.item.videoItem.movie",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:video/x-flv:*"
                    },
                    .__item__ = "http://103.145.51.95/video123/flv/720/big_buck_bunny_720p_1mb.flv",
                },
            },
        },
        .{
            .__attributes__ = .{
                .id = "102",
                .parentID = videosId,
            },
            .@"dc:title" = "1MB MKV",
            .@"upnp:class" = "object.item.videoItem.movie",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:video/x-matroska:*"
                    },
                    .__item__ = "http://103.145.51.95/video123/mkv/720/big_buck_bunny_720p_1mb.mkv",
                },
            },
        },
        .{
            .__attributes__ = .{
                .id = "103",
                .parentID = videosId,
            },
            .@"dc:title" = "1MB 3GP",
            .@"upnp:class" = "object.item.videoItem.movie",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:video/3gpp:*"
                    },
                    .__item__ = "http://103.145.51.95/video123/3gp/240/big_buck_bunny_240p_1mb.3gp",
                },
            },
        },
        .{
            .__attributes__ = .{
                .id = "200",
                .parentID = imagesId,
            },
            .@"dc:title" = "50kB JPG",
            .@"upnp:class" = "object.item.imageItem.photo",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:image/jpeg:*"
                    },
                    .__item__ = "http://103.145.51.95/img/Sample-jpg-image-50kb.jpg",
                },
            },
        },
        .{
            .__attributes__ = .{
                .id = "201",
                .parentID = imagesId,
            },
            .@"dc:title" = "100kB PNG",
            .@"upnp:class" = "object.item.imageItem.photo",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:image/png:*"
                    },
                    .__item__ = "http://103.145.51.95/img/Sample-png-image-100kb.png",
                },
            },
        },
        .{
            .__attributes__ = .{
                .id = "202",
                .parentID = imagesId,
            },
            .@"dc:title" = "40kB GIF",
            .@"upnp:class" = "object.item.imageItem.photo",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:image/gif:*"
                    },
                    .__item__ = "http://103.145.51.95/gif/3.gif",
                },
            },
        },
        // .{
        //     .__attributes__ = .{
        //         .id = "203",
        //         .parentID = imagesId,
        //     },
        //     .@"dc:title" = "23kB SVG",
        //     .@"upnp:class" = "object.item.imageItem.photo",
        //     .res = &[_] zupnp.upnp.definition.content_directory.Res {
        //         .{
        //             .__attributes__ = .{
        //                 .protocolInfo = "http-get:*:image/svg+xml:*"
        //             },
        //             .__item__ = "http://103.145.51.95/svg/1.svg",
        //         },
        //     },
        // },
        .{
            .__attributes__ = .{
                .id = "300",
                .parentID = audioId,
            },
            .@"dc:title" = "0.4MB MP3",
            .@"upnp:class" = "object.item.audioItem.musicTrack",
            .res = &[_] zupnp.upnp.definition.content_directory.Res {
                .{
                    .__attributes__ = .{
                        .protocolInfo = "http-get:*:audio/mpeg:*"
                    },
                    .__item__ = "http://103.145.51.95/audio/mp3/crowd-cheering.mp3",
                },
            },
        },
    });
    

    while (true) {
        std.time.sleep(1_000_000);
    }
}


