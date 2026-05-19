ARG PYTHON_RUNTIME=3.11
ARG LAMBDA_TASK_ROOT=/var/task
FROM python:${PYTHON_RUNTIME}-bookworm
ARG PYTHON_RUNTIME
ARG LAMBDA_TASK_ROOT

# Copy requirements file
COPY requirements.txt .

# Install dependencies into the canonical Lambda layer site-packages path
RUN mkdir -p "${LAMBDA_TASK_ROOT}/python/lib/python${PYTHON_RUNTIME}/site-packages" \
    && pip install -r requirements.txt -t "${LAMBDA_TASK_ROOT}/python/lib/python${PYTHON_RUNTIME}/site-packages" --no-cache-dir

# Copy to output
FROM scratch
COPY --from=0 /var/task/python /python
CMD ["true"]
