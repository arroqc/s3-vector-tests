// Configuration - injected by Terraform template
const CONFIG = {
    API_ENDPOINT: `${API_GATEWAY_URL}/search`,
    S3_BUCKET: S3_BUCKET,
    S3_REGION: S3_REGION,
};

const uploadBox = document.getElementById('uploadBox');
const imageInput = document.getElementById('imageInput');
const statusSection = document.getElementById('statusSection');
const statusMessage = document.getElementById('statusMessage');
const loadingSpinner = document.getElementById('loadingSpinner');
const resultsSection = document.getElementById('resultsSection');
const resultsList = document.getElementById('resultsList');

// Drag and drop handlers
uploadBox.addEventListener('click', () => imageInput.click());
uploadBox.addEventListener('dragover', (e) => {
    e.preventDefault();
    uploadBox.classList.add('drag-over');
});

uploadBox.addEventListener('dragleave', () => {
    uploadBox.classList.remove('drag-over');
});

uploadBox.addEventListener('drop', (e) => {
    e.preventDefault();
    uploadBox.classList.remove('drag-over');
    const files = e.dataTransfer.files;
    if (files.length > 0) {
        handleImageUpload(files[0]);
    }
});

imageInput.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
        handleImageUpload(e.target.files[0]);
    }
});

async function handleImageUpload(file) {
    if (!file.type.startsWith('image/')) {
        showStatus('Please select an image file', 'error');
        return;
    }

    try {
        showStatus('Uploading image...', 'info');
        showLoadingSpinner(true);

        // Step 1: Upload to S3
        const s3Key = await uploadToS3(file);
        showStatus('Processing image...', 'info');

        // Step 2: Call Lambda via API Gateway to search for similar images
        const results = await callSearchLambda(s3Key);

        // Step 3: Display results
        displayResults(results);
        showStatus('Search complete!', 'success');
        showLoadingSpinner(false);

    } catch (error) {
        console.error('Error:', error);
        showStatus(`Error: ${error.message}`, 'error');
        showLoadingSpinner(false);
    }
}

async function uploadToS3(file) {
    // TODO: Once API Gateway is set up, you can:
    // 1. Create an endpoint that returns a pre-signed URL
    // 2. Or handle S3 upload through the same API endpoint

    // For now, this is a placeholder
    // You'll need to implement S3 upload via pre-signed URL or through your API Gateway
    throw new Error('S3 upload not yet implemented. Set up API Gateway endpoint to get pre-signed URL.');
}

async function callSearchLambda(s3Key) {
    const response = await fetch(CONFIG.API_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            bucket: CONFIG.S3_BUCKET,
            key: s3Key,
        }),
    });

    if (!response.ok) {
        throw new Error(`API request failed: ${response.statusText}`);
    }

    const data = await response.json();

    if (data.error) {
        throw new Error(data.error);
    }

    return data.nearest_neighbors || [];
}

function displayResults(neighbors) {
    resultsList.innerHTML = '';

    if (neighbors.length === 0) {
        resultsList.innerHTML = '<p style="grid-column: 1/-1; text-align: center; color: #6c757d;">No similar images found</p>';
        resultsSection.style.display = 'block';
        return;
    }

    neighbors.forEach((neighbor, index) => {
        const resultItem = document.createElement('div');
        resultItem.className = 'result-item';

        const distance = neighbor.distance ? neighbor.distance.toFixed(4) : 'N/A';
        const key = neighbor.metadata?.key || neighbor.key || 'Unknown';

        resultItem.innerHTML = `
            <div class="result-item-image">
                <span>Image ${index + 1}</span>
            </div>
            <div class="result-item-info">
                <div class="result-item-distance">Distance: ${distance}</div>
                <div class="result-item-key">${key}</div>
            </div>
        `;

        resultsList.appendChild(resultItem);
    });

    resultsSection.style.display = 'block';
}

function showStatus(message, type = 'info') {
    statusMessage.textContent = message;
    statusMessage.className = `status-message ${type}`;
    statusSection.style.display = 'flex';
}

function showLoadingSpinner(show) {
    loadingSpinner.style.display = show ? 'block' : 'none';
}
