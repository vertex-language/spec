import (
    "ui"
    "ui/window"
    "ui/canvas"
    "codec/vp8"
    "codec/opus"
    "net/webrtc"
    "net/webrtc/rtp"
)

// ---------------------------------------------------------------
// Audio
// ---------------------------------------------------------------

func audioLoop(track: webrtc.Track) thread {
    let decoder = opus.Decoder(sampleRate: 48000, channels: 2)
    defer decoder.delete()

    let speaker = canvas.AudioOut(sampleRate: 48000, channels: 2)
    defer speaker.delete()

    var lastSeq: uint16 = 0
    var buf = [uint8](repeating: 0, count: 1500)

    while true {
        let n   = track.read(into: &buf).try()
        let pkt = rtp.parse(buf.slice(0, n)).try()

        if pkt.header.sequenceNumber <= lastSeq { continue }
        lastSeq = pkt.header.sequenceNumber

        let pcm = decoder.decode(payload: pkt.payload).try()
        speaker.write(pcm).try()
    }
}

// ---------------------------------------------------------------
// Video read — raw bytes off the track
// ---------------------------------------------------------------

func readLoop(track: webrtc.Track, ch: channel rtp.Packet) thread {
    var buf = [uint8](repeating: 0, count: 1500)

    while true {
        let n   = track.read(into: &buf).try()
        let pkt = rtp.parse(buf.slice(0, n)).try()
        ch.send(pkt)
    }
}

// ---------------------------------------------------------------
// Video render — decode VP8, commit frames to canvas
// ---------------------------------------------------------------

func renderLoop(ch: channel rtp.Packet, ctx: canvas.Context) thread {
    let decoder = vp8.Decoder(width: 1280, height: 720)
    defer decoder.delete()

    var lastSeq: uint16 = 0

    while true {
        let pkt = ch.receive()

        if pkt.header.sequenceNumber <= lastSeq { continue }
        lastSeq = pkt.header.sequenceNumber

        // strip VP8 RTP payload descriptor, accumulate bitstream chunk
        decoder.push(payload: pkt.payload).try()

        // marker bit = last RTP packet of this video frame
        if pkt.header.marker {
            let frame = decoder.decode().try()
            ctx.commit(frame)
            decoder.reset()
        }
    }
}

// ---------------------------------------------------------------
// Stats overlay
// ---------------------------------------------------------------

struct StreamStats {
    var fps:        int
    var bitrate:    int
    var packetsIn:  int
    var ssrc:       uint32
    var codec:      string
}

func StatsOverlay(stats: StreamStats) -> ui.Element {
    return (
        <hstack padding=8 spacing=16 class="stats-bar">
            <text size=11>{"FPS: "     + string(stats.fps)}</text>
            <text size=11>{"Kbps: "    + string(stats.bitrate)}</text>
            <text size=11>{"Packets: " + string(stats.packetsIn)}</text>
            <text size=11>{"SSRC: "    + string(stats.ssrc)}</text>
            <text size=11>{"Codec: "   + stats.codec}</text>
        </hstack>
    )
}

// ---------------------------------------------------------------
// Root component
// ---------------------------------------------------------------

func StreamView(pc: webrtc.PeerConnection) -> ui.Element {

    var status = "connecting..."
    var stats  = StreamStats{
        fps:       0,
        bitrate:   0,
        packetsIn: 0,
        ssrc:      0,
        codec:     "vp8",
    }

    let ctx = canvas.Context()

    pc.onTrack(func(track: webrtc.Track) {
        switch track.kind {

        case webrtc.TrackKind.video:
            let ch = rtp.Packet.channel()
            readLoop(track: track, ch: ch).spawn()
            renderLoop(ch: ch, ctx: ctx).spawn()
            stats.ssrc  = track.ssrc
            stats.codec = track.codec
            status      = "streaming"

        case webrtc.TrackKind.audio:
            audioLoop(track: track).spawn()
        }
    })

    pc.onConnectionChange(func(state: webrtc.ConnectionState) {
        switch state {
        case webrtc.ConnectionState.connected:    status = "streaming"
        case webrtc.ConnectionState.disconnected: status = "disconnected"
        case webrtc.ConnectionState.failed:       status = "failed"
        default:
            status = "connecting..."
        }
    })

    return (
        <window title="Vertex Stream" width=1280 height=760>
            <vstack>

                {status == "streaming" ?
                    <vstack>
                        <canvas ctx=ctx width=1280 height=720 />
                        <StatsOverlay stats=stats />
                    </vstack>
                :
                    <vstack grow=true align="center" spacing=12>
                        <text size=22 bold=true>{"Vertex Stream"}</text>
                        <text size=14>{"Status: " + status}</text>
                    </vstack>
                }

            </vstack>
        </window>
    )
}

// ---------------------------------------------------------------
// Entry
// ---------------------------------------------------------------

func main() -> int {
    let config = webrtc.Config{
        iceServers: ["stun:stun.l.google.com:19302"],
    }

    let pc = webrtc.PeerConnection(config: config)
    defer pc.delete()

    let offer = pc.createOffer().await().try()
    pc.setLocalDescription(offer).await().try()

    // exchange SDP with signaling server here ...

    let app = window.App(func() -> ui.Element {
        return StreamView(pc: pc)
    })

    return app.run()
}