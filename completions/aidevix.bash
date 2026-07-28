# bash/zsh uchun `aidevix` buyrug'i avtomatik to'ldirilishi.
#
# Yoqish:
#   • bash: ushbu faylni ~/.bashrc dan `source` qiling.
#   • zsh : ~/.zshrc da `autoload -U +X bashcompinit && bashcompinit` dan
#           keyin ushbu faylni `source` qiling.
# install.sh buni avtomatik bajaradi.

_ai_complete() {
  local cur flags names self repo_cfg cfg
  local -a cfgs=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  flags="--list --free --top --update --doctor --add --stats --lang --icons --version --help -l -f -t -u -d -a -s -L -i -v -h"

  # Faqat birinchi argument to'ldiriladi (qolganlari agentga uzatiladi).
  if [[ "$COMP_CWORD" -ne 1 ]]; then
    return 0
  fi

  # Agent nomlarini chiqarish uchun configlarni `resolve_config` mantiqiga
  # mos tanlaymiz: AI_PULT_CONFIG berilsa — faqat o'sha; aks holda repo config
  # (ASOSIY ro'yxat) + foydalanuvchi qo'shimchalari. Repo config ushbu completion
  # fayliga nisbatan topiladi (u repo ichida turadi) — shu sababli o'rnatilgan
  # bo'sh foydalanuvchi config bilan ham claude/gemini/... nomlari taklif etiladi.
  if [[ -n "${AI_PULT_CONFIG:-}" && -r "$AI_PULT_CONFIG" ]]; then
    cfgs=("$AI_PULT_CONFIG")
  else
    self="${BASH_SOURCE[0]}"
    repo_cfg="$(cd -P "$(dirname "$self")/.." >/dev/null 2>&1 && pwd)/config/agents.conf"
    cfgs=("$repo_cfg" "$HOME/.config/ai-cli/agents.conf")
  fi

  names=""
  for cfg in "${cfgs[@]}"; do
    [[ -n "$cfg" && -r "$cfg" ]] || continue
    names+=" $(grep -vE '^[[:space:]]*(#|$)' "$cfg" 2>/dev/null \
               | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')"
  done

  # shellcheck disable=SC2207
  COMPREPLY=( $(compgen -W "$flags $names" -- "$cur") )
}

complete -F _ai_complete aidevix
