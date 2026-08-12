{{/*
   Early-exit guard for scripts that only make sense with a desktop.
   Used as:  {{ "{{" }} template "gui-only.sh" . {{ "}}" }}
   immediately after the lib.sh include.
*/ -}}
{{ if not .gui -}}
info "GUI applications are disabled for this machine — skipping."
exit 0
{{ end -}}
