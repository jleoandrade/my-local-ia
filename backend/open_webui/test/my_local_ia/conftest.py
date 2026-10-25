import os
import tempfile

# Modules that touch the database read these at import time.
os.environ.setdefault('WEBUI_SECRET_KEY', 'test-secret-key-for-my-local-ia-tests')
os.environ.setdefault('DATA_DIR', tempfile.mkdtemp(prefix='my-local-ia-test-'))
os.environ.setdefault('USE_SLIM_DOCKER', 'true')  # pgvector instead of chromadb: no heavy vector DB needed
