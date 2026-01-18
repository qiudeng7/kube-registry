{{/*
展开 chart 的名称
优先使用 nameOverride，否则使用 Chart.yaml 中的名称
结果截断到 63 个字符并移除末尾连字符

示例:
  - Release.Name: "my-release", Chart.Name: "my-zot" → "my-zot"
  - Release.Name: "my-release", Chart.Name: "my-zot", nameOverride: "zot" → "zot"
*/}}
{{- define "my-zot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
创建默认的完整应用名称
生成格式为 {Release.Name}-{Chart.Name} 的完整资源名称
如果设置了 fullnameOverride，则直接使用该值

示例:
  - Release.Name: "prod" → "prod-my-zot"
  - Release.Name: "my-zot-prod" → "my-zot-prod" (避免重复)
  - fullnameOverride: "zot-prod" → "zot-prod"
*/}}
{{- define "my-zot.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
