!include "EnvVarUpdate.nsh"
!macro customInstall
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR"
!macroend
!macro customUnInstall
    ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR"
!macroend