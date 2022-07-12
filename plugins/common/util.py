def serialise_command(exe: str, script: str, args: dict = {}):
    """Convert command to string using a dict to represent args."""
    cmd = ""
    for key, value in args.items():
        if value is True:
            cmd += f" --{key}"
        elif str(value):
            cmd += f" --{key} {value}"
    return f"{exe} {script}{cmd}"


def bash_cd_command(dir, cmd):
    """Change directory to dir and run command."""
    cmd = cmd.replace('"', r"\"")  # escape double-quotes
    return f'bash -lc "cd {dir} && {cmd}"'
