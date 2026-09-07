<div align="center">
<img src="icon.png" alt="icon" width="30%" height="auto" />

# Printemps

</div>

Very small music widget

## Preview
<img src="Preview.png" alt="Preview" width="60%" height="auto" />

## Supported firmwares

iOS 16 only, tested on 16.6.1.

Printemps draws its own player on the lock screen. The expanded player you get
by tapping the artwork is Control Center's, and is left stock.

iOS 16 turned the lock screen player into a live activity drawn in another
process: the cover sheet holds a `CSActivityItemContentView` whose content
arrives as a hosted scene layer, and there is not a single MediaControls view
left in SpringBoard to restyle. Printemps therefore builds its own player from
MediaRemote, puts it inside that activity item and sizes the card around it.
Only the activity in the `com.apple.MediaRemoteUI` group is touched, so other
live activities are left alone.

## What it does

- Artwork, title, artist, transport controls and a progress bar, in the space
  the stock widget took
- Long titles scroll instead of being cut off
- Drag or tap the progress bar to seek
- Hold the artwork to share `[title] - [artist] #nowplaying` with the artwork,
  once the device has authenticated

Sharing can be turned off on its own, and Printemps as a whole can be turned off
to get the stock widget back without uninstalling.

## Install

- `make package`

Needs `iPhoneOS16.5.sdk` from [theos/sdks](https://github.com/theos/sdks).
Unlike Xcode's own SDK it carries the PrivateFrameworks the preference bundle
links against. Packages are built with the rootless scheme.

## Reporting a layout problem

Turn on *debug logging* in the Printemps settings, respring, then read
`/var/mobile/Library/Logs/Printemps.log`. It records which activity group the
lock screen handed Printemps and the frames it applied, which is what the layout
constants at the top of `Tweak.xm` are tuned against. The same lines go to the
system log.

Printemps always logs one line when it is injected, whether or not debug
logging is on, so an empty system log means the tweak was never loaded.

## License
[MIT](https://github.com/karin722/Printemps/blob/main/LICENSE)

## Contact
- [Twitter](https://twitter.com/tako3s)

## Credits
- Original
  - [TinyWidget14](https://github.com/p2kdev/TinyWidget14) under [MIT license](https://github.com/p2kdev/TinyWidget14/blob/main/LICENSE)
- Icon
  - [ikonate](https://github.com/mikolajdobrucki/ikonate) under [MIT license](https://github.com/mikolajdobrucki/ikonate/blob/master/LICENSE)
