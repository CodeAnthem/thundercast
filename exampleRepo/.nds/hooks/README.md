# Optional leaf hooks (sourced by NDS if the file exists):
#   post_scaffold.sh  — after host files are written, before git push
#   pre_install.sh    — after disk confirm, before nixos-install
#   post_install.sh   — after nixos-install (ISO still; Swarm join belongs on first boot)
#
# ThunderCast does not require Docker. Swarm/sops live on your private leaf.
