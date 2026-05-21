savedcmd_mimodulo.mod := printf '%s\n'   mimodulo.o | awk '!x[$$0]++ { print("./"$$0) }' > mimodulo.mod
