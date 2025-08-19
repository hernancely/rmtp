// Dashboard JavaScript
let socket;
let hls;
let currentServerInfo = {};

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeSocket();
    loadServerInfo();
    loadStreams();
    loadRecordings();
    setupModal();
    startPeriodicUpdates();
});

// Socket.IO initialization
function initializeSocket() {
    socket = io();
    
    socket.on('connect', function() {
        console.log('Connected to server');
        updateStatus(true);
    });
    
    socket.on('disconnect', function() {
        console.log('Disconnected from server');
        updateStatus(false);
    });
    
    socket.on('server-info', function(data) {
        currentServerInfo = data;
        updateServerInfo(data);
    });
    
    socket.on('stats-update', function(data) {
        updateStatistics(data);
    });
}

// Update connection status
function updateStatus(isOnline) {
    const statusElement = document.getElementById('status');
    if (isOnline) {
        statusElement.textContent = '● En línea';
        statusElement.className = 'status online';
    } else {
        statusElement.textContent = '● Desconectado';
        statusElement.className = 'status offline';
    }
}

// Load server information
async function loadServerInfo() {
    try {
        const response = await fetch('/api/server-info');
        const data = await response.json();
        currentServerInfo = data;
        updateServerInfo(data);
    } catch (error) {
        console.error('Error loading server info:', error);
    }
}

// Update server info display
function updateServerInfo(data) {
    document.getElementById('rtmp-url').value = data.rtmpUrl || '';
    document.getElementById('hls-url').value = data.hlsUrl ? `${data.hlsUrl}/live-stream.m3u8` : '';
    document.getElementById('modal-rtmp-url').textContent = data.rtmpUrl || '';
    
    // Initialize HLS player if stream is available
    initializeHLSPlayer(`${data.hlsUrl}/live-stream.m3u8`);
}

// Initialize HLS video player
function initializeHLSPlayer(hlsUrl) {
    const video = document.getElementById('live-video');
    
    if (Hls.isSupported()) {
        if (hls) {
            hls.destroy();
        }
        
        hls = new Hls({
            enableWorker: false,
            liveMaxLatencyDuration: 30,
            liveSyncDuration: 10
        });
        
        hls.loadSource(hlsUrl);
        hls.attachMedia(video);
        
        hls.on(Hls.Events.MANIFEST_PARSED, function() {
            console.log('HLS manifest loaded');
        });
        
        hls.on(Hls.Events.ERROR, function(event, data) {
            console.log('HLS error:', data);
            if (data.fatal) {
                switch(data.type) {
                    case Hls.ErrorTypes.NETWORK_ERROR:
                        console.log('Network error, trying to recover...');
                        hls.startLoad();
                        break;
                    case Hls.ErrorTypes.MEDIA_ERROR:
                        console.log('Media error, trying to recover...');
                        hls.recoverMediaError();
                        break;
                    default:
                        console.log('Fatal error, destroying HLS...');
                        hls.destroy();
                        break;
                }
            }
        });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        // Safari native HLS support
        video.src = hlsUrl;
        video.addEventListener('loadedmetadata', function() {
            console.log('Video metadata loaded (Safari)');
        });
    } else {
        console.log('HLS not supported in this browser');
    }
}

// Load active streams
async function loadStreams() {
    try {
        const response = await fetch('/api/streams');
        const data = await response.json();
        updateStreamsList(data.streams || []);
        updateStatistics({ totalStreams: data.total || 0 });
    } catch (error) {
        console.error('Error loading streams:', error);
        document.getElementById('streams-container').innerHTML = '<p>Error al cargar streams</p>';
    }
}

// Update streams list display
function updateStreamsList(streams) {
    const container = document.getElementById('streams-container');
    
    if (streams.length === 0) {
        container.innerHTML = '<p>No hay streams activos</p>';
        return;
    }
    
    const streamsHTML = streams.map(stream => `
        <div class="stream-item">
            <h4>📺 ${stream.name}</h4>
            <div class="stream-meta">
                <span>👥 ${stream.clients} espectadores</span>
                <span>📊 ${formatBandwidth(stream.bandwidth)}</span>
                <span>⏱️ ${formatTime(stream.time)}</span>
                <span class="${stream.publishing ? 'online' : 'offline'}">
                    ${stream.publishing ? '🔴 En vivo' : '⚫ Offline'}
                </span>
            </div>
        </div>
    `).join('');
    
    container.innerHTML = streamsHTML;
}

