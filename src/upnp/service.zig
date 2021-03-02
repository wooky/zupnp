const c = @import("../c.zig");
const std = @import("std");
const zupnp = @import("../main.zig");

const Service = @This();

service_type: []const u8,
service_id: []const u8,
schema: zupnp.xml.Document,

pub fn init(service_type: []const u8, service_id: []const u8, schema: zupnp.xml.Document) Service {
    return .{
        .service_type = service_type,
        .service_id = service_id,
        .schema = schema,
    };
}

pub fn deinit(self: *Service) void {
    self.schema.deinit();
}

pub fn handleAction(self: *Service, action: *c.UpnpActionRequest) !void {

}

pub const Request = struct {

};

pub const Response = struct {

};
