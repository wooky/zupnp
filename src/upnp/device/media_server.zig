const std = @import("std");
const zupnp = @import("../../lib.zig");
const ActionRequest = zupnp.upnp.device.ActionRequest;
const ActionResult = zupnp.upnp.device.ActionResult;
const DeviceServiceDefinition = zupnp.upnp.definition.DeviceServiceDefinition;

const MediaServer = @This();
const logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer");

pub const device_type = "urn:schemas-upnp-org:device:MediaServer:1";

bogus: bool, // TODO remove me
content_directory: ContentDirectory,

pub fn prepare(self: *MediaServer, allocator: *std.mem.Allocator, config: void) ![]DeviceServiceDefinition {
    self.content_directory = ContentDirectory.init();

    var service_list = try allocator.alloc(DeviceServiceDefinition, 1);
    service_list[0] = ContentDirectory.service_definition;
    return service_list;
}

pub fn handleAction(self: *MediaServer, request: ActionRequest) ActionResult {
    const service_id = request.getServiceId();
    if (std.mem.eql(u8, service_id, ContentDirectory.service_definition.service_id)) {
        return self.content_directory.handleAction(request);
    }

    logger.debug("Unhandled service ID {s}", .{service_id});
    return ActionResult.createError(2);
}

const ContentDirectory = struct {
    pub const service_definition = DeviceServiceDefinition {
        .service_type = "urn:schemas-upnp-org:service:ContentDirectory:1",
        .service_id = "urn:upnp-org:serviceId:ContentDirectory",
        .scpd_xml = @embedFile("../definition/content_directory.xml"),
    };

    const GetSearchCapabilities = "GetSearchCapabilities";
    const GetSortCapabilities = "GetSortCapabilities";
    const GetSystemUpdateID = "GetSystemUpdateID";
    const Browse = "Browse";
    const action_functions = std.ComptimeStringMap(zupnp.upnp.device.ActionFunction(ContentDirectory), .{
        .{ GetSearchCapabilities, getSearchCapabilities },
        .{ GetSortCapabilities, getSortCapabilities },
        .{ GetSystemUpdateID, getSystemUpdateID },
        .{ Browse, browse },
    });
    const logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer.ContentDirectory");

    usingnamespace zupnp.upnp.definition.content_directory;

    pub fn init() ContentDirectory {
        return .{};
    }

    pub fn handleAction(self: *ContentDirectory, request: ActionRequest) ActionResult {
        const action_name = request.getActionName();
        if (action_functions.get(action_name)) |actionFn| {
            return actionFn(self, request) catch |err| blk: {
                logger.err("Failed to create request: {s}", .{@errorName(err)});
                break :blk ActionResult.createError(Error.ActionFailed.toErrorCode());
            };
        }
        logger.debug("Unhandled action {s}", .{action_name});
        return ActionResult.createError(Error.InvalidAction.toErrorCode());
    }

    fn getSearchCapabilities(self: *ContentDirectory, request: ActionRequest) !ActionResult {
        return ActionResult.createResult(GetSearchCapabilities, service_definition.service_type, GetSearchCapabilitiesOutput {
            .SearchCaps = "",
        });
    }

    fn getSortCapabilities(self: *ContentDirectory, request: ActionRequest) !ActionResult {
        return ActionResult.createResult(GetSortCapabilities, service_definition.service_type, GetSortCapabilitiesOutput {
            .SortCaps = "",
        });
    }

    fn getSystemUpdateID(self: *ContentDirectory, request: ActionRequest) !ActionResult {
        return ActionResult.createResult(GetSystemUpdateID, service_definition.service_type, GetSystemUpdateIdOutput {
            .Id = "0",
        });
    }

    fn browse(self: *ContentDirectory, request: ActionRequest) !ActionResult {
        logger.info("Browse()", .{});
        return ActionResult.createError(Error.NoSuchObject.toErrorCode());
    }
};
