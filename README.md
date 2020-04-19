# ReviewKit

<p>
  <a href="https://github.com/Carthage/Carthage">
  	<img alt="Carthage Compatible" src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat">
  </a>
  <a href="https://swift.org/blog/swift-5-2-released/">
  	<img alt="Swift 5.2" src="http://img.shields.io/badge/swift-5.2-brightgreen.svg">
  </a>
  <a href="https://github.com/simonmitchell/ReviewKit/blob/master/README.md">
  	<img alt="MIT" src="https://img.shields.io/badge/license-MIT-brightgreen.svg">
  </a>
</p>

ReviewKit is a Swift package/framework that provides logic designed to prompt users at the ideal moment for a review of your app. At a basic level it works by beginning an "App Session" and then sending "Actions" – which contain a "Score" and a few other properties – to the main controller object. This allows the library to track things such as:

- The last date a review prompt was requested.
- The last session in which a review prompt was requested.
- The last version of the app for which a review prompt was requested.
- The average score of each session.
- The total number of sessions a user has had.

This library **DOES NOT** provide any kind of review UI, it was primarily designed with iOS in mind – which Apple don't allow custom review prompts on – although you can easily configure it to show your own review prompt on other platforms. The reason that it doesn't provide any UI is due to Apple's strict shutdown and rejection of app's which provide their own UI to "filter" bad reviews out.

