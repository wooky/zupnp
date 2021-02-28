const c = @import("../c.zig");

const Service = @This();

type: []const u8,
id: []const u8,

pub fn handleAction(self: *Service, action: *c.UpnpActionRequest) !void {

}
