# Jingle OBS Link

Plugin and OBS Script to link Jingle and OBS. Previously a part of Jingle itself, now split into its own repository,
with the Eye Projector being removed in favor of ToolScreen.

## Developing

Jingle GUIs are made with the IntelliJ IDEA form designer, if you intend on changing GUI portions of the code, IntelliJ
IDEA must be configured in a certain way to ensure the GUI form works properly:

- `Settings` -> `Build, Execution, Deployment` -> `Build Tools` -> `Gradle` -> `Build and run using: IntelliJ Idea`
- `Settings` -> `Editor` -> `GUI Designer` -> `Generate GUI into: Java source code`