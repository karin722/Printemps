<div align="center">
<img src="icon.png" alt="icon" width="30%" height="auto" />

# Printemps

</div>

Very small music widget

## Preview
<img src="Preview.png" alt="Preview" width="60%" height="auto" />

## Supported firmwares

| iOS | What Printemps changes |
| --- | --- |
| 14.0 – 15.x | Restyles the stock lock screen player in place |
| 16.x | Draws its own player on the lock screen. The expanded player you get by tapping the artwork is Control Center's, and is left stock. |

The two firmware families work completely differently, and `%ctor` picks one at
load time.

On iOS 14 and 15 the lock screen player is a `MRUNowPlayingView` inside
SpringBoard, so Printemps moves its parts around. iOS 16 turned that player into
a live activity drawn in another process: the cover sheet holds a
`CSActivityItemContentView` whose content arrives as a hosted scene layer, and
there is not a single MediaControls view left in SpringBoard to restyle.
Printemps therefore builds its own player from MediaRemote and puts it on the
cover sheet.

## Install

- `make package`

Needs `iPhoneOS16.5.sdk` from [theos/sdks](https://github.com/theos/sdks): it is
the oldest SDK that can build the iOS 16 code paths, and unlike Xcode's own SDK
it carries the PrivateFrameworks the preference bundle links against.

Packages are built with the rootless scheme. For a rootful build, drop
`THEOS_PACKAGE_SCHEME=rootless` from `Makefile` and `PrintempsPrefs/Makefile`
and set `Architecture: iphoneos-arm` in `control`.

## Reporting a layout problem

Turn on *debug logging* in the Printemps settings, respring, then read
`/var/mobile/Library/Logs/Printemps.log`. It records the player's `layout` and
`context` values, the view controllers it sits under and the frames that were
applied, which is what the layout constants at the top of `Tweak.xm` are tuned
against. The same lines go to the system log.

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
