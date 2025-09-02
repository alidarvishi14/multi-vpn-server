FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Create non-root user
RUN useradd -m -u 1000 vpnuser && \
    chown -R vpnuser:vpnuser /app

USER vpnuser

# Expose port
EXPOSE 5556

# Run the application
CMD ["python", "scalable-sub.py"]