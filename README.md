# Credits and Attribution

This project is free for anyone to use without attribution. However if you would like to attribute me, please include a link to the repository.

**credits.txt** includes required licensing information as described on the official Godot documentation website, linked below.
https://docs.godotengine.org/en/stable/about/complying_with_licenses.html.


# Using the project

This repository holds two Godot projects, one is a dedicated multiplayer server, and the other is a board game template that utilizes that server.
The project uses the server to determine RNG and approve player actions. Though this may be slower in the long run, it may be beneficial toward
reducing cheating in projects that get a start from this template.

To use the project:
- Open the server project and game project in separate Godot 4.2.2 instances
- Run the server project
- Run the game project - make sure you turn on multiple debug instances (3 instances will let the game load when they all connect to the server).
- Type names into the game instances
- Press the Connect button on each game instance to connect to the localhost server
- The game template and server should now load into the world
- One of the game instances will start their turn. Follow the prompts to complete each turn.


# Motivations
- Create a multiplayer board game template with a dedicated server for my future projects
- Broaden my experience with multiplayer in Godot 4
- Help others learn from my experience / provide code examples for those who need it
- See if I can make a more stable server than Ubisoft's Monopoly.
