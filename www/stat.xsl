<?xml version="1.0" encoding="utf-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/">
<html>
<head>
<title>NGINX RTMP Statistics</title>
<style>
body {
    font-family: Arial, sans-serif;
    background: #f5f5f5;
    margin: 0;
    padding: 20px;
}
.container {
    max-width: 1200px;
    margin: 0 auto;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    padding: 20px;
}
h1 { color: #333; text-align: center; }
.section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
.application { background: #f9f9f9; }
.live { background: #e8f5e8; }
table { width: 100%; border-collapse: collapse; margin: 10px 0; }
th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #ddd; }
th { background: #007bff; color: white; }
.stat-row { display: flex; justify-content: space-between; margin: 5px 0; }
.stat-label { font-weight: bold; }
</style>
</head>
<body>
<div class="container">
    <h1>📊 NGINX RTMP Server Statistics</h1>
    
    <div class="section">
        <h2>Server Information</h2>
        <div class="stat-row">
            <span class="stat-label">NGINX Version:</span>
            <span><xsl:value-of select="rtmp/nginx_version"/></span>
        </div>
        <div class="stat-row">
            <span class="stat-label">NGINX RTMP Version:</span>
            <span><xsl:value-of select="rtmp/nginx_rtmp_version"/></span>
        </div>
        <div class="stat-row">
            <span class="stat-label">Server Built:</span>
            <span><xsl:value-of select="rtmp/built"/></span>
        </div>
        <div class="stat-row">
            <span class="stat-label">PID:</span>
            <span><xsl:value-of select="rtmp/pid"/></span>
        </div>
        <div class="stat-row">
            <span class="stat-label">Uptime:</span>
            <span><xsl:value-of select="rtmp/uptime"/></span>
        </div>
    </div>

    <xsl:for-each select="rtmp/server">
    <div class="section">
        <h2>RTMP Server</h2>
        
        <xsl:for-each select="application">
        <div class="application section">
            <h3>Application: <xsl:value-of select="name"/></h3>
            
            <xsl:if test="live">
            <div class="live section">
                <h4>📡 Live Streams</h4>
                <table>
                    <tr>
                        <th>Stream Name</th>
                        <th>Time Running</th>
                        <th>Bandwidth (bytes/s)</th>
                        <th>Clients</th>
                        <th>Video Info</th>
                        <th>Audio Info</th>
                    </tr>
                    <xsl:for-each select="live/stream">
                    <tr>
                        <td><strong><xsl:value-of select="name"/></strong></td>
                        <td><xsl:value-of select="time"/> ms</td>
                        <td>
                            Video: <xsl:value-of select="bw_video"/> bytes/s<br/>
                            Audio: <xsl:value-of select="bw_audio"/> bytes/s
                        </td>
                        <td><xsl:value-of select="nclients"/></td>
                        <td>
                            <xsl:if test="meta/video">
                                Codec: <xsl:value-of select="meta/video/codec"/><br/>
                                Profile: <xsl:value-of select="meta/video/profile"/><br/>
                                Level: <xsl:value-of select="meta/video/level"/><br/>
                                Width: <xsl:value-of select="meta/video/width"/><br/>
                                Height: <xsl:value-of select="meta/video/height"/><br/>
                                Frame Rate: <xsl:value-of select="meta/video/frame_rate"/>
                            </xsl:if>
                        </td>
                        <td>
                            <xsl:if test="meta/audio">
                                Codec: <xsl:value-of select="meta/audio/codec"/><br/>
                                Profile: <xsl:value-of select="meta/audio/profile"/><br/>
                                Channels: <xsl:value-of select="meta/audio/channels"/><br/>
                                Sample Rate: <xsl:value-of select="meta/audio/sample_rate"/>
                            </xsl:if>
                        </td>
                    </tr>
                    </xsl:for-each>
                </table>
                
                <h5>📱 Connected Clients</h5>
                <table>
                    <tr>
                        <th>Client ID</th>
                        <th>Address</th>
                        <th>Time Connected</th>
                        <th>Dropped Frames</th>
                        <th>Type</th>
                    </tr>
                    <xsl:for-each select="live/stream/client">
                    <tr>
                        <td><xsl:value-of select="id"/></td>
                        <td><xsl:value-of select="address"/></td>
                        <td><xsl:value-of select="time"/> ms</td>
                        <td><xsl:value-of select="dropped"/></td>
                        <td>
                            <xsl:choose>
                                <xsl:when test="publishing = 'true'">🔴 Publisher</xsl:when>
                                <xsl:otherwise>👁️ Viewer</xsl:otherwise>
                            </xsl:choose>
                        </td>
                    </tr>
                    </xsl:for-each>
                </table>
            </div>
            </xsl:if>
            
        </div>
        </xsl:for-each>
        
    </div>
    </xsl:for-each>

</div>

<script>
// Auto-refresh every 5 seconds
setTimeout(function(){
    location.reload();
}, 5000);
</script>

</body>
</html>
</xsl:template>
</xsl:stylesheet>