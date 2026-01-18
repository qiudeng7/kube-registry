{{/*
展开 chart 的名称
优先使用 nameOverride，否则使用 Chart.yaml 中的名称
结果截断到 63 个字符并移除末尾连字符

示例:
  - Release.Name: "my-release", Chart.Name: "kube-registry" → "kube-registry"
  - Release.Name: "my-release", Chart.Name: "kube-registry", nameOverride: "zot" → "zot"
*/}}
{{- define "kube-registry.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
创建默认的完整应用名称
生成格式为 {Release.Name}-{Chart.Name} 的完整资源名称
如果设置了 fullnameOverride，则直接使用该值

示例:
  - Release.Name: "prod" → "prod-kube-registry"
  - Release.Name: "kube-registry-prod" → "kube-registry-prod" (避免重复)
  - fullnameOverride: "zot-prod" → "zot-prod"
*/}}
{{- define "kube-registry.fullname" -}}
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

{{/*
生成 Clash 容器配置（当 clash.enabled=true 时使用）
*/}}
{{- define "kube-registry.clashContainer" -}}
- name: clash
  image: dreamacro/clash:latest
  command: ["/bin/sh", "-c"]
  args:
    - |
      wget -O /root/config.yaml "$SUBSCRIPTION_URL" &&
      /usr/bin/clash -d /root
  env:
    - name: SUBSCRIPTION_URL
      value: {{ .Values.clash.subscriptionUrl | quote }}
  ports:
    - containerPort: 7890
      name: http-proxy
    - containerPort: 7891
      name: socks5
    - containerPort: 9090
      name: dashboard
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"
{{- end }}

{{/*
生成 Zot 代理环境变量（当 clash.enabled=true 时使用）
*/}}
{{- define "kube-registry.proxyEnv" -}}
- name: HTTP_PROXY
  value: "http://127.0.0.1:7890"
- name: HTTPS_PROXY
  value: "http://127.0.0.1:7890"
- name: NO_PROXY
  value: "localhost,127.0.0.1"
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kube-registry.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-registry.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Standard labels
*/}}
{{- define "kube-registry.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "kube-registry.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
