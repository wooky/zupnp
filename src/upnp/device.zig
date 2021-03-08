const c = @import("../c.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const zupnp = @import("../main.zig");

const Device = @This();
const ServiceList = std.ArrayList(*zupnp.upnp.Service);
const logger = std.log.scoped(.Device);

pub const Error = error.UPnPError;

allocator: *Allocator,
device_type: []const u8,
friendly_name: []const u8,
services: ServiceList,

handle: c.UpnpDevice_Handle = undefined,

pub fn init(
    allocator: *Allocator,
    device_type: []const u8,
    friendly_name: []const u8
) !Device {
    return Device {
        .allocator = allocator,
        .device_type = device_type,
        .friendly_name = friendly_name,
        .services = ServiceList.init(allocator),
    };
}

pub fn deinit(self: *Device) void {
    _ = c.UpnpUnRegisterRootDevice(self.handle);
    self.services.deinit();
}

pub fn addService(self: *Device, service: *zupnp.upnp.Service) !void {
    try self.services.append(service);
}

pub fn createSchema(self: *Device, udn: []const u8, udn_url: []const u8) !zupnp.xml.DOMString {
    var writer = zupnp.xml.Writer.init(self.allocator);
    defer writer.deinit();

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var schema_services = std.ArrayList(DeviceSchema.Service).init(&arena.allocator);
    for (self.services.items) |service, idx| {
        try schema_services.append(.{
            .serviceType = service.service_type,
            .serviceId = try std.fmt.allocPrint(&arena.allocator, "{}", .{idx}),
            .SCPDURL = try std.fmt.allocPrint(&arena.allocator, "{}/scpd/{}", .{udn_url, idx}),
            .controlURL = try std.fmt.allocPrint(&arena.allocator, "{}/control/{}", .{udn_url, idx}),
            .eventSubURL = try std.fmt.allocPrint(&arena.allocator, "{}/event/{}", .{udn_url, idx}),
        });
    }

    const schema = DeviceSchema {
        .root = .{
            .__attributes__ = .{},
            .specVersion = .{},
            .device = .{
                .deviceType = self.device_type,
                .friendlyName = self.friendly_name,
                .UDN = udn,
                .iconList = null,
                .serviceList = .{
                    .service = schema_services.items,
                },
            },
        },
    };
    var doc = try writer.writeStructToDocument(schema);
    defer doc.deinit();
    return try doc.toString();
}

pub fn onEvent(event_type: c.Upnp_EventType, event: ?*const c_void, cookie: ?*c_void) callconv(.C) c_int {
    var self = @ptrCast(*Device, @alignCast(8, cookie));
    var mut_event = @intToPtr(*c_void, @ptrToInt(event));
    switch (event_type) {
        c.Upnp_EventType.UPNP_CONTROL_ACTION_REQUEST =>
            self.handleAction(@ptrCast(*c.UpnpActionRequest, mut_event)) catch |err| logger.err("{}", .{err}),
        else =>
            logger.info("Unexpected event type {}", .{@tagName(event_type)})
    }
    return c.UPNP_E_SUCCESS;
}

fn handleAction(self: *Device, action: *c.UpnpActionRequest) !void {
    const service_id_str = upnpStringToSlice(c.UpnpActionRequest_get_ServiceID(action));
    const service_id = try std.fmt.parseInt(usize, service_id_str, 10);
    if (service_id >= self.services.items.len) {
        return Error;
    }
    try self.services.items[service_id].handleAction(action);
}

fn upnpStringToSlice(str: ?*const c.UpnpString) []const u8 {
    var slice: []const u8 = undefined;
    slice.ptr = c.UpnpString_get_String(str);
    slice.len = c.UpnpString_get_Length(str);
    return slice;
}

// fn cStringToSlice(str: [*]const u8) []const u8 {
//     var slice: []const u8 = undefined;
//     slice.ptr = str;
//     slice.len = 0;
//     while (str[slice.len] != 0) : (slice.len += 1) {}
//     return slice;
// }

const DeviceSchema = struct {
    const Service = struct {
        serviceType: []const u8,
        serviceId: []const u8,
        SCPDURL: []const u8,
        controlURL: []const u8,
        eventSubURL: []const u8,
    };

    root: struct {
        __attributes__: struct {
            xmlns: []const u8 = "urn:schemas-upnp-org:device-1-0",
        },
        specVersion: struct {
            major: []const u8 = "1",
            minor: []const u8 = "0",
        },
        device: struct {
            deviceType: []const u8,
            friendlyName: []const u8,
            UDN: []const u8,
            iconList: ?struct {
                icon: []struct {
                    mimetype: []const u8,
                    width: []const u8,
                    height: []const u8,
                    depth: []const u8,
                    url: []const u8,
                },
            },
            serviceList: struct {
                service: []Service
            },
        },
    },
};
