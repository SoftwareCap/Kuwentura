# Kwentura Agent Guidelines

## Godot CLI Reference

Godot supports running projects and checking scripts directly from the terminal using its command-line interface. This is ideal for automation, CI/CD pipelines, or headless environments.

[docs.godotengine](https://docs.godotengine.org/en/3.1/getting_started/editor/command_line_tutorial.html)

### Running Projects

Use the Godot executable followed by your project path or scene file from the project directory.

- **Basic run**: `godot` (runs the main scene if set) or `godot scene.tscn`
  [reddit](https://www.reddit.com/r/godot/comments/1fi1bqp/is_there_a_way_to_force_godot_to_recompilerelint/)

- **With project path**: `godot --path /path/to/project` or `godot /path/to/project/project.godot`
  [docs.godotengine](https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html)

- **Headless mode (no window)**: `godot --headless scene.tscn` (useful for servers or exports)
  [forum.godotengine](https://forum.godotengine.org/t/making-cli-applications-using-godot/127859)

- **Debug mode**: `godot -d` or `godot -d scene.tscn` (enables verbose output and breakpoints)
  [reddit](https://www.reddit.com/r/godot/comments/1fi1bqp/is_there_a_way_to_force_godot_to_recompilerelint/)

> Always ensure you're in the project root or specify `--path`/`--upwards` to locate project.godot.
> [github](https://github.com/godotengine/godot/issues/85771)

### Linting Scripts

Godot lacks a built-in lint-only CLI but offers script checking; use third-party tools like gdlint for full linting.

- **Check-only mode**: `godot --headless --check-only -s script.gd` (parses for errors without running; requires project context)
  [github](https://github.com/godotengine/godot/issues/78587)

- **Standalone scripts**: Create a .gd extending SceneTree, run with `godot -s script.gd`, and use `quit()` after checks
  [reddit](https://www.reddit.com/r/godot/comments/13gibx2/scan_whole_godot_4_project_for_gdscript_errors/)

- **gdlint tool**: Install via `pip install gdtoolkit`, then `gdlint script.gd` or `gdlint .` for directories (checks style, naming, etc.)
  [godotengine](https://godotengine.org/asset-library/asset/2520)

For project-wide linting, combine gdlint in scripts or Godot's `--check-only` in a loop over .gd files.
[github](https://github.com/Scony/godot-gdscript-toolkit)

---

*Reference: [docs.godotengine.org](https://docs.godotengine.org)*
