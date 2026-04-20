---
name: remotion-video
description: Create programmatic videos using Remotion (React-based video framework). Use when generating video content or animations.
argument-hint: "Create a 30-second product demo video with animated text and transitions"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references: []
thinking-level: medium
---

# Remotion Video

Create videos programmatically with React. Videos are components. Animations are code.

## Setup

New project:
```bash
npx create-video@latest
```

Add to existing project:
```bash
npm i remotion @remotion/cli @remotion/player
```

## Core Concepts

### Composition = Video Definition

```tsx
import { Composition } from "remotion";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="MyVideo"
      component={MyVideo}
      durationInFrames={150}  // 5 seconds at 30fps
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
```

### useCurrentFrame = Animation Clock

Every frame, React re-renders. `useCurrentFrame()` gives the current frame number.

```tsx
import { useCurrentFrame, useVideoConfig } from "remotion";

const MyVideo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames, width, height } = useVideoConfig();

  const opacity = Math.min(1, frame / 30); // Fade in over 1 second

  return (
    <div style={{ opacity, fontSize: 80, color: "white" }}>
      Frame {frame} of {durationInFrames}
    </div>
  );
};
```

### interpolate = Animation Curves

Map frame ranges to value ranges with easing:

```tsx
import { interpolate, Easing } from "remotion";

const MyTitle: React.FC = () => {
  const frame = useCurrentFrame();

  const translateY = interpolate(frame, [0, 30], [50, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const opacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <h1 style={{ transform: `translateY(${translateY}px)`, opacity }}>
      Hello World
    </h1>
  );
};
```

### spring = Physics-Based Animation

Natural motion without manual easing:

```tsx
import { spring, useCurrentFrame, useVideoConfig } from "remotion";

const BouncyLogo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({ frame, fps, config: { damping: 10, mass: 0.5 } });

  return (
    <img
      src="/logo.png"
      style={{ transform: `scale(${scale})` }}
    />
  );
};
```

### Sequence = Timing Segments

Offset components in time:

```tsx
import { Sequence, AbsoluteFill } from "remotion";

const MultiScene: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      <Sequence from={0} durationInFrames={60}>
        <TitleCard text="Welcome" />
      </Sequence>
      <Sequence from={60} durationInFrames={90}>
        <DemoSection />
      </Sequence>
      <Sequence from={150} durationInFrames={60}>
        <OutroCard text="Thanks for watching" />
      </Sequence>
    </AbsoluteFill>
  );
};
```

## Common Patterns

### Text Animations

**Typewriter:**
```tsx
const Typewriter: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const charsToShow = Math.floor(frame / 2);
  return <span>{text.slice(0, charsToShow)}</span>;
};
```

**Stagger reveal (word by word):**
```tsx
const StaggerText: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const words = text.split(" ");

  return (
    <div style={{ display: "flex", gap: 12 }}>
      {words.map((word, i) => {
        const delay = i * 8;
        const opacity = interpolate(frame - delay, [0, 10], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
        return <span key={i} style={{ opacity }}>{word}</span>;
      })}
    </div>
  );
};
```

### Transitions

**Slide transition:**
```tsx
const SlideTransition: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const frame = useCurrentFrame();
  const translateX = interpolate(frame, [0, 15], [100, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  return (
    <AbsoluteFill style={{ transform: `translateX(${translateX}%)` }}>
      {children}
    </AbsoluteFill>
  );
};
```

### Data-Driven Charts

```tsx
const BarChart: React.FC<{ data: number[] }> = ({ data }) => {
  const frame = useCurrentFrame();
  const max = Math.max(...data);

  return (
    <div style={{ display: "flex", alignItems: "flex-end", gap: 8, height: 400 }}>
      {data.map((value, i) => {
        const height = interpolate(
          frame,
          [i * 10, i * 10 + 20],
          [0, (value / max) * 100],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
        );
        return (
          <div
            key={i}
            style={{
              width: 40,
              height: `${height}%`,
              backgroundColor: "#4f46e5",
              borderRadius: 4,
            }}
          />
        );
      })}
    </div>
  );
};
```

### Audio

