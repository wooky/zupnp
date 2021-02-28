pub const upnp = struct {
    pub const Device = @import("device.zig");
    pub const Server = @import("server.zig");
    pub const Service = @import("service.zig");
};

pub const xml = struct {
    pub const Parser = @import("xml/parser.zig");
    pub const Writer = @import("xml/writer.zig");
};
