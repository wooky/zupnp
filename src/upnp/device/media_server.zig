const std = @import("std");
const Allocator = std.mem.Allocator;
const zupnp = @import("../../lib.zig");
const ActionRequest = zupnp.upnp.device.ActionRequest;
const ActionResult = zupnp.upnp.device.ActionResult;
const DeviceServiceDefinition = zupnp.upnp.definition.DeviceServiceDefinition;

const MediaServer = @This();
const ms_logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer");

pub const device_type = "urn:schemas-upnp-org:device:MediaServer:1";

content_directory: ContentDirectory,
connection_manager: ConnectionManager,

pub fn prepare(self: *MediaServer, allocator: Allocator, _: void, service_list: *std.ArrayList(DeviceServiceDefinition)) !void {
    self.content_directory = ContentDirectory.init(allocator);
    self.connection_manager = ConnectionManager.init();

    try service_list.append(ContentDirectory.service_definition);
    try service_list.append(ConnectionManager.service_definition);
}

pub fn deinit(self: *MediaServer) void {
    self.content_directory.deinit();
}

pub usingnamespace zupnp.upnp.device.AbstractDevice(MediaServer, ms_logger, .{
    "content_directory",
    "connection_manager",
});

pub const ContentDirectory = struct {
    pub const service_definition = DeviceServiceDefinition {
        .service_type = "urn:schemas-upnp-org:service:ContentDirectory:1",
        .service_id = "urn:upnp-org:serviceId:ContentDirectory",
        .scpd_xml = @embedFile("../definition/content_directory.xml"),
    };

    const cd_logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer.ContentDirectory");
    const cd = zupnp.upnp.definition.content_directory;

    pub usingnamespace zupnp.upnp.device.AbstractService(ContentDirectory, cd_logger, .{
        .{ cd.GetSearchCapabilitiesOutput, getSearchCapabilities },
        .{ cd.GetSortCapabilitiesOutput, getSortCapabilities },
        .{ cd.GetSystemUpdateIdOutput, getSystemUpdateID },
        .{ cd.BrowseOutput, browse },
    });

    pub const Contents = struct {
        containers: std.ArrayList(cd.Container),
        items: std.ArrayList(cd.Item),
    };

    state: cd.ContentDirectoryState,
    containers: std.ArrayList(cd.Container),
    items: std.ArrayList(cd.Item),

    pub fn init(allocator: Allocator) ContentDirectory {
        return .{
            .state = .{
                .SystemUpdateID = "0",
            },
            .containers = std.ArrayList(cd.Container).init(allocator),
            .items = std.ArrayList(cd.Item).init(allocator),
        };
    }

    pub fn deinit(self: *ContentDirectory) void {
        self.containers.deinit();
        self.items.deinit();
    }

    fn getSearchCapabilities(_: *ContentDirectory, _: ActionRequest) !ActionResult {
        return ActionResult.createResult(service_definition.service_type, cd.GetSearchCapabilitiesOutput {
            .SearchCaps = "",
        });
    }

    fn getSortCapabilities(_: *ContentDirectory, _: ActionRequest) !ActionResult {
        return ActionResult.createResult(service_definition.service_type, cd.GetSortCapabilitiesOutput {
            .SortCaps = "",
        });
    }

    fn getSystemUpdateID(self: *ContentDirectory, _: ActionRequest) !ActionResult {
        return ActionResult.createResult(service_definition.service_type, cd.GetSystemUpdateIdOutput {
            .Id = self.state.SystemUpdateID,
        });
    }

    fn browse(self: *ContentDirectory, request: ActionRequest) !ActionResult {
        var str = try request.getActionRequest().toString();
        defer str.deinit();
        var browse_input = zupnp.xml.decode(
            request.allocator,
            zupnp.upnp.definition.content_directory.BrowseInput,
            request.getActionRequest()
        ) catch |err| {
            cd_logger.warn("Failed to parse browse request: {s}", .{err});
            return ActionResult.createError(zupnp.upnp.definition.ActionError.InvalidArgs.toErrorCode());
        };
        defer browse_input.deinit();
        const objectId = browse_input.result.@"u:Browse".ObjectID;

        var containers = std.ArrayList(cd.Container).init(request.allocator);
        defer containers.deinit();
        for (self.containers.items) |c| {
            if (std.mem.eql(u8, objectId, c.__attributes__.parentID)) {
                try containers.append(c);
            }
        }

        var items = std.ArrayList(cd.Item).init(request.allocator);
        defer items.deinit();
        for (self.items.items) |i| {
            if (std.mem.eql(u8, objectId, i.__attributes__.parentID)) {
                try items.append(i);
            }
        }

        const count = containers.items.len + items.items.len;
        var count_buf: [8]u8 = undefined;
        var count_str = try std.fmt.bufPrintZ(&count_buf, "{d}", .{count});
        var didl = try zupnp.xml.encode(request.allocator, cd.DIDLLite {
            .@"DIDL-Lite" = .{
                .container = containers.items,
                .item = items.items,
            }
        });
        defer didl.deinit();
        var didl_str = try didl.toString();
        defer didl_str.deinit();
        return ActionResult.createResult(service_definition.service_type, cd.BrowseOutput {
            .Result = didl_str.string,
            .NumberReturned = count_str,
            .TotalMatches = count_str,
            .UpdateID = "0",
        });
    }
};

pub const ConnectionManager = struct {
    pub const service_definition = DeviceServiceDefinition {
        .service_type = "urn:schemas-upnp-org:service:ConnectionManager:1",
        .service_id = "urn:upnp-org:serviceId:ConnectionManager",
        .scpd_xml = @embedFile("../definition/connection_manager.xml"),
    };

    const cm_logger = std.log.scoped(.@"zupnp.upnp.device.MediaServer.ConnectionManager");
    const cm = zupnp.upnp.definition.connection_manager;

    pub usingnamespace zupnp.upnp.device.AbstractService(ConnectionManager, cm_logger, .{
        .{ cm.GetProtocolInfoOutput, getProtocolInfo },
        .{ cm.GetCurrentConnectionIdsOutput, getCurrentConnectionIDs },
        .{ cm.GetCurrentConnectionInfoOutput, getCurrentConnectionInfo },
    });

    state: cm.ConnectionManagerState,

    pub fn init() ConnectionManager {
        return .{
            .state = .{
                .SourceProtocolInfo = "",
                .SinkProtocolInfo = "",
                .CurrentConnectionIDs = "0",
            },
        };
    }

    fn getProtocolInfo(self: *ConnectionManager, _: ActionRequest) !ActionResult {
        return ActionResult.createResult(service_definition.service_type, cm.GetProtocolInfoOutput {
            .Source = self.state.SourceProtocolInfo,
            .Sink = self.state.SinkProtocolInfo,
        });
    }

    fn getCurrentConnectionIDs(self: *ConnectionManager, _: ActionRequest) !ActionResult {
        return ActionResult.createResult(service_definition.service_type, cm.GetCurrentConnectionIdsOutput {
            .ConnectionIDs = self.state.CurrentConnectionIDs,
        });
    }

    fn getCurrentConnectionInfo(_: *ConnectionManager, _: ActionRequest) !ActionResult {
        return ActionResult.createResult(service_definition.service_type, cm.GetCurrentConnectionInfoOutput {
            .RcsID = "0",
            .AVTransportID = "0",
            .ProtocolInfo = "",
            .PeerConnectionManager = "",
            .PeerConnectionID = "-1",
            .Direction = "Input",
            .Status = "Unknown",
        });
    }
};
