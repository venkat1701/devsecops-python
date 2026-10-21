{{- define "taskboard.fullname" -}}
{{- printf "%s-taskboard" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "taskboard.labels" -}}
app.kubernetes.io/name: taskboard
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* Selector labels for one component: include "taskboard.selector" (dict "ctx" . "component" "backend") */}}
{{- define "taskboard.selector" -}}
app.kubernetes.io/name: taskboard
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "taskboard.backendImage" -}}
{{ .Values.backend.image }}:{{ .Values.backend.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "taskboard.frontendImage" -}}
{{ .Values.frontend.image }}:{{ .Values.frontend.tag | default .Chart.AppVersion }}
{{- end }}

{{- define "taskboard.postgresHost" -}}
{{ include "taskboard.fullname" . }}-postgres
{{- end }}
