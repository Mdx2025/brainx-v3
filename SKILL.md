---
name: brainx
description: |
  Motor de memoria vectorial con PostgreSQL + pgvector + OpenAI embeddings.
  Permite almacenar, buscar e inyectar memorias contextuales en prompts de LLMs.
  Incluye hook de auto-inyección para OpenClaw y sistema completo de backup/recuperación.
metadata:
  openclaw:
    emoji: "🧠"
    requires:
      bins: ["psql"]
      env: ["DATABASE_URL", "OPENAI_API_KEY"]
    primaryEnv: "DATABASE_URL"
    hooks:
      - name: brainx-auto-inject
        event: agent:bootstrap
        description: Auto-inyecta memorias relevantes al iniciar sesión
user-invocable: true
---

# BrainX V3 - Memoria Vectorial para OpenClaw

Sistema de memoria persistida que usa embeddings vectoriales para recuperación contextual en agentes AI.

## Cuándo Usar

✅ **USAR cuando:**
- Un agente necesita "recordar" información de sesiones previas
- Querés dar contexto adicional a un LLM sobre acciones pasadas
- Necesitás búsqueda semántica por contenido
- Querés guardar decisiones importantes con metadatos

❌ **NO USAR cuando:**
- Información efímera que no necesita persistencia
- Datos estructurados tabulares (usá una DB normal)
- Cache simple (usá Redis o memoria en memoria)

## Auto-Inyección (Hook)

BrainX V3 incluye un **hook de OpenClaw** que automáticamente inyecta memorias relevantes cuando un agente inicia:

### Cómo funciona:

1. Evento `agent:bootstrap` → Hook se ejecuta automáticamente
2. Consulta PostgreSQL → Obtiene memorias hot/warm recientes
3. Genera archivo → Crea `BRAINX_CONTEXT.md` en el workspace
4. Agente lee → El archivo se carga como contexto inicial

### Configuración:

En `~/.openclaw/openclaw.json`:
```json
{
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "brainx-auto-inject": {
          "enabled": true,
          "limit": 5,
          "tier": "hot+warm",
          "minImportance": 5
        }
      }
    }
  }
}
```

### Para cada agente:

Agregar a `AGENTS.md` en cada workspace:
```markdown
## Every Session

1. Read `SOUL.md`
2. Read `USER.md`
3. Read `brainx.md`
4. Read `BRAINX_CONTEXT.md` ← Contexto auto-inyectado
```

## Herramientas Disponibles

### brainx_add_memory

Guarda una memoria en el brain vectorial.

**Parámetros:**
- `content` (requerido) - Texto de la memoria
- `type` (opcional) - Tipo: note, decision, action, learning (default: note)
- `context` (opcional) - Namespace/scope
- `tier` (opcional) - Prioridad: hot, warm, cold, archive (default: warm)
- `importance` (opcional) - Importancia 1-10 (default: 5)
- `tags` (opcional) - Tags separados por coma
- `agent` (opcional) - Nombre del agente que crea la memoria

**Ejemplo:**
```
brainx add --type decision --content "Usar embeddings 3-small para reducir costos" --tier hot --importance 9 --tags config,openai
```

### brainx_search

Busca memorias por similitud semántica.

**Parámetros:**
- `query` (requerido) - Texto a buscar
- `limit` (opcional) - Número de resultados (default: 10)
- `minSimilarity` (opcional) - Umbral 0-1 (default: 0.3)
- `minImportance` (opcional) - Filtro por importancia 0-10
- `tier` (opcional) - Filtro por tier
- `context` (opcional) - Filtro exacto por contexto

**Ejemplo:**
```
brainx search --query "configuracion de API" --limit 5 --minSimilarity 0.5
```

**Retorna:** JSON con resultados.

### brainx_inject

Obtiene memorias formateadas para inyectar directamente en prompts LLM.

**Parámetros:**
- `query` (requerido) - Texto a buscar
- `limit` (opcional) - Número de resultados (default: 10)
- `minImportance` (opcional) - Filtro por importancia
- `tier` (opcional) - Filtro por tier (default: hot+warm)
- `context` (opcional) - Filtro por contexto
- `maxCharsPerItem` (opcional) - Truncar contenido (default: 2000)

**Ejemplo:**
```
brainx inject --query "que decisiones se tomaron sobre openai" --limit 3
```

**Retorna:** Texto formateado listo para inyectar:
```
[sim:0.82 imp:9 tier:hot type:decision agent:coder ctx:openclaw]
Usar embeddings 3-small para reducir costos...

---

[sim:0.71 imp:8 tier:hot type:decision agent:support ctx:brainx]
Crear SKILL.md para integración con OpenClaw...
```

### brainx_health

Verifica que BrainX está operativo.

**Parámetros:** ninguno

**Ejemplo:**
```
brainx health
```

**Retorna:** Estado de conexión a PostgreSQL + pgvector.

## Backup y Recuperación

### Crear Backup

```bash
./scripts/backup-brainx.sh ~/backups
```

Crea archivo `brainx-v3_backup_YYYYMMDD_HHMMSS.tar.gz` con:
- Base de datos PostgreSQL completa (SQL dump)
- Configuración de OpenClaw (hooks, .env)
- Archivos de skill
- Documentación de workspaces

### Restaurar Backup

```bash
./scripts/restore-brainx.sh backup.tar.gz --force
```

Restaura completamente BrainX V3 incluyendo:
- Todas las memorias (126+ registros con embeddings)
- Configuración de hooks
- Variables de entorno

### Documentación Completa

Ver [RESILIENCE.md](RESILIENCE.md) para:
- Escenarios de desastre completos
- Migración a nuevo VPS
- Troubleshooting
- Configuración de backups automáticos

## Configuración

### Variables de Entorno

```bash
# Obligatorias
DATABASE_URL=postgresql://user:pass@host:5432/brainx_v3
OPENAI_API_KEY=sk-...

# Opcionales
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
OPENAI_EMBEDDING_DIMENSIONS=1536
BRAINX_INJECT_DEFAULT_TIER=hot+warm
BRAINX_INJECT_MAX_CHARS_PER_ITEM=2000
BRAINX_INJECT_MAX_LINES_PER_ITEM=80
```

### Setup de Base de Datos

```bash
# El schema está en ~/.openclaw/skills/brainx-v3/sql/
# Requiere PostgreSQL con extensión pgvector

psql $DATABASE_URL -f ~/.openclaw/skills/brainx-v3/sql/v3-schema.sql
```

## Integración Directa

También podés usar el wrapper unificado que lee la API key de OpenClaw:

```bash
cd ~/.openclaw/skills/brainx-v3
./brainx add --type note --content "test"
./brainx search --query "test"
./brainx inject --query "test"
./brainx health
```

## Notas

- Las memorias se almacenan con embeddings vectoriales (1536 dimensiones)
- La búsqueda usa similitud coseno
- `inject` es la herramienta más útil para dar contexto a LLMs
- Tier hot = acceso rápido, cold/archive = archive a largo plazo
- Las memorias son persistentes en PostgreSQL (independientes de OpenClaw)
- El hook de auto-inyección funciona en cada `agent:bootstrap`
