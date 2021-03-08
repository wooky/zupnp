//! XML library.
//! You are encouraged to use the `Parser` and `Writer` to convert XML documents to and from structs, respectively.
//! You can also manually construct an XML document, starting with `Document`.

pub usingnamespace @import("xml.zig");
pub const Parser = @import("parser.zig");
pub const Writer = @import("writer.zig");
