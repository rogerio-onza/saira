if [ $HAVE_NO_SANDBOX -eq 0 ] && ! unshare -Ur true 2>/dev/null ; then
  trap - EXIT
  case "$LANG" in
    pt*) MSG="O Saíra precisa da sandbox do Chromium, e este sistema bloqueia a sandbox para AppImages. Instale o pacote .deb do Saíra." ;;
    es*) MSG="Saíra necesita el sandbox de Chromium, y este sistema lo bloquea para AppImages. Instale el paquete .deb de Saíra." ;;
    *) MSG="Saíra needs the Chromium sandbox, and this system blocks it for AppImages. Install the Saíra .deb package." ;;
  esac
  if [ -x /usr/bin/zenity ] ; then
    LD_LIBRARY_PATH="" zenity --error --text "$MSG" 2>/dev/null || true
  elif [ -x /usr/bin/kdialog ] ; then
    LD_LIBRARY_PATH="" kdialog --error "$MSG" 2>/dev/null || true
  fi
  echo "$MSG" >&2
  exit 1
fi