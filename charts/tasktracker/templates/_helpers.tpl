{{/*
File        : charts/tasktracker/templates/_helpers.tpl
Assignment  : DSO202 Assignment 4
Descriptor  : Unit III 3.2 - Helm templates
Purpose     : Defines common labels for chart resources.
*/}}

{{- define "tasktracker.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
