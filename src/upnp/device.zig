const c = @import("../c.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const zupnp = @import("../main.zig");

const Device = @This();
const ServiceMap = std.StringHashMap(zupnp.upnp.Service);
const logger = std.log.scoped(.Device);

pub const Error = error.UPnPError;

allocator: *Allocator,
device_type: []const u8,
friendly_name: []const u8,
writer: zupnp.xml.Writer,
services: ServiceMap,
udn: []const u8,
udn_url: []const u8,

handle: c.UpnpDevice_Handle = undefined,
started: bool = false,

pub fn init(
    allocator: *Allocator,
    upnp_server: zupnp.upnp.Server,
    device_type: []const u8,
    friendly_name: []const u8
) !Device {
    return Device {
        .allocator = allocator,
        .device_type = device_type,
        .friendly_name = friendly_name,
        .writer = zupnp.xml.Writer.init(allocator),
        .services = ServiceMap.init(allocator),
        .udn = "udn:TODO",
        .udn_url = try std.fmt.allocPrint(allocator, "{}/{}", .{upnp_server.base_url, "udn:TODO"}),
    };
}

pub fn deinit(self: *Device) void {
    self.started = false;
    _ = c.UpnpUnRegisterRootDevice(self.handle);
    self.writer.deinit();
    self.services.deinit();
    self.allocator.free(self.udn_url);
}

pub fn addService(self: *Device, service: *zupnp.upnp.Service) !void {
    std.debug.assert(!self.started);
    try self.services.putNoClobber(service.id, service);
}

pub fn start(self: *Device) !void {
    std.debug.assert(!self.started);
    const schema = try self.createSchema();
    {
        const err = c.UpnpRegisterRootDevice2(c.Upnp_DescType.UPNPREG_BUF_DESC, schema, schema.len, 1, onEvent, self, &self.handle);
        if (err != c.UPNP_E_SUCCESS) {
            logger.err("Cannot register device: {s}", .{c.UpnpGetErrorMessage(err)});
        }
    }
    
    if (c.UpnpSendAdvertisement(self.handle, 100) != c.UPNP_E_SUCCESS) return Error;
    logger.info("Started {}", .{self.friendly_name});
}

fn createSchema(self: *Device) ![:0]const u8 {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();

    var schema_services = std.ArrayList(DeviceSchema.Service).init(self.allocator);
    defer schema_services.deinit();
    var iter = self.services.iterator();
    while (iter.next()) |kv| {
        try schema_services.append(.{
            .serviceType = kv.value.type,
            .serviceId = kv.value.id,
            .SCPDURL = try std.fmt.allocPrint(self.allocator, "{}/{}/{}", .{self.udn_url, kv.value.id, "IDK"}),
            .controlURL = try std.fmt.allocPrint(self.allocator, "{}/{}/{}", .{self.udn_url, kv.value.id, "control"}),
            .eventSubURL = try std.fmt.allocPrint(self.allocator, "{}/{}/{}", .{self.udn_url, kv.value.id, "event"}),
        });
    }

    const schema = DeviceSchema {
        .root = .{
            .__attributes__ = .{},
            .specVersion = .{},
            .device = .{
                .deviceType = self.device_type,
                .friendlyName = self.friendly_name,
                .UDN = self.udn,
                .iconList = null,
                .serviceList = .{
                    .service = schema_services.items,
                },
            },
        },
    };
    return try self.writer.writeStructToDocumentString(schema);
}

fn onEvent(event_type: c.Upnp_EventType, event: ?*const c_void, cookie: ?*c_void) callconv(.C) c_int {
    var self = @ptrCast(*Device, @alignCast(8, cookie));
    var mut_event = @intToPtr(*c_void, @ptrToInt(event));
    switch (event_type) {
        c.Upnp_EventType.UPNP_CONTROL_ACTION_REQUEST =>
            self.handleAction(@ptrCast(*c.UpnpActionRequest, mut_event)) catch |err| logger.err("{}", err),
        else =>
            logger.info("Unexpected event type {}", .{@tagName(event_type)})
    }
    return c.UPNP_E_SUCCESS;
}

fn handleAction(self: *Device, action: *c.UpnpActionRequest) !void {
    const service_id = upnpStringToSlice(c.UpnpActionRequest_get_ServiceID(action));
    const entry = self.services.getEntry(service_id);
    if (entry) |e| {
        try e.value.handleAction(action);
    }
    else {
        logger.info("Unexpected service ID {}", .{service_id});
    }
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
