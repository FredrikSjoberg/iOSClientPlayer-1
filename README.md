[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

# Player

* [Features](#features)
* [License](https://github.com/EricssonBroadcastServices/iOSClientPlayer/blob/master/LICENSE)
* [Requirements](#requirements)
* [Installation](#installation)
* Usage
    - [Getting Started](#getting-started)
    - [Responding to Playback Events](#responding-to-playback-events)
    - [Enabling Airplay]()
    - [Analytics How-To]()
    - [Custom Playback Controls]()
    - [Error Handling]()
* [Release Notes](#release-notes)
* [Upgrade Guides](#upgrade-guides)
* [Roadmap](#roadmap)
* [Contributing](#contributing)


## Features
- [x] VoD, live and catchup streaming
- [x] FairPlay DRM protection
- [x] Playback event publishing
- [x] Pluggable analytics provider
- [x] Airplay
- [x] Custom playback controls
- [x] Multi-device session shift

## Requirements

* `iOS` 9.0+
* `Swift` 3.0+
* `Xcode` 8.2.1+

## Installation

### Carthage
[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependency graph without interfering with your `Xcode` project setup. `CI` integration through [fastlane](https://github.com/fastlane/fastlane) is also available.

Install *Carthage* through [Homebrew](https://brew.sh) by performing the following commands:

```sh
$ brew update
$ brew install carthage
```

Once *Carthage* has been installed, you need to create a `Cartfile` which specifies your dependencies. Please consult the [artifacts](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md) documentation for in-depth information about `Cartfile`s and the other artifacts created by *Carthage*.

```sh
github "EricssonBroadcastServices/iOSClientPlayer"
```

Running `carthage update` will fetch your dependencies and place them in `/Carthage/Checkouts`. You either build the `.framework`s and drag them in your `Xcode` or attach the fetched projects to your `Xcode workspace`.

Finaly, make sure you add the `.framework`s to your targets *General -> Embedded Binaries* section. 

## Usage
`Player` has been designed with a minimalistic but extendable approach in mind. It is a *stand-alone* player based on `AVFoundation` with an easy to use yet powerful `API`.

### Getting Started
The `Player` class is self-contained and will handle setup and teardown of associated resources as you load media into it. This allows you to instantiate it inside your `viewController`.

```Swift
class PlayerViewController: UIViewController {
    fileprivate let player: Player = Player()
    
    ...
}
```

Media rendering is done by an `AVPlayerLayer` attached to a subview of a *user supplied* view. This means *customized overlay controls* are easy to implement.

```Swift
player.configure(playerView: customPlayerView)
```

Loading and preparation of a stream is as simple as calling

```Swift
player.stream(url: pathToMedia)
```

Please note that streaming *FairPlay* protected media assets will require the client application implements a `FairplayRequester` to manage the `DRM` vaidation. This protocol extends the *Apple* supplied `AVAssetResourceLoaderDelegate` protocol. **EMP** provides an out of the box implementation for *FairPlay* protection through the [Exposure module](https://github.com/EricssonBroadcastServices/iOSClientExposure) which integrates seamlessly with the rest of the platform.

### Responding to Playback Events
Streaming media over *HLS* is an inherently asychronous process. Preparation and initialisation of a *playback session* is subject to a host of outside factors, such as network avaliability, content hosting and possibly `DRM` validation. An active session must respond to environmental changes, report on playback progress and optionally deliver event specific [analytics](#analytics-how-to) data. Additionally, user interaction must be handled in a reliable and responsive way.

Finally, [error handling](#error-handling) needs to be robust.

`Player` exposes a number of *interfaces* to manage these complexities. Playback and lifecycle events are described by `PlayerEventPublisher` protocol which `Player` implements. The functionality allow an interested party to register callbacks to fire when the events occur.

#### Initialisation and Preparation of playback
During the initialisation process `Player` creates and configures a `MediaAsset` to manage the media. If the asset is protected by *FairPlay* `DRM` the associated `FairplayRequester` is also attached.

Subsequent steps load and prepare the *stream*.

```Swift
myPlayer
    .onPlaybackCreated{ player in
        // Fires once the associated MediaAsset has been created.
        // Playback is not ready to start at this point.
    }
    .onPlaybackPrepared{ player in
        // Published when the associated MediaAsset completed asynchronous loading of relevant properties.
        // Internally, no KVO or Notifications have been registered yet at this point.
        // Playback is not ready to start at this point.
    }
    .onPlaybackReady{ player in
        // When this event fires starting playback is possible
        player.play()
    }
```

#### Playback events
Once playback is in progress the `Player` continuously publishes *events* related media status and user interaction.

```Swift
myPlayer
    .onPlaybackStarted{ player in
        // Published once the playback starts for the first time.
        // This is a one-time event.
    }
    .onPlaybackPaused{ [weak self] player in
        // Fires when the playback pauses for some reason
        self?.pausePlayButton.toggle(paused: true)
    }
    .onPlaybackResumed{ [weak self] player in
        // Fires when the playback resumes from a paused state
        self?.pausePlayButton.toggle(paused: false)
    }
    .onPlaybackAborted{ player in
        // Published once the player.stop() method is called.
        // This is considered a user action
    }
    .onPlaybackCompleted{ player in
        // Published when playback reached the end of the current media.
    }
```
Besides playback control events `Player` also publishes several status related events.

```Swift
myPlayer
    .onBitrateChanged{ [weak self] event in
        // Published whenever the current bitrate changes
        // Details about the changes can be found in the supplied event
        self?.updateQualityIndicator(with: event.currentRate)
    }
    .onBufferingStarted{ player in
        // Fires whenever the buffer is unable to keep up with playback
    }
    .onBufferingStopped{ player in
        // Fires when buffering is no longer needed
    }
    .onDurationChanged{ player in
        // Published when the active media received an update to its duration property
    }
```

#### Error forwarding
Errors encountered throughout the lifecycle of  `Player` are published through `onError(callback:)`. For more information, please see [Error Handling](#error-handling).

### Enabling Airplay
To enable airplay the client application needs to add an *Airplay* button to the playback controls (pause, play, etc). This is done by adding an `MPVolumeView` with `setShowsVolumeSlider` to `NO`.

```Swift
let airplayButton = MPVolumeView()
airplayButton.showsVolumeSlider = false
view.addSubview(airplayButton)
```

#### Background Modes
Client applications who wish to continue *Airplay* once a user locks their screen or navigates from the app need to set the relevant `Capabilities` in their *Xcode* project.

1. Select `Target` in your *Xcode* project
2. Under `Capabilities`, locate `Background Modes`
3. Make sure `Audio, AirPlay, and Picture in Picture` is selected

## Release Notes
Release specific changes can be found in the [CHANGELOG](https://github.com/EricssonBroadcastServices/iOSClientPlayer/blob/master/CHANGELOG.md).

## Upgrade Guides
The procedure to apply when upgrading from one version to another depends on what solution your client application has chosen to integrate `Player`.

Major changes between releases will be documented with special [Upgrade Guides](https://github.com/EricssonBroadcastServices/iOSClientPlayer/blob/master/UPGRADE_GUIDE.md).

### Carthage
Updating your dependencies is done by running  `carthage update` with the relevant *options*, such as `--use-submodules`, depending on your project setup. For more information regarding dependency management with `Carthage` please consult their [documentation](https://github.com/Carthage/Carthage/blob/master/README.md) or run `carthage help`.

## Roadmap

## Contributing

