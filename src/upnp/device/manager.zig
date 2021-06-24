const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const c = @import("../../c.zig");
const zupnp = @import("../../lib.zig");

const Manager = @This();
const logger = std.log.scoped(.@"zupnp.upnp.device.Manager");

const RegisteredDevice = struct {
    const DeinitFn = fn(*c_void)void;

    instance: *c_void,
    deinitFn: ?DeinitFn,
};

arena: ArenaAllocator,
devices: std.ArrayList(RegisteredDevice),

pub fn init(allocator: *Allocator) Manager {
    return .{
        .arena = ArenaAllocator.init(allocator),
        .devices = std.ArrayList(RegisteredDevice).init(allocator),
    };
}

pub fn deinit(self: *Manager) void {
    for (self.devices.items) |dev| {
        if (dev.deinitFn) |deinitFn| {
            deinitFn(dev.instance);
        }
    }
    self.devices.deinit();
    self.arena.deinit();
}

pub fn createDevice(
    self: *Manager,
    comptime T: type,
    device_parameters: zupnp.upnp.UserDefinedDeviceParameters,
    config: anytype,
) !*T {
    // TODO this is stupidly hacky
    const server = @fieldParentPtr(zupnp.ZUPnP, "device_manager", self).server;
    if (server.base_url == null) {
        logger.err("Server must be started before creating devices", .{});
        return zupnp.Error;
    }

    var instance = try self.arena.allocator.create(T);
    errdefer self.arena.allocator.destroy(instance);

    const udn = "udn:TODO";
    const service_list = try instance.prepare(&self.arena.allocator, udn, config);
    defer self.arena.allocator.free(service_list);

    const device = zupnp.upnp.Device {
        .root = .{
            .device = .{
                .deviceType = T.device_type,
                .UDN = udn,
                .friendlyName = device_parameters.friendlyName,
                .manufacturer = device_parameters.manufacturer,
                .manufacturerURL = device_parameters.manufacturerURL,
                .modelDescription = device_parameters.modelDescription,
                .modelName = device_parameters.modelName,
                .modelNumber = device_parameters.modelNumber,
                .modelURL = device_parameters.modelURL,
                .serialNumber = device_parameters.serialNumber,
                .UPC = device_parameters.UPC,
                .iconList = device_parameters.iconList,
                .serviceList = service_list,
            }
        }
    };
    const device_document = try zupnp.xml.encode(&self.arena.allocator, device);
    defer device_document.deinit();
    var device_str = try device_document.toString();
    defer device_str.deinit();

    try self.devices.append(.{
        .instance = @ptrCast(*c_void, instance),
        .deinitFn = c.mutateCallback(T, "deinit", RegisteredDevice.DeinitFn),
    });
    errdefer { _ = self.devices.pop(); }

    var handle: c.UpnpDevice_Handle = undefined; // TODO store this somewhere
    if (c.is_error(c.UpnpRegisterRootDevice2(
        .UPNPREG_BUF_DESC,
        device_str.string.ptr,
        device_str.string.len,
        1, // TODO wtf does this do?
        onEvent,
        @ptrCast(*const c_void, &self.devices.items[self.devices.items.len - 1]),
        &handle)))
    |err| {
        logger.err("Failed to register device: {s}", .{err});
        return zupnp.Error;
    }

    return instance;
}

fn onEvent(event_type: c.Upnp_EventType, event: ?*const c_void, cookie: ?*c_void) callconv(.C) c_int {
    // TODO
    return 0;
}
