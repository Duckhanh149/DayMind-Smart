"""Validate a local client build config without printing its values. No deployment."""
import json
from pathlib import Path
import re
import sys

FIELDS = {'DAYMIND_FIREBASE_MODE', 'DAYMIND_FIREBASE_PROJECT', 'DAYMIND_FIREBASE_API_KEY'}

def validate(value):
    if not isinstance(value, dict) or set(value) != FIELDS:
        raise ValueError('configuration_fields')
    project = value['DAYMIND_FIREBASE_PROJECT']
    key = value['DAYMIND_FIREBASE_API_KEY']
    if value['DAYMIND_FIREBASE_MODE'] != 'production':
        raise ValueError('production_mode_required')
    if not isinstance(project, str) or not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project) or project.startswith('demo-'):
        raise ValueError('project_id_invalid')
    if not isinstance(key, str) or not re.fullmatch(r'AIza[A-Za-z0-9_-]{35}', key):
        raise ValueError('client_key_invalid')

def main():
    try:
        if len(sys.argv) != 2:
            raise ValueError('config_file_required')
        path = Path(sys.argv[1])
        if path.stat().st_size > 4096:
            raise ValueError('config_size_limit')
        validate(json.loads(path.read_text(encoding='utf-8')))
        print(json.dumps({'valid': True, 'mode': 'production', 'liveProjectVerified': False}))
        return 0
    except (OSError, ValueError, TypeError):
        # Never echo path, config, private key or JSON parser exception text.
        print(json.dumps({'valid': False, 'code': 'production_config_invalid'}))
        return 1

if __name__ == '__main__':
    sys.exit(main())
