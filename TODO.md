Features

UI/UX improvements

- Continuous beep sound customizability?
- Confirm/adjust settings defaults.
- HandsOff app not running in Dock?

Bugs

- Face bounding box isn't quite right on x-axis. It s offset a bit too much to the left.
- Stats dots change when camera stopped/started repeatedly.

Not possible?

- Keep menu bar item open when clicking 'Start monitoring'?

Testing

- Confirm wake from sleep continues as expected.
- Confirm login items works as expected, if we had or hadn't previously started monitoring.
- Confirm what happens if webcam is disconnected while or while not running. Ideally should just keep going with whatever webcam is available.
  - Looks like the item is removed from the list, but the selected item remains the old one, displayed as a blank entry. No crash. Stop monitoring button is visible.
