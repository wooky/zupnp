const std = @import("std");
const c = @import("../../c.zig");
const zupnp = @import("../../lib.zig");
const xml = @import("xml");

const logger = std.log.scoped(.@"zupnp.upnp.device.event_subscription");

pub const EventSubscriptionRequest = struct {
    handle: *const c.UpnpSubscriptionRequest,

    pub fn getDeviceUdn(self: *const EventSubscriptionRequest) [:0]const u8 {
        return c.UpnpSubscriptionRequest_get_UDN_cstr(self.handle)[0..c.UpnpSubscriptionRequest_get_UDN_Length(self.handle):0];
    }

    pub fn getServiceId(self: *const EventSubscriptionRequest) [:0]const u8 {
        return c.UpnpSubscriptionRequest_get_ServiceId_cstr(self.handle)[0..c.UpnpSubscriptionRequest_get_ServiceId_Length(self.handle):0];
    }

    pub fn getSid(self: *const EventSubscriptionRequest) [:0]const u8 {
        return c.UpnpSubscriptionRequest_get_SID_cstr(self.handle)[0..c.UpnpSubscriptionRequest_get_SID_Length(self.handle):0];
    }
};

pub const EventSubscriptionResult = struct {
    property_set: ?xml.Document,

    pub fn createResult(arguments: anytype) !EventSubscriptionResult {
        var doc: ?*c.IXML_Document = null;
        inline for (@typeInfo(@TypeOf(arguments)).Struct.fields) |field| {
            const key = field.name ++ "\x00";
            const value: [:0]const u8 = @field(arguments, field.name);
            if (c.is_error(c.UpnpAddToPropertySet(&doc, key, value))) |err| {
                logger.err("Cannot create response: {s}", .{err});
                return zupnp.Error;
            }
        }
        return EventSubscriptionResult {
            .property_set = xml.Document.init(c.mutate(*xml.c.IXML_Document, doc.?)),
        };
    }

    pub fn createError() EventSubscriptionResult {
        return .{
            .property_set = null,
        };
    }

    pub fn deinit(self: *EventSubscriptionResult) void {
        if (self.property_set) |*property_set| {
            property_set.deinit();
        }
    }
};
