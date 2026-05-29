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
    // Validate file size (10 MB max)
    const MAX_FILE_SIZE = 10 * 1024 * 1024;
    if (file.size > MAX_FILE_SIZE) {
        const maxSizeMB = Math.round(MAX_FILE_SIZE / 1024 / 1024);
        throw new Error(`File too large. Maximum size is ${maxSizeMB} MB`);
    }

    // Validate file type
    const allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!allowed_types.includes(file.type)) {
        throw new Error('Only image files (JPG, PNG, GIF, WebP) are supported');
    }

    try {
        // Step 1: Request pre-signed URL from Lambda
        const presignResponse = await fetch(`${CONFIG.API_ENDPOINT.split('/search')[0]}/presign`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                filename: file.name,
                size: file.size
            })
        });

        if (!presignResponse.ok) {
            const error = await presignResponse.json();
            throw new Error(error.error || 'Failed to get upload URL');
        }

        const presignData = await presignResponse.json();
        const presignedUrl = presignData.presigned_url;
        const s3Key = presignData.key;

        // Step 2: Upload to S3 using pre-signed URL
        const uploadResponse = await fetch(presignedUrl, {
            method: 'PUT',
            headers: {
                'Content-Type': file.type,
            },
            body: file
        });

        if (!uploadResponse.ok) {
            throw new Error(`S3 upload failed: ${uploadResponse.statusText}`);
        }

        console.log(`File uploaded to S3: ${s3Key}`);
        return s3Key;

    } catch (error) {
        console.error('Upload error:', error);
        throw error;
    }
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
        const emptyMsg = document.createElement('p');
        emptyMsg.style.gridColumn = '1/-1';
        emptyMsg.style.textAlign = 'center';
        emptyMsg.style.color = '#6c757d';
        emptyMsg.textContent = 'No similar images found';
        resultsList.appendChild(emptyMsg);
        resultsSection.style.display = 'block';
        return;
    }

    neighbors.forEach((neighbor, index) => {
        const resultItem = document.createElement('div');
        resultItem.className = 'result-item';

        const distance = neighbor.distance ? neighbor.distance.toFixed(4) : 'N/A';
        const key = neighbor.metadata?.key || neighbor.key || 'Unknown';

        const imageDiv = document.createElement('div');
        imageDiv.className = 'result-item-image';
        const imageSpan = document.createElement('span');
        imageSpan.textContent = `Image ${index + 1}`;
        imageDiv.appendChild(imageSpan);

        const infoDiv = document.createElement('div');
        infoDiv.className = 'result-item-info';

        const distanceDiv = document.createElement('div');
        distanceDiv.className = 'result-item-distance';
        distanceDiv.textContent = `Distance: ${distance}`;

        const keyDiv = document.createElement('div');
        keyDiv.className = 'result-item-key';
        keyDiv.textContent = key;

        infoDiv.appendChild(distanceDiv);
        infoDiv.appendChild(keyDiv);

        resultItem.appendChild(imageDiv);
        resultItem.appendChild(infoDiv);
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
