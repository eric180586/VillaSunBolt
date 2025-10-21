#!/usr/bin/env python3
"""
Migration Batch Applier for Villa Sun App
Reads all migration files and prepares them for application
"""

import os
import glob
from pathlib import Path

MIGRATIONS_DIR = "/tmp/cc-agent/58999531/project/supabase/migrations"

def get_all_migrations():
    """Get all migration files sorted by timestamp"""
    pattern = os.path.join(MIGRATIONS_DIR, "*.sql")
    files = sorted(glob.glob(pattern))
    return files

def read_migration(filepath):
    """Read migration file content"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def main():
    migrations = get_all_migrations()
    print(f"Found {len(migrations)} migrations to apply")
    print("\nMigrations list:")
    print("=" * 80)

    for i, migration_path in enumerate(migrations, 1):
        filename = Path(migration_path).name
        migration_name = filename.replace('.sql', '')
        size = os.path.getsize(migration_path)
        print(f"{i:3d}. {filename:70s} ({size:6d} bytes)")

    print("\n" + "=" * 80)
    print(f"\nTotal: {len(migrations)} migrations")
    print(f"\nNext step: Apply these migrations using Supabase MCP tool")

if __name__ == "__main__":
    main()
