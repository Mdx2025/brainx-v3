#!/bin/bash
# BrainX V3 - Backup Completo
# Uso: ./backup-brainx.sh [output_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAINX_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${1:-${HOME}/backups/brainx-v3}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="brainx-v3_backup_${DATE}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "🧠 BrainX V3 - Sistema de Backup"
echo "=================================="
echo "Destino: $BACKUP_PATH"
echo ""

# Crear directorio de backup
mkdir -p "$BACKUP_PATH"

# 1. Backup de PostgreSQL (DATOS CRÍTICOS)
echo "📦 1/6 Respaldando base de datos PostgreSQL..."
if command -v pg_dump >/dev/null 2>&1; then
    # Cargar DATABASE_URL desde .env
    if [ -f "$BRAINX_DIR/.env" ]; then
        export $(grep -v '^#' "$BRAINX_DIR/.env" | grep DATABASE_URL | xargs) 2>/dev/null || true
    fi
    
    if [ -n "${DATABASE_URL:-}" ]; then
        pg_dump "$DATABASE_URL" > "$BACKUP_PATH/brainx_v3_database.sql"
        echo "   ✅ Base de datos respaldada ($(stat -c%s "$BACKUP_PATH/brainx_v3_database.sql" | numfmt --to=iec))"
    else
        echo "   ⚠️  DATABASE_URL no encontrada, saltando backup de DB"
    fi
else
    echo "   ⚠️  pg_dump no disponible, saltando backup de DB"
fi

# 2. Backup de archivos de configuración
echo "📄 2/6 Respaldando archivos de configuración..."
mkdir -p "$BACKUP_PATH/config"

# Skill principal
cp -r "$BRAINX_DIR" "$BACKUP_PATH/config/brainx-v3-skill" 2>/dev/null || true

# .env de openclaw global
cp "${HOME}/.openclaw/.env" "$BACKUP_PATH/config/openclaw.env" 2>/dev/null || true

# openclaw.json (con hooks)
cp "${HOME}/.openclaw/openclaw.json" "$BACKUP_PATH/config/openclaw.json" 2>/dev/null || true

echo "   ✅ Configuración respaldada"

# 3. Backup de hooks personalizados
echo "🪝 3/6 Respaldando hooks personalizados..."
if [ -d "${HOME}/.openclaw/hooks/internal" ]; then
    mkdir -p "$BACKUP_PATH/hooks"
    cp -r "${HOME}/.openclaw/hooks/internal" "$BACKUP_PATH/hooks/" 2>/dev/null || true
    echo "   ✅ Hooks respaldados"
else
    echo "   ℹ️  No hay hooks personalizados"
fi

# 4. Backup de documentación brainx.md en workspaces
echo "📝 4/6 Respaldando brainx.md de workspaces..."
mkdir -p "$BACKUP_PATH/workspaces"
for ws in "${HOME}/.openclaw/workspace-"*/; do
    if [ -f "$ws/brainx.md" ]; then
        name=$(basename "$ws")
        cp "$ws/brainx.md" "$BACKUP_PATH/workspaces/${name}_brainx.md" 2>/dev/null || true
    fi
done
echo "   ✅ $(ls -1 "$BACKUP_PATH/workspaces" 2>/dev/null | wc -l) archivos respaldados"

# 5. Backup de wrappers
echo "🔧 5/6 Respaldando wrappers de workspaces..."
mkdir -p "$BACKUP_PATH/wrappers"
for ws in "${HOME}/.openclaw/workspace-"*/; do
    if [ -f "$ws/hooks/brainx-v3-wrapper.sh" ]; then
        name=$(basename "$ws")
        cp "$ws/hooks/brainx-v3-wrapper.sh" "$BACKUP_PATH/wrappers/${name}_wrapper.sh" 2>/dev/null || true
    fi
done
echo "   ✅ $(ls -1 "$BACKUP_PATH/wrappers" 2>/dev/null | wc -l) wrappers respaldados"

# 6. Crear archivo de metadatos
echo "📋 6/6 Creando metadatos..."
cat > "$BACKUP_PATH/METADATA.json" << EOF
{
  "backup_version": "1.0",
  "created_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "brainx_v3": {
    "database": "brainx_v3",
    "tables": [
      "brainx_memories",
      "brainx_learning_details",
      "brainx_trajectories",
      "brainx_context_packs",
      "brainx_session_snapshots",
      "brainx_pilot_log"
    ]
  },
  "files": {
    "database_sql": "brainx_v3_database.sql",
    "skill_dir": "config/brainx-v3-skill",
    "openclaw_env": "config/openclaw.env",
    "openclaw_config": "config/openclaw.json",
    "hooks": "hooks/",
    "workspaces": "workspaces/",
    "wrappers": "wrappers/"
  },
  "restore_instructions": "Ejecutar: ./restore-brainx.sh $BACKUP_NAME"
}
EOF
echo "   ✅ Metadatos creados"

# Crear tarball comprimido
echo ""
echo "🗜️  Comprimiendo backup..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

BACKUP_SIZE=$(stat -c%s "${BACKUP_NAME}.tar.gz" | numfmt --to=iec)
echo ""
echo "=================================="
echo "✅ Backup completado exitosamente!"
echo "Archivo: ${BACKUP_NAME}.tar.gz"
echo "Tamaño: $BACKUP_SIZE"
echo "Ubicación: $BACKUP_DIR"
echo "=================================="
echo ""
echo "Para restaurar en otro VPS:"
echo "  1. Copiar ${BACKUP_NAME}.tar.gz al nuevo servidor"
echo "  2. Ejecutar: ./restore-brainx.sh ${BACKUP_NAME}.tar.gz"
echo ""
