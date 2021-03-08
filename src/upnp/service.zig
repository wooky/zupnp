const c = @import("../c.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const zupnp = @import("../main.zig");

const Service = @This();
const ActionMap = std.StringHashMap([]Argument);

allocator: *Allocator,
service_type: []const u8,
actions: ActionMap,

pub fn init(allocator: *Allocator, service_type: []const u8) Service {
    return .{
        .allocator = allocator,
        .service_type = service_type,
        .actions = ActionMap.init(allocator),
    };
}

pub fn deinit(self: *Service) void {
    self.actions.deinit();
}

pub fn addAction(self: *Service, name: []const u8, arguments: []Argument) !void {
    try self.actions.putNoClobber(name, arguments);
}

pub fn createSchema(self: *Service) !zupnp.xml.DOMString {
    var writer = zupnp.xml.Writer.init(self.allocator);
    defer writer.deinit();

    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var ss_actions = std.ArrayList(ServiceSchema.Action).init(&arena.allocator);
    var ss_sv = std.ArrayList(ServiceSchema.SV).init(&arena.allocator);
    var state_variables_encountered = std.StringHashMap(void).init(&arena.allocator);

    var iter = self.actions.iterator();
    while (iter.next()) |kv| {
        var ss_args = std.ArrayList(ServiceSchema.Arg).init(&arena.allocator);
        for (kv.value) |arg| {
            try ss_args.append(.{
                .name = arg.name,
                .direction = arg.direction,
                .relatedStateVariable = arg.state_variable.name,
            });
            if (!state_variables_encountered.contains(arg.state_variable.name)) {
                try state_variables_encountered.putNoClobber(arg.state_variable.name, {});
                try ss_sv.append(.{
                    .name = arg.state_variable.name,
                    .dataType = "TODO",
                    .allowedValueList = null,   // TODO
                });
            }
        }
        try ss_actions.append(.{
            .name = kv.key,
            .argumentList = .{
                .argument = ss_args.items,
            },
        });
    }

    const schema = ServiceSchema {
        .scpd = .{
            .actionList = .{
                .action = ss_actions.items,
            },
            .serviceStateTable = .{
                .stateVariable = ss_sv.items,
            },
        },
    };
    var doc = try writer.writeStructToDocument(schema);
    defer doc.deinit();
    return try doc.toString();
}

pub fn handleAction(self: *Service, action: *c.UpnpActionRequest) !void {

}

pub const Request = struct {

};

pub const Response = struct {

};

pub const Direction = enum { in, out };

pub const StateVariable = struct {
    name: []const u8,
    // data_type: type,
};

pub const Argument = struct {
    name: []const u8,
    direction: Direction,
    state_variable: StateVariable,
};

const ServiceSchema = struct {
    const Arg = struct {
        name: []const u8,
        direction: Direction,
        relatedStateVariable: []const u8,
    };

    const Action = struct {
        name: []const u8,
        argumentList: struct {
            argument: []Arg,
        },
    };

    const SV = struct {
        __attributes__: struct {
            sendEvents: []const u8 = "no",
        } = .{},
        name: []const u8,
        dataType: []const u8,
        allowedValueList: ?struct {
            allowedValue: [][]const u8,
        },
    };

    scpd: struct {
        __attributes__: struct {
            xmlns: []const u8 = "urn:schemas-upnp-org:service-1-0",
        } = .{},
        specVersion: struct {
            major: []const u8 = "1",
            minor: []const u8 = "0",
        } = .{},
        actionList: struct {
            action: []Action,
        },
        serviceStateTable: struct {
            stateVariable: []SV,
        },
    },
};
