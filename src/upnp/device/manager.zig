const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const c = @import("../../c.zig");
const zupnp = @import("../../lib.zig");

const Manager = @This();
const logger = std.log.scoped(.@"zupnp.upnp.device.Manager");

const RegisteredDevice = struct {
    const DeinitFn = fn(*c_void)void;
    const HandleActionFn = fn(*c_void, zupnp.upnp.device.ActionRequest) zupnp.upnp.device.ActionResult;

    instance: *c_void,
    deinitFn: ?DeinitFn,
    handleActionFn: HandleActionFn,
};
const DeviceMap = std.StringHashMap(RegisteredDevice);

arena: ArenaAllocator,
devices: DeviceMap,
scpd_endpoint: ?*ScpdEndpoint = null,

pub fn init(allocator: *Allocator) Manager {
    return .{
        .arena = ArenaAllocator.init(allocator),
        .devices = DeviceMap.init(allocator),
    };
}

pub fn deinit(self: *Manager) void {
    var devices_iter = self.devices.valueIterator();
    while (devices_iter.next) |dev| {
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
    device_parameters: zupnp.upnp.definition.UserDefinedDeviceParameters,
    config: anytype,
) !*T {
    if (self.scpd_endpoint == null) {
        // TODO this is stupidly hacky
        // and yeah it has to be a pointer, otherwise it'll copy the server object
        var server = &@fieldParentPtr(zupnp.ZUPnP, "device_manager", self).server;
        self.scpd_endpoint = try server.createEndpoint(ScpdEndpoint, .{ .allocator = &self.arena.allocator }, ScpdEndpoint.base_url);
    }

    var instance = try self.arena.allocator.create(T);
    errdefer self.arena.allocator.destroy(instance);

    var arena = ArenaAllocator.init(&self.arena.allocator);
    defer arena.deinit();

    var service_definitions = std.ArrayList(zupnp.upnp.definition.DeviceServiceDefinition).init(&arena.allocator);
    try instance.prepare(&self.arena.allocator, config, &service_definitions);
    const udn = "udn:TODO";
    const service_list = try arena.allocator.alloc(zupnp.upnp.definition.ServiceDefinition, service_definitions.items.len);
    for (service_definitions.items) |service_definition, i| {
        const scpd_url = try self.scpd_endpoint.?.addFile(udn, service_definition.service_id, service_definition.scpd_xml);
        service_list[i] = .{
            .service = .{
                .serviceType = service_definition.service_type,
                .serviceId = service_definition.service_id,
                .SCPDURL = scpd_url,
                .controlURL = try std.fmt.allocPrint(&arena.allocator, "/control/{s}/{s}", .{udn, service_definition.service_id}),
                .eventSubURL = try std.fmt.allocPrint(&arena.allocator, "/event/{s}/{s}", .{udn, service_definition.service_id}),
            }
        };
    }

    const device = zupnp.upnp.definition.Device {
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
    const device_document = try zupnp.xml.encode(&arena.allocator, device);
    defer device_document.deinit();
    var device_str = try device_document.toString();
    defer device_str.deinit();

    try self.devices.putNoClobber(udn, .{
        .instance = @ptrCast(*c_void, instance),
        .deinitFn = c.mutateCallback(T, "deinit", RegisteredDevice.DeinitFn),
        .handleActionFn = c.mutateCallback(T, "handleAction", RegisteredDevice.HandleActionFn).?,
    });
    errdefer { _ = self.devices.remove(udn); }

    var handle: c.UpnpDevice_Handle = undefined; // TODO store this somewhere
    if (c.is_error(c.UpnpRegisterRootDevice2(
        .UPNPREG_BUF_DESC,
        device_str.string.ptr,
        device_str.string.len,
        1, // TODO wtf does this do?
        onEvent,
        @ptrCast(*const c_void, self.devices.getPtr(udn).?),
        &handle)))
    |err| {
        logger.err("Failed to register device: {s}", .{err});
        return zupnp.Error;
    }

    return instance;
}

fn onEvent(event_type: c.Upnp_EventType, event: ?*const c_void, cookie: ?*c_void) callconv(.C) c_int {
    var device = c.mutate(*RegisteredDevice, cookie);
    switch (event_type) {
        .UPNP_CONTROL_ACTION_REQUEST => onAction(device, event),
        else => logger.debug("Unhandled event type {s}", .{@tagName(event_type)})
    }
    return 0;
}

fn onAction(device: *RegisteredDevice, event: ?*const c_void) void {
    var action_request = c.mutate(*c.UpnpActionRequest, event);
    const action = zupnp.upnp.device.ActionRequest { .handle = action_request };
    const udn = action.getDeviceUdn();
    var result: zupnp.upnp.device.ActionResult = device.handleActionFn(device.instance, action);
    
    if (result.action_result) |action_result| {
        _ = c.UpnpActionRequest_set_ActionResult(action_request, action_result.handle);
    }
    _ = c.UpnpActionRequest_set_ErrCode(action_request, result.err_code);
}

const ScpdEndpoint = struct {
    const base_url = "/scpd";

    allocator: *Allocator,
    xml_files: std.StringHashMap([]const u8),

    pub fn prepare(self: *ScpdEndpoint, config: struct { allocator: *Allocator }) !void {
        self.allocator = config.allocator;
        self.xml_files = std.StringHashMap([]const u8).init(config.allocator);
    }

    pub fn addFile(
        self: *ScpdEndpoint,
        udn: []const u8,
        service_id: []const u8,
        contents: []const u8
    ) ![]const u8 {
        const url = try std.fmt.allocPrint(self.allocator, "{s}/{s}/{s}", .{base_url, udn, service_id});
        try self.xml_files.put(url, contents);
        return url;
    }

    pub fn get(self: *ScpdEndpoint, request: *const zupnp.web.ServerGetRequest) zupnp.web.ServerResponse {
        return if (self.xml_files.get(request.filename)) |contents|
            .{ .Contents = .{ .content_type = "text/xml", .contents = contents } }
        else
            .{ .NotFound = {} }
        ;
    }
};
