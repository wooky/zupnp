const std = @import("std");
const zupnp = @import("../../lib.zig");

const ActionError = zupnp.upnp.definition.ActionError;
const ActionRequest = zupnp.upnp.device.ActionRequest;
const ActionResult = zupnp.upnp.device.ActionResult;
const EventSubscriptionRequest = zupnp.upnp.device.EventSubscriptionRequest;
const EventSubscriptionResult = zupnp.upnp.device.EventSubscriptionResult;

pub fn AbstractDevice(comptime DeviceType: type, logger: anytype, services: anytype) type {
    return struct {
        pub fn handleAction(self: *DeviceType, request: ActionRequest) ActionResult {
            const service_id = request.getServiceId();
            logger.debug(
                "Received action request for service ID {s} action {s} from {s}",
                .{service_id, request.getActionName(), request.getClientAddress().toString()}
            );
            inline for (services) |service_str| {
                comptime const ServiceClass = @TypeOf(@field(self, service_str));
                if (std.mem.eql(u8, service_id, ServiceClass.service_definition.service_id)) {
                    return @field(self, service_str).handleAction(request);
                }
            }

            logger.debug("Unhandled action service ID {s}", .{service_id});
            return ActionResult.createError(ActionError.UnhandledActionServiceId.toErrorCode());
        }

        pub fn handleEventSubscription(self: *DeviceType, request: EventSubscriptionRequest) EventSubscriptionResult {
            const service_id = request.getServiceId();
            logger.debug("Received event subscription request for service ID {s} SID {s}", .{service_id, request.getSid()});
            inline for (services) |service_str| {
                comptime const ServiceClass = @TypeOf(@field(self, service_str));
                if (std.mem.eql(u8, service_id, ServiceClass.service_definition.service_id)) {
                    return @field(self, service_str).handleEventSubscription(request);
                }
            }

            logger.debug("Unhandled event subscription service ID {s}", .{service_id});
            return EventSubscriptionResult.createError();
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
                        logger.err("Failed to create action request: {s}", .{@errorName(err)});
                        break :blk ActionResult.createError(ActionError.ActionFailed.toErrorCode());
                    };
                }
            }
            logger.debug("Unhandled action {s}", .{action_name});
            return ActionResult.createError(ActionError.InvalidAction.toErrorCode());
        }

        pub fn handleEventSubscription(self: *ServiceType, request: EventSubscriptionRequest) EventSubscriptionResult {
            return EventSubscriptionResult.createResult(self.state) catch |err| blk: {
                logger.err("Failed to create event subscription request: {s}", .{@errorName(err)});
                break :blk EventSubscriptionResult.createError();
            };
        }
    };
}
