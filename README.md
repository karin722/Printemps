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
| 14.0 – 15.x | The lock screen player |
| 16.x | The **collapsed** lock screen player. The expanded one you get by tapping the artwork is left stock. |

iOS 16 moved the lock screen player around: `context` is gone from the leaf
views, `MRUNowPlayingControlsView` was folded into `MRUNowPlayingView` and the
scrubber became an `MRUSlider`. The two firmware families therefore get their
own hooks, picked at load time in `%ctor`.

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
