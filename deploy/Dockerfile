FROM python:3.12-slim

# Install system dependencies for Kerberos and LDAP
RUN apt-get update && apt-get install -y \
    gcc \
    libkrb5-dev \
    krb5-user \
    libsasl2-dev \
    libldap2-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
# Use Docker-specific requirements (gssapi instead of winkerberos)
COPY deploy/requirements-docker.txt requirements.txt

# Install with trusted host for corporate environments
RUN pip install --no-cache-dir -r requirements.txt \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org

# Install production WSGI server
RUN pip install --no-cache-dir gunicorn \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org

# Copy application files
COPY app.py .
# Note: .env is not copied - use environment variables instead
# Environment variables will be provided by docker-compose or kubernetes

# Create non-root user for security
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run with Gunicorn (4 workers for production)
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
