// http://www.upnp.org/schemas/service-1-0.xsd

pub const ActionError = enum(c_int) {
    UnhandledActionServiceId = 2, // idk where this one came from
    InvalidAction = 401,
    InvalidArgs = 402,
    InvalidVar = 404,
    ActionFailed = 501,
    ArgumentValueInvalid = 600,
    ArgumentValueOutOfRange = 601,
    OptionalActionNotImplemented = 602,
    OutOfMemory = 603,
    HumanInterventionRequired = 604,
    StringArgumentTooLong = 605,

    pub fn toErrorCode(self: ActionError) c_int {
        return @enumToInt(self);
    }
};
