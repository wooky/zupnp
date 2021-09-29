const std = @import("std");
const zupnp = @import("../lib.zig");
const c = @import("../c.zig");

const logger = std.log.scoped(.@"zupnp.util.uuid");
const RTLD_LAZY = 1;
const RTLD_NOLOAD = 4;

const UuidUpnp = packed struct {
    time_low: u32,
    time_mid: u16,
    time_hi_and_version: u16,
    clock_seq_hi_and_reserved: u8,
    clock_seq_low: u8,
    node: [6]u8,
};

const Lib = struct {
    const UuidCreateFn = fn (*UuidUpnp) c_int;
    const UpnpUuidUnpackFn = fn (*UuidUpnp, UUID) void;

    uuid_create: UuidCreateFn,
    upnp_uuid_unpack: UpnpUuidUnpackFn,

    fn init() !Lib {
        var libupnp = std.c.dlopen("libupnp.so", RTLD_LAZY | RTLD_NOLOAD) orelse {
            logger.alert("Failed to load libupnp, even though it's already loaded?!", .{});
            return zupnp.Error;
        };
        defer _ = std.c.dlclose(libupnp);
        const uuid_create = std.c.dlsym(libupnp, "uuid_create") orelse {
            logger.alert("uuid_create() missing in libupnp", .{});
            return zupnp.Error;
        };
        const upnp_uuid_unpack = std.c.dlsym(libupnp, "upnp_uuid_unpack") orelse {
            logger.alert("upnp_uuid_unpack() missing in libupnp", .{});
            return zupnp.Error;
        };

        return Lib {
            .uuid_create = @ptrCast(UuidCreateFn, uuid_create),
            .upnp_uuid_unpack = @ptrCast(UpnpUuidUnpackFn, upnp_uuid_unpack),
        };
    }
};

var lib: ?Lib = null;

pub const UUID = [36:0]u8;

pub fn generateUuid() !UUID {
    if (lib == null) {
        lib = try Lib.init();
    }
    var uuid_upnp: UuidUpnp = undefined;
    _ = lib.?.uuid_create(&uuid_upnp);
    var uuid: UUID = undefined;
    lib.?.upnp_uuid_unpack(&uuid_upnp, uuid);
    return uuid;
}
