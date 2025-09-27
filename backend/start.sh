#!/bin/bash

# Railway startup script for AquaSync Backend
echo "🚀 Starting AquaSync Backend on Railway..."

# Create model cache directory if it doesn't exist
mkdir -p /tmp/model_cache

# Set environment variables for optimal performance
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

# Start the FastAPI application
echo "📡 Starting FastAPI server..."
uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 1
