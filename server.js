const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const axios = require('axios');
const xml2js = require('xml2js');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const PORT = process.env.PORT || 3000;
const NGINX_STATS_URL = 'http://nginx:8080/stats';
const RTMP_SERVER = process.env.RTMP_SERVER || 'localhost';

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Utility function to get RTMP statistics
async function getRTMPStats() {
    try {
        const response = await axios.get(NGINX_STATS_URL);
        const parser = new xml2js.Parser();
        const result = await parser.parseStringPromise(response.data);
        return result;
    } catch (error) {
        console.error('Error fetching RTMP stats:', error.message);
        return null;
    }
}

// Get server info and RTMP URL
app.get('/api/server-info', (req, res) => {
    const serverInfo = {
        rtmpUrl: `rtmp://${RTMP_SERVER}:1935/live`,
        hlsUrl: `http://${RTMP_SERVER}:8080/hls`,
        serverStatus: 'running',
        streamKey: 'your-stream-key',
        timestamp: new Date().toISOString()
    };
    
    res.json(serverInfo);
});

// Get live streams
app.get('/api/streams', async (req, res) => {
    const stats = await getRTMPStats();
    if (!stats) {
        return res.json({ streams: [], error: 'Unable to fetch stream data' });
    }
    
    try {
        const streams = [];
        const rtmp = stats.rtmp;
        
        if (rtmp && rtmp.server && rtmp.server[0] && rtmp.server[0].application) {
            const applications = rtmp.server[0].application;
            
            applications.forEach(app => {
                if (app.live && app.live[0] && app.live[0].stream) {
                    const streamList = Array.isArray(app.live[0].stream) 
                        ? app.live[0].stream 
                        : [app.live[0].stream];
                    
                    streamList.forEach(stream => {
                        streams.push({
                            name: stream.name ? stream.name[0] : 'unknown',
                            clients: stream.nclients ? parseInt(stream.nclients[0]) : 0,
                            bandwidth: stream.bw_video ? parseInt(stream.bw_video[0]) : 0,
                            time: stream.time ? parseInt(stream.time[0]) : 0,
                            publishing: stream.publishing && stream.publishing[0] === 'true'
                        });
                    });
                }
            });
        }
        
        res.json({ streams, total: streams.length });
    } catch (error) {
        console.error('Error parsing stream data:', error);
        res.json({ streams: [], error: 'Error parsing stream data' });
    }
});

// Get recorded videos
app.get('/api/recordings', (req, res) => {
    const recordingsPath = '/var/recordings';
    
    try {
        if (!fs.existsSync(recordingsPath)) {
            return res.json({ recordings: [] });
        }
        
        const files = fs.readdirSync(recordingsPath);
        const recordings = files
            .filter(file => file.endsWith('.flv') || file.endsWith('.mp4'))
            .map(file => {
                const filePath = path.join(recordingsPath, file);
                const stats = fs.statSync(filePath);
                
                return {
                    filename: file,
                    size: stats.size,
                    created: stats.birthtime,
                    modified: stats.mtime,
                    downloadUrl: `/api/download/${file}`
                };
            })
            .sort((a, b) => new Date(b.created) - new Date(a.created));
        
        res.json({ recordings });
    } catch (error) {
        console.error('Error reading recordings:', error);
        res.json({ recordings: [], error: 'Unable to read recordings directory' });
    }
});

// Download recorded video
app.get('/api/download/:filename', (req, res) => {
    const filename = req.params.filename;
    const filePath = path.join('/var/recordings', filename);
    
    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'File not found' });
    }
    
    res.download(filePath);
});

// Authentication endpoint for RTMP (optional)
app.post('/auth', (req, res) => {
    // Simple authentication - in production, implement proper auth
    const { name } = req.body;
    
    console.log(`Stream authentication request for: ${name}`);
    
    // Accept all streams for now
    res.status(200).send('OK');
});

// WebSocket for real-time updates
io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);
    
    // Send initial server info
    socket.emit('server-info', {
        rtmpUrl: `rtmp://${RTMP_SERVER}:1935/live`,
        hlsUrl: `http://${RTMP_SERVER}:8080/hls`,
        connected: true
    });
    
    socket.on('disconnect', () => {
        console.log('Client disconnected:', socket.id);
    });
});

// Send periodic updates to connected clients
setInterval(async () => {
    try {
        const streams = await getRTMPStats();
        io.emit('stats-update', streams);
    } catch (error) {
        console.error('Error in periodic update:', error.message);
    }
}, 5000);

server.listen(PORT, () => {
    console.log(`RTMP Dashboard Server running on port ${PORT}`);
    console.log(`RTMP URL: rtmp://${RTMP_SERVER}:1935/live`);
    console.log(`Dashboard: http://localhost:${PORT}`);
});