# Agent host defaults.

# vim is the default editor (nano is removed from this image).
export EDITOR=vim
export VISUAL=vim

# The agent CLIs (claude, codex, agy) install per-user into ~/.local/bin --
# see /usr/bin/llm-agents-install for why they are not in the image.
case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) ;;
  *) PATH="${HOME}/.local/bin:${PATH}" ;;
esac
export PATH
