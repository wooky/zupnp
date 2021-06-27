const std = @import("std");
const Allocator = std.mem.Allocator;
const zupnp = @import("../../lib.zig");
const ActionRequest = zupnp.upnp.device.ActionRequest;
const ActionResult = zupnp.upnp.device.ActionResult;
const DeviceServiceDefinition = zupnp.upnp.definition.DeviceServiceDefinition;

const MediaServer = @This();
const logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer");

pub const device_type = "urn:schemas-upnp-org:device:MediaServer:1";

bogus: bool, // TODO remove me
content_directory: ContentDirectory,

pub fn prepare(self: *MediaServer, allocator: *std.mem.Allocator, config: void, service_list: *std.ArrayList(DeviceServiceDefinition)) !void {
    self.content_directory = ContentDirectory.init(allocator);

    try service_list.append(ContentDirectory.service_definition);
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
    // const ContainerList = std.ArrayList(Container);
    const ItemList = std.ArrayList(Item);

    allocator: *Allocator,
    // containers: ContainerList,
    items: ItemList,

    pub fn init(allocator: *Allocator) ContentDirectory {
        return .{
            .allocator = allocator,
            .items = ItemList.init(allocator),
        };
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
        var count_buf: [8]u8 = undefined;
        var count = try std.fmt.bufPrintZ(&count_buf, "{d}", .{self.items.items.len});
        var didl = try zupnp.xml.encode(self.allocator, DIDLLite {
            .@"DIDL-Lite" = .{
                .item = self.items.items,
            }
        });
        defer didl.deinit();
        var didl_str = try didl.toString();
        defer didl_str.deinit();
        return ActionResult.createResult(Browse, service_definition.service_type, BrowseOutput {
            .Result = didl_str.string,
            .NumberReturned = count,
            .TotalMatches = count,
            .UpdateID = "0",
        });
    }
};
