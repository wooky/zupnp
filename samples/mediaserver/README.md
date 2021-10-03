# MediaServer (DLNA server)
This program serves contents stored locally and on remote server to DLNA compatible receivers.

Build and run the program:
```zig
zig build run
```

Open up VLC or, even better, a smart TV, find the server called "ZUPnP Test", and open up some contents.

Notes:
 * All remote content is hosted on http://www.sample-videos.com/. Its domain name has been converted to an IP address because most TVs do not support domain names.
 * Your TV may not play, or even display, all contents. That's simply due to the fact that your TV may not support that content type.
