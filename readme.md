# (Average) Joe AI

_Through the screeching sound of Pillars being crushed by Monkeylords the Support Armored Command Unit whispers to the Armored Command Unit: did we underestimate him? What is average about this?_

## Development Setup

### Intellisense

There's a couple of steps to make intellisense work:

- Clone the [fa](https://github.com/FAForever/fa) repository of FAForever to disk. This is stocked with annotations.
- Install the [extension](https://github.com/FAForever/fa-lua-vscode-extension/releases/latest) for [Visual Studio Code](https://code.visualstudio.com/). 
- Create a `.vscode` folder if it does not yet exist. This is where Visual Studio Code stores configuration for this workplace.
- Copy the content of the [.setup/intellisense](./.setup/intellisense) folder into the `.vscode` folder.
- Update the path to the [fa](https://github.com/FAForever/fa) repository you cloned earlier in the `settings.json` file that you just copied into the `.vscode` folder. The field that references libraries is called `Lua.workspace.library`.
  
This adds all of the annotations of the repository to the context of the extension. To also support the concept of hooking files you'll need to do a few more steps:

- Setup a local development environment for the [fa](https://github.com/FAForever/fa) that you cloned earlier. You can learn more about that [here](https://github.com/FAForever/fa/blob/develop/setup/setup-english.md#running-the-game-with-your-changes).
- Update the path to the init file that you copied into the `bin` in the `fa-plugin.lua` file. By default the path is correct if you did not choose an alternative installation location for FAForever.

You should be all set! As you start Visual Studio Code you should see the extension load in a few thousand files. You can see this happen in the status bar of Visual Studio Code. After that, verify that as you ctrl-left-click a reference that it opens the corresponding source file and pin points the place where the reference is defined.

### Launch the game

You can use the (ab)use the [Run and Debug view](https://code.visualstudio.com/docs/debugtest/debugging) to quickly start the game with all settings set exactly the way you need it:

- Copy the content of the [.setup/run-and-debug](./.setup/intellisense) folder into the `.vscode` folder.
- For the file `.vscode/tasks/launch-game.ps1` you'll need to update the following values:
- - Update the path to the executable. This is only necessary if you did not install FAForever at the default location.
- - Update the program arguments, such as the UID of the mod and the key of the AIs that you want to launch.

This provides you with a single configuration. As you run the configuration it will ask you what map to start. You can pick a map and the game will launch. The default configuration will always launch a 1vs1 using the first two slots. You can edit this by changing the program arguments.
