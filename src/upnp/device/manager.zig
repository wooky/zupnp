const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const c = @import("../../c.zig");
const zupnp = @import("../../lib.zig");
const xml = @import("xml");

const Manager = @This();
const logger = std.log.scoped(.@"zupnp.upnp.device.Manager");

const RegisteredDevice = struct {
    const DeinitFn = *const fn(*anyopaque)void;
    const HandleActionFn = *const fn(*anyopaque, zupnp.upnp.device.ActionRequest) zupnp.upnp.device.ActionResult;
    const HandleEventSubscriptionFn = *const fn(*anyopaque, zupnp.upnp.device.EventSubscriptionRequest) zupnp.upnp.device.EventSubscriptionResult;

    instance: *anyopaque,
    allocator: Allocator,
    deinitFn: ?DeinitFn,
    handleActionFn: HandleActionFn,
    handleEventSubscriptionFn: HandleEventSubscriptionFn,
    device_handle: c.UpnpDevice_Handle = undefined,

    fn deinit(self: *RegisteredDevice) void {
        if (self.deinitFn) |deinitFn| {
            deinitFn(self.instance);
        }
    }
};
const DeviceMap = std.StringHashMap(RegisteredDevice);

arena: ArenaAllocator,
devices: DeviceMap,
scpd_endpoint: ?*ScpdEndpoint = null,

pub fn init(allocator: Allocator) Manager {
    return .{
        .arena = ArenaAllocator.init(allocator),
        .devices = DeviceMap.init(allocator),
    };
}

pub fn deinit(self: *Manager) void {
    var devices_iter = self.devices.valueIterator();
    while (devices_iter.next) |dev| {
        dev.deinit();
        _ = c.UpnpUnRegisterRootDevice(dev.device_handle);
    }
    self.devices.deinit();
    self.arena.deinit();
}

pub fn createDevice(
    self: *Manager,
    comptime T: type,
    server: *zupnp.web.Server,
    device_parameters: zupnp.upnp.definition.UserDefinedDeviceParameters,
    config: anytype,
) !*T {
    if (self.scpd_endpoint == null) {
        // TODO this is stupidly hacky
        // and yeah it has to be a pointer, otherwise it'll copy the server object
        // FIXME this line crashes Zig 0.10 compiler! Therefore `server` must be accepted as a function parameter.
        // var server = &@fieldParentPtr(zupnp.ZUPnP, "device_manager", self).server;
        self.scpd_endpoint = try server.createEndpoint(ScpdEndpoint, .{ .allocator = self.arena.allocator() }, ScpdEndpoint.base_url);
    }

    var instance = try self.arena.allocator().create(T);
    errdefer self.arena.allocator().destroy(instance);

    var arena = ArenaAllocator.init(self.arena.allocator());
    defer arena.deinit();

    var service_definitions = std.ArrayList(zupnp.upnp.definition.DeviceServiceDefinition).init(arena.allocator());
    try instance.prepare(self.arena.allocator(), config, &service_definitions);
    const service_list = try arena.allocator().alloc(zupnp.upnp.definition.ServiceDefinition, service_definitions.items.len);
    for (service_definitions.items) |service_definition, i| {
        const scpd_url = try self.scpd_endpoint.?.addFile(device_parameters.UDN, service_definition.service_id, service_definition.scpd_xml);
        service_list[i] = .{
            .serviceType = service_definition.service_type,
            .serviceId = service_definition.service_id,
            .SCPDURL = scpd_url,
            .controlURL = try std.fmt.allocPrint(arena.allocator(), "/control/{s}/{s}", .{device_parameters.UDN, service_definition.service_id}),
            .eventSubURL = try std.fmt.allocPrint(arena.allocator(), "/event/{s}/{s}", .{device_parameters.UDN, service_definition.service_id}),
        };
    }

    const device = zupnp.upnp.definition.Device {
        .root = .{
            .device = .{
                .deviceType = T.device_type,
                .UDN = device_parameters.UDN,
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
                .serviceList = .{
                    .service = service_list,
                },
            }
        }
    };
    const device_document = try xml.encode(arena.allocator(), device);
    defer device_document.deinit();
    var device_str = try device_document.toString();
    defer device_str.deinit();

    // TODO Put all of this much earlier than here
    if (self.devices.contains(device_parameters.UDN)) {
        logger.err("Device {s} is already registered", .{device_parameters.UDN});
        return zupnp.Error;
    }
    const entry = try self.devices.getOrPutValue(device_parameters.UDN, .{
        .instance = @ptrCast(*anyopaque, instance),
        .allocator = self.arena.allocator(),
        .deinitFn = c.mutateCallback(T, "deinit", RegisteredDevice.DeinitFn),
        .handleActionFn = c.mutateCallback(T, "handleAction", RegisteredDevice.HandleActionFn).?,
        .handleEventSubscriptionFn = c.mutateCallback(T, "handleEventSubscription", RegisteredDevice.HandleEventSubscriptionFn).?,
    });
    errdefer {
        entry.value_ptr.deinit();
        _ = self.devices.remove(device_parameters.UDN);
    }

    if (c.is_error(c.UpnpRegisterRootDevice2(
        c.UPNPREG_BUF_DESC,
        device_str.string.ptr,
        device_str.string.len,
        1, // TODO wtf does this do?
        onEvent,
        @ptrCast(*const anyopaque, entry.value_ptr),
        &entry.value_ptr.device_handle
    ))) |err| {
        logger.err("Failed to register device: {s}", .{err});
        return zupnp.Error;
    }

    logger.info("Registered device {any} with UDN {s}", .{T, device_parameters.UDN});
    return instance;
}

