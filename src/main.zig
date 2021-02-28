pub const upnp = struct {
    pub const Device = @import("upnp/device.zig");
    pub const Server = @import("upnp/server.zig");
    pub const Service = @import("upnp/service.zig");
};

pub const xml = struct {
    pub const Parser = @import("xml/parser.zig");
    pub const Writer = @import("xml/writer.zig");
};
