const std = @import("std");
const zupnp = @import("../../lib.zig");

const ActionRequest = zupnp.upnp.device.ActionRequest;
const ActionResult = zupnp.upnp.device.ActionResult;

pub fn AbstractDevice(comptime DeviceType: type, logger: anytype, services: anytype) type {
    return struct {
        pub fn handleAction(self: *DeviceType, request: ActionRequest) ActionResult {
            const service_id = request.getServiceId();
            logger.debug("Received request for service ID {s} action {s}", .{service_id, request.getActionName()});
            inline for (services) |service_str| {
                comptime const ServiceClass = @TypeOf(@field(self, service_str));
                if (std.mem.eql(u8, service_id, ServiceClass.service_definition.service_id)) {
                    return @field(self, service_str).handleAction(request);
                }
            }

            logger.debug("Unhandled service ID {s}", .{service_id});
            return ActionResult.createError(2);
        }
    };
}

pub fn AbstractService(comptime ServiceType: type, logger: anytype, actions_to_functions: anytype) type {
    return struct {
        pub fn handleAction(self: *ServiceType, request: ActionRequest) ActionResult {
            const action_name = request.getActionName();
            inline for (actions_to_functions) |action_to_function| {
                comptime const target_action_name = action_to_function.@"0".action_name;
                if (std.mem.eql(u8, action_name, target_action_name)) {
                    return action_to_function.@"1"(self, request) catch |err| blk: {
                        logger.err("Failed to create request: {s}", .{@errorName(err)});
                        break :blk ActionResult.createError(501); // TODO place in some common error code struct - ActionFailed
                    };
                }
            }
            logger.debug("Unhandled action {s}", .{action_name});
            return ActionResult.createError(401); // TODO place in some common error code struct - InvalidAction
        }
    };
}