fn onEvent(event_type: c.Upnp_EventType, event: ?*const anyopaque, cookie: ?*anyopaque) callconv(.C) c_int {
    var device = c.mutate(*RegisteredDevice, cookie);
    switch (event_type) {
        c.UPNP_CONTROL_ACTION_REQUEST => onAction(device, event),
        c.UPNP_EVENT_SUBSCRIPTION_REQUEST => onEventSubscribe(device, event),
        else => logger.info("Unhandled event type {}", .{event_type})
    }
    return 0;
}

fn onAction(device: *RegisteredDevice, event: ?*const anyopaque) void {
    var arena = ArenaAllocator.init(device.allocator);
    defer arena.deinit();
    var action_request = c.mutate(*c.UpnpActionRequest, event);
    const action = zupnp.upnp.device.ActionRequest {
        .allocator = arena.allocator(),
        .handle = action_request,
    };
    var result: zupnp.upnp.device.ActionResult = device.handleActionFn(device.instance, action);
    
    if (result.action_result) |action_result| {
        _ = c.UpnpActionRequest_set_ActionResult(action_request, c.mutate(*c.IXML_Document, action_result.handle));
    }
    _ = c.UpnpActionRequest_set_ErrCode(action_request, result.err_code);
}

fn onEventSubscribe(device: *RegisteredDevice, event: ?*const anyopaque) void {
    var event_subscription_request = c.mutate(*c.UpnpSubscriptionRequest, event);
    var event_subscription = zupnp.upnp.device.EventSubscriptionRequest {
        .handle = event_subscription_request,
    };
    var result: zupnp.upnp.device.EventSubscriptionResult = device.handleEventSubscriptionFn(device.instance, event_subscription);
    defer result.deinit();
    
    if (result.property_set) |property_set| {
        if (c.is_error(c.UpnpAcceptSubscriptionExt(
            device.device_handle,
            event_subscription.getDeviceUdn().ptr,
            event_subscription.getServiceId().ptr,
            c.mutate(*c.IXML_Document, property_set.handle),
            event_subscription.getSid().ptr
        ))) |err| {
            logger.warn("Failed to accept event subscription: {s}", .{err});
        }
    }
}

const ScpdEndpoint = struct {
    const base_url = "/scpd";

    allocator: Allocator,
    xml_files: std.StringHashMap([]const u8),

    pub fn prepare(self: *ScpdEndpoint, config: struct { allocator: Allocator }) !void {
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
            zupnp.web.ServerResponse.contents(.{ .content_type = "text/xml", .contents = contents })
        else
            zupnp.web.ServerResponse.notFound()
        ;
    }
};
