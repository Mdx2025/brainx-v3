---
name: brainx
description: |
  Motor de memoria vectorial con PostgreSQL + pgvector + OpenAI embeddings.
  Permite almacenar, buscar e inyectar memorias contextuales en prompts de LLMs.
metadata:
  openclaw:
    emoji: "🧠"
    requires:
      bins: ["psql"]
      env: ["DATABASE_URL", "OPENAI_API_KEY"]
    primaryEnv: "DATABASE_URL"
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
```

### Setup de Base de Datos

```bash
# El schema está en ~/.openclaw/skills/brainx-v3/sql/
# Requiere PostgreSQL con extensión pgvector

psql $DATABASE_URL -f ~/.openclaw/skills/brainx-v3/sql/schema.sql
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
