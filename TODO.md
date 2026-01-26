Features

UI/UX improvements

- Continuous beep sound customizability?
- Confirm/adjust settings defaults.
- Group settings a bit better? E.g. no point choosing sound when continuous plays its own
- HandsOff app not running in Dock?

- Blur background red, or some other configurable color? Atm the white is a bit too strong in dark mode.

- Sensitivity should just be hardcoded to low I think, why should it not be as accurate as possible?
- Cooldown also just hardcoded to 1s for now I think. If the alert is annoying then what are we doing here?

- Can the stats picker be left aligned?
- Should the whole menu be wider now that it's quite tall?

Bugs

- Face bounding box isn't quite right on x-axis. It s offset a bit too much to the left.
- Stats grid is sometimes showing x-axis labels.
- Stats dots change when camera stopped/started repeatedly.

Not possible?

- Keep menu bar item open when clicking 'Start monitoring'?

Testing

- Confirm wake from sleep continues as expected.
- Confirm login items works as expected, if we had or hadn't previously started monitoring.
- Confirm what happens if webcam is disconnected while or while not running. Ideally should just keep going with whatever webcam is available.
  - Looks like the item is removed from the list, but the selected item remains the old one, displayed as a blank entry. No crash. Stop monitoring button is visible.