// Load recordings
async function loadRecordings() {
    try {
        const response = await fetch('/api/recordings');
        const data = await response.json();
        updateRecordingsList(data.recordings || []);
    } catch (error) {
        console.error('Error loading recordings:', error);
        document.getElementById('recordings-list').innerHTML = '<p>Error al cargar grabaciones</p>';
    }
}

// Update recordings list display
function updateRecordingsList(recordings) {
    const container = document.getElementById('recordings-list');
    
    if (recordings.length === 0) {
        container.innerHTML = '<p>No hay grabaciones disponibles</p>';
        return;
    }
    
    const recordingsHTML = recordings.map(recording => `
        <div class="recording-item">
            <div class="recording-info">
                <h4>🎥 ${recording.filename}</h4>
                <div class="recording-meta">
                    <span>📁 ${formatFileSize(recording.size)}</span>
                    <span>📅 ${formatDate(recording.created)}</span>
                </div>
            </div>
            <div class="recording-actions">
                <a href="${recording.downloadUrl}" class="btn-primary" download>⬇️ Descargar</a>
            </div>
        </div>
    `).join('');
    
    container.innerHTML = recordingsHTML;
}

// Update statistics
function updateStatistics(data) {
    if (data.totalStreams !== undefined) {
        document.getElementById('total-streams').textContent = data.totalStreams;
    }
    
    // Calculate total viewers and bandwidth from streams
    if (data.streams) {
        const totalViewers = data.streams.reduce((sum, stream) => sum + (stream.clients || 0), 0);
        const totalBandwidth = data.streams.reduce((sum, stream) => sum + (stream.bandwidth || 0), 0);
        
        document.getElementById('total-viewers').textContent = totalViewers;
        document.getElementById('bandwidth').textContent = formatBandwidth(totalBandwidth);
    }
}

// Utility functions
function formatBandwidth(bytes) {
    if (!bytes || bytes === 0) return '0 KB/s';
    const kb = bytes / 1024;
    if (kb < 1024) return `${Math.round(kb)} KB/s`;
    return `${(kb / 1024).toFixed(1)} MB/s`;
}

function formatFileSize(bytes) {
    if (!bytes || bytes === 0) return '0 B';
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${Math.round(bytes / Math.pow(1024, i) * 100) / 100} ${sizes[i]}`;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('es-ES');
}

function formatTime(seconds) {
    if (!seconds) return '00:00:00';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

// Copy to clipboard function
function copyToClipboard(elementId) {
    const element = document.getElementById(elementId);
    element.select();
    document.execCommand('copy');
    
    // Show feedback
    const button = element.nextElementSibling;
    const originalText = button.textContent;
    button.textContent = '✅';
    setTimeout(() => {
        button.textContent = originalText;
    }, 2000);
}

// Stream control functions
function refreshStream() {
    if (currentServerInfo.hlsUrl) {
        initializeHLSPlayer(`${currentServerInfo.hlsUrl}/live-stream.m3u8`);
    }
    loadStreams();
}

function toggleFullscreen() {
    const video = document.getElementById('live-video');
    if (video.requestFullscreen) {
        video.requestFullscreen();
    } else if (video.webkitRequestFullscreen) {
        video.webkitRequestFullscreen();
    } else if (video.msRequestFullscreen) {
        video.msRequestFullscreen();
    }
}

// Recording functions
function refreshRecordings() {
    loadRecordings();
}

function deleteAllRecordings() {
    if (confirm('¿Estás seguro de que quieres eliminar todas las grabaciones?')) {
        // This would need a DELETE endpoint on the server
        console.log('Delete all recordings requested');
        alert('Función no implementada aún. Contacta al administrador.');
    }
}

// Modal functions
function setupModal() {
    const modal = document.getElementById('obs-modal');
    const closeBtn = document.getElementsByClassName('close')[0];
    
    closeBtn.onclick = function() {
        modal.style.display = 'none';
    };
    
    window.onclick = function(event) {
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    };
}

function showOBSModal() {
    document.getElementById('obs-modal').style.display = 'block';
}

// Periodic updates
function startPeriodicUpdates() {
    // Update streams every 10 seconds
    setInterval(loadStreams, 10000);
    
    // Update recordings every 30 seconds
    setInterval(loadRecordings, 30000);
    
    // Update uptime
    let startTime = Date.now();
    setInterval(() => {
        const uptime = Math.floor((Date.now() - startTime) / 1000);
        document.getElementById('uptime').textContent = formatTime(uptime);
    }, 1000);
}