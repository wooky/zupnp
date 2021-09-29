const std = @import("std");
const zupnp = @import("../lib.zig");
const c = @import("../c.zig");

const logger = std.log.scoped(.@"zupnp.util.uuid");

// https://github.com/pupnp/pupnp/blob/branch-1.14.x/upnp/src/inc/uuid.h
const UuidUpnp = extern struct {
    time_low: u32,
    time_mid: u16,
    time_hi_and_version: u16,
    clock_seq_hi_and_reserved: u8,
    clock_seq_low: u8,
    node: [6]u8,
};
extern fn uuid_create(*UuidUpnp) c_int;
extern fn upnp_uuid_unpack (*UuidUpnp, [*c]u8) void;

pub const UUID = [36:0]u8;

pub fn generateUuid() !UUID {
    var uuid_upnp: UuidUpnp = undefined;
    _ = uuid_create(&uuid_upnp);
    var uuid: UUID = undefined;
    upnp_uuid_unpack(&uuid_upnp, &uuid);
    return uuid;
}
