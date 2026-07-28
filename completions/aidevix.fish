# fish shell uchun `aidevix` buyrug'i avtomatik to'ldirilishi.
#
# Yoqish:
#   • Ushbu faylni fish completion papkasiga ko'chiring:
#       ~/.config/fish/completions/aidevix.fish
#   • Homebrew bilan o'rnatilsa avtomatik ulanadi.

# Agent binarlarini config'dan o'qiydigan yordamchi funksiya.
function __aidevix_agents
    set -l cfg
    if set -q AI_PULT_CONFIG; and test -r "$AI_PULT_CONFIG"
        set cfg "$AI_PULT_CONFIG"
    else if test -r "$HOME/.config/ai-cli/agents.conf"
        set cfg "$HOME/.config/ai-cli/agents.conf"
    end
    test -n "$cfg"; or return
    grep -vE '^[[:space:]]*(#|$)' "$cfg" 2>/dev/null | cut -d'|' -f2 | string trim
end

# Faqat birinchi argumentni to'ldiramiz (qolganlari agentga uzatiladi).
set -l no_subcmd "not __fish_seen_subcommand_from (__aidevix_agents)"

# Flaglar.
complete -c aidevix -f
complete -c aidevix -n $no_subcmd -s l -l list    -d "agentlar ro'yxati va holati"
complete -c aidevix -n $no_subcmd -s f -l free    -d "faqat bepul agentlar menyusi"
complete -c aidevix -n $no_subcmd -s t -l top     -d "faqat eng mashhur agentlar menyusi"
complete -c aidevix -n $no_subcmd -s u -l update  -d "o'rnatilgan agentlarni yangilaydi"
complete -c aidevix -n $no_subcmd -s d -l doctor  -d "muhitni tekshiradi"
complete -c aidevix -n $no_subcmd -s a -l add     -d "interaktiv yangi agent qo'shadi"
complete -c aidevix -n $no_subcmd -s s -l stats   -d "global statistika (opt-in): on/off"
complete -c aidevix -n $no_subcmd -s L -l lang    -d "interfeys tili: en/uz"
complete -c aidevix -n $no_subcmd -s i -l icons   -d "ikonka uslubi: nerd/unicode/ascii/auto"
complete -c aidevix -n $no_subcmd -s v -l version -d "versiyani ko'rsatadi"
complete -c aidevix -n $no_subcmd -s h -l help    -d "yordam matnini ko'rsatadi"

# Agent nomlari.
complete -c aidevix -n $no_subcmd -a "(__aidevix_agents)" -d "AI agenti"