This library attempts to provide some of that filtering behind the scenes by requiring a strict set of criteria ([All configurable](#configuration)) before requesting a review prompt to be shown. It also provides default timeouts between subsequent prompts which is particularly important when using `SKStoreReviewController` as Apple do not provide any kind of timeout for it's method.

Usage on other platforms is outlined [below](#other-platforms)

## Installation

### Carthage
[Carthage](https://github.com/Carthage/Carthage) is a package manager which either builds projects and provides you with binaries or uses pre-built frameworks from release tags in GitHub. To add ReviewKit to your project, simply specify it in your `Cartfile`:

```ogdl
github "simonmitchell/ReviewKit" ~> 1.2.0
```

### Swift Package Manager
[Swift Package Manager](https://swift.org/package-manager/) is apple's dependency manager for distributing Swift code. It is embedded into Xcode, but can also be used in the command line.

To add ReviewKit to your project simply add it to your dependencies array:

```swift
dependencies: [
    .package(url: "https://github.com/simonmitchell/ReviewKit.git", .upToNextMajor(from: "1.2.0"))
]
```

### Manual
Manual installation (as of iOS 13) requires a paid developer license in order to run on a physical device.

1. Download, or checkout in Git the source code.
1. Drag the ReviewKit.xcodeproj file into your own project. 
1. Drag ReviewKit.framework from the project navigator into the "Frameworks, Libraries and Embedded Content" section of your project.
1. Make sure "Embed" is set to "Embed & Sign"  

## Usage

### Starting a Session
To start a new app session, simply call:

```swift
RequestController.startSession(version: Bundle.main.version)
```

It is very important you call this before logging actions, otherwise they will be stored under a default session with app version `1.0.0`

### Logging an action
To log an action, then call

```swift
requestController.log(action: .init(score: 50, showReview: true, isBad: false)
```
 
|  Property  |  Description   |
|---|---|
|  score |  The score of the action, positive actions should have a positive score, and negative should have a negative. The scale is up to you as a user of this library.  |
|  showReview   |  Whether a review can be shown directly after this action has occured, this should be true if you deem the action to be important enough to have a review shown after it. Good examples may be: The user has just finished a checkout process, or the user has just completed a level of your game.  |
|  isBad  | Whether an action was so bad, that it would entirely put the user off your app and therefore you may not want to show them a review at all, or even for a few sessions or cooldown period afterwards. |

### Resetting 
If for some reason you want to reset all sessions, and start from scratch entirely you can call:

```swift
requestController.reset()
```

### Providing custom storage for the session history
By default all historical review and session information is stored in `UserDefaults.standard` however there is a `ReviewRequestControllerStorage` protocol which you can implement and then set on the controller object like so:

```swift
requestController.storage = myCustomStorageInstance
```
You may want to do this if you want to sync the session history and prompt history between multiple devices or platforms.

### Showing Custom Prompts

```swift
var reviewRequester: ReviewRequester?
```

You can control the review prompt that is shown by implementing the `ReviewRequester` protocol in your code, and setting this property. This defaults to `AppStoreReviewRequester` on supported operating systems which is a wrapper that calls `SKStoreReviewController.requestReview()`. 

⚠️ **If you are using this library on an operating system which doesn't support `SKStoreReviewController` you MUST provide a value for this property.** ⚠️

###Accessing Checks

The same checks that the library does internally can be accessed individually through a set of properties. These could be useful for example if you have a button in your UI which the user can use to go to your App's store page you could hide/show it using a combination of these properties.

|  Property  |  Description   |
|---|---|
|  timeoutSinceFirstSessionHasElapsed |  Whether the timeout since the first app session has elapsed  |
|  timeoutSinceLastRequestHasElapsed   |  Whether the timeout since the last time the user was prompted for a review has passed  |
|  timeoutSinceLastBadSessionHasElapsed  | Whether the timout since the last time the user experienced a 'bad' session has passed |
| versionChangeSinceLastRequestIsSatisfied | Whether the required app version change has occured since the last version the user was prompted for a review on |
| averageScoreThresholdIsMet | Whether the average score over the last 'n' sessions has been met. If no previous sessions are recorded, this will return `false` |
| currentSessionIsAboveScoreThreshold | Whether the current session has met the required score threshold |

All of these can be checked in one go by checking

```swift
ReviewRequestController.shared.allReviewPromptCriteriaSatisfied
```

The values returned in these variables are all based on thee configuration settings below.

## Configuration

### Score

```swift
var scoreThreshold: Double = 100.0
```
The score which the current session has to reach before the review prompt is shown.

### Average Score

```swift
var averageScoreThreshold: (score: Double, sessions: Int) = (score: 75, sessions: 3)
```
This determines the threshold for the average score that must have been achieved over the given number of previous sessions for the review prompt to be shown. This can be disabled if `sessions` is set to (or below) `0`.

### Score Bounds

```swift
var scoreBounds: ClosedRange<Double>? = -200.0...200.0
```
This can be used to bound the score for the current session, it stops the current sessions score from getting too out of hand in either a negative or positive direction. This can be disabled by setting it to `nil`.

### Initial Request Timeout

```swift
var initialRequestTimeout: Timeout = Timeout(sessions: 2, duration: 4 * .day, operation: .and)
```
This defines the minumum app usage from first launch, in sessions and/or time interval to display a review prompt to the user. This can be disabled by setting both `sessions` and `duration` to 0. Values are non-inclusive so the above means the app user must be on their third session and having used the app for over (to the second) 4 days.

### Subsequent Request Timeout

```swift
var reviewRequestTimeout: Timeout = Timeout(sessions: 4, duration: 8 * .week, operation: .and)
```
This defines the minumum app usage in sessions and/or time interval since the last time a review prompt was displayed to the user. This can be disabled by setting both `sessions` and `duration` to 0. Values are non-inclusive so the above means the app user must be on their 5th session after the previous prompt and having used the app for an additional (to the second) 8 weeks.

### Version Difference

```swift
var reviewVersionTimeout: Version? = Version(major: 0, minor: 0, patch: 1)
```
The minimum version change that must have taken place since the last review was prompted before another is shown.

### Disable During a "bad" Session

```swift
var disabledForBadSession: Bool = true
```
Setting this to false will allow the review prompt to be shown even if the current session was previously marked as "bad"

### Bad Session Timeout

```swift
var badSessionTimeout: Timeout = Timeout(sessions: 2, duration: 2 * .day, operation: .or)
```
The minimum number of sessions and/or time since the last bad session occured. 

### Other Platforms
If your platform doesn't have Foundation's `UserDefaults` you can provide your own storage using:

```swift
requestController.storage = myCustomStorageInstance
```

If your platform doesn't support `SKStoreReviewController` you can provide a custom request controller using:

```swift
requestController.reviewRequester = myCustomRequester
```