```tsx
import { Audio, staticFile } from "remotion";

const WithMusic: React.FC = () => {
  return (
    <AbsoluteFill>
      <Audio src={staticFile("background.mp3")} volume={0.5} />
      <MainContent />
    </AbsoluteFill>
  );
};
```

## Workflow

1. Define composition (dimensions, fps, duration)
2. Create scene components as React components
3. Use useCurrentFrame() + interpolate() for animations
4. Preview: `npx remotion preview`
5. Render: `npx remotion render MyVideo out/video.mp4`

## Rendering

```bash
# MP4 (default, best compatibility)
npx remotion render MyVideo out/video.mp4

# WebM (smaller, web-optimized)
npx remotion render MyVideo out/video.webm --codec=vp8

# GIF (for short clips)
npx remotion render MyVideo out/video.gif

# Image sequence (for post-processing)
npx remotion render MyVideo out/ --image-format=png --sequence
```

### Server-Side Rendering

```tsx
import { renderMedia } from "@remotion/renderer";

await renderMedia({
  composition,
  serveUrl: bundleLocation,
  codec: "h264",
  outputLocation: "out/video.mp4",
});
```

For serverless: use `@remotion/lambda` for AWS Lambda rendering.

## Integration with Gemini Pipeline

Combined with `frontend-design-pro` and `using-antigravity`:

1. **Gemini generates image assets** (hero images, icons, backgrounds)
2. **Place assets in `public/`** directory
3. **Remotion composes them** into animated video with transitions, text overlays, and motion
4. **Render to MP4** for distribution

```
Gemini (image gen) → public/assets/ → Remotion (compose + animate) → MP4
```

## Voice Synthesis with Qwen3-TTS

Generate voiceovers locally via Ollama's Qwen3-TTS, then compose into Remotion videos.

### Generate Speech

```bash
# Generate voiceover audio via Ollama
curl -s http://localhost:11434/api/generate \
  -d '{
    "model": "qwen3-tts",
    "prompt": "Welcome to our product demo. Here is what makes us different.",
    "options": { "voice": "alloy", "speed": 1.0 }
  }' --output public/voiceover.wav
```

Or via MCP:
```
ollama_generate model=qwen3-tts prompt="Your narration text here"
```

### Compose with Remotion

```tsx
import { Audio, Sequence, staticFile, useCurrentFrame } from "remotion";

const NarratedVideo: React.FC = () => {
  return (
    <AbsoluteFill>
      {/* Background music at low volume */}
      <Audio src={staticFile("background.mp3")} volume={0.15} />

      {/* Voiceover synced to scene */}
      <Sequence from={30} durationInFrames={150}>
        <Audio src={staticFile("voiceover.wav")} volume={0.9} />
        <ProductDemo />
      </Sequence>

      {/* Second narration segment */}
      <Sequence from={180} durationInFrames={120}>
        <Audio src={staticFile("voiceover-part2.wav")} volume={0.9} />
        <FeatureShowcase />
      </Sequence>
    </AbsoluteFill>
  );
};
```

### Voice-First Workflow

```
Script → Qwen3-TTS (voiceover.wav) → measure duration → set Remotion durationInFrames → animate visuals to match audio timing
```

1. Write narration script per scene
2. Generate audio with Qwen3-TTS via Ollama
3. Measure audio duration: `ffprobe -i voiceover.wav -show_entries format=duration`
4. Set `durationInFrames = Math.ceil(audioDuration * fps)`
5. Animate visuals to match narration pacing

### Tips

- Generate each scene's voiceover separately for easier timing
- Use `startFrom` and `endAt` on `<Audio>` to trim silence
- Layer: music (0.1-0.2 volume) + voiceover (0.8-1.0 volume) + SFX (0.3-0.5 volume)
- Qwen3-TTS runs locally — zero API cost, no rate limits

---

## Decision Framework

| Need | Approach |
|------|----------|
| Simple animation (< 10s) | CSS animation or Framer Motion |
| Video with scenes + timing | Remotion |
| Data-driven video at scale | Remotion + @remotion/lambda |
| Interactive preview | @remotion/player (embeddable) |
| Image assets needed | Gemini MCP → Remotion |
| Narrated explainer video | Qwen3-TTS → Remotion (voice-first workflow) |
