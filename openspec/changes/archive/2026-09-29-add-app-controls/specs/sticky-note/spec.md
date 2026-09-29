# Spec Delta

## ADDED Requirements

### Requirement: Panel position persists
The panel SHALL open at the position where the user last left it. When there is no saved position, or the saved position is not on any connected screen, the panel MUST open 20 points from the top and right edges of the main screen's visible area. The panel MUST always open fully inside one screen's visible area.

#### Scenario: Relaunch keeps position
- **WHEN** the user drags the panel to a new position, quits the app, and launches it again
- **THEN** the panel opens at the same position

#### Scenario: First launch position
- **WHEN** the app launches with no saved position
- **THEN** the panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved screen disconnected
- **WHEN** the saved position is on a screen that is no longer connected, and the app launches
- **THEN** the panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved position partly off-screen
- **WHEN** the saved position puts part of the panel outside the visible area of the screen it overlaps, and the app launches
- **THEN** the panel opens fully inside that screen's visible area, moved the shortest distance from the saved position
