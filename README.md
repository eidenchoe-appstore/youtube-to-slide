<h1>
  <img src="icon.icon/Assets/icon%202.png" width="48" height="48" align="center" alt="YouTube to Slide icon">
  YouTube to Slide
</h1>

[한국어 README](README.ko.md) | English

Turn lecture videos into slide images, PDFs, and PowerPoint decks on macOS.

YouTube to Slide is a local macOS app for extracting mostly static lecture slides from YouTube links and video files. Drop in a lecture recording, tune the sampling and change threshold, then export the detected slides as PNG files, a PDF, or a PPTX deck.

> The app is designed for screen-share lecture videos. It does not use AI, OCR, CLIP embeddings, or cloud processing.

## Features

- Drag and drop local lecture videos into a batch queue
- Paste a YouTube URL and see a title/thumbnail preview before adding the job
- Install missing `yt-dlp` or `ffmpeg` from inside the app when Homebrew is available
- Detect slide changes with frame sampling and pixel-change ratio
- Default 1 second sampling interval and 25% slide-change threshold
- Export PNG slide folders, PDF files, PPTX decks, and timeline JSON
- Keep output next to the source video by default
- Choose per-job and global output folders
- Tune sampling interval, pixel delta, threshold, comparison width, and output resolution
- Process batches locally with visible job progress and errors

## Quick Demo

Try the app with this short YouTube lecture video:

https://www.youtube.com/watch?v=MxGW2WurKuM&list=PLRJhV4hUhIymmp5CCeIFPyxbknsdcXCc8&index=2

Paste the URL into the YouTube field, wait for the preview card, click **Add**, then click **Start**.

## Requirements

YouTube to Slide uses local command-line tools for video handling.

```bash
brew install ffmpeg yt-dlp
```

`ffmpeg` is required for all video processing. `yt-dlp` is only required for YouTube links.

If a tool is missing, the app shows an **Install** button in the sidebar. The installer uses Homebrew when it is available. If Homebrew is not installed, install Homebrew first and then run the command above.

The app looks for tools in this order:

```text
/opt/homebrew/bin
/usr/local/bin
PATH
```

## How It Works

The app samples frames from the video, compares each frame against the previous sampled frame, and saves a new slide when enough pixels changed.

```text
video or YouTube URL
→ sample frames every N seconds
→ resize frame for comparison
→ grayscale pixel diff
→ changed_pixel_ratio >= threshold
→ export slide image
→ build PDF / PPTX / timeline JSON
```

The default slide-change metric is:

```text
changed_pixel_ratio =
count(abs(gray_t - gray_t+1) > pixel_delta) / total_pixels
```

Default values:

| Setting | Default |
| --- | ---: |
| Sampling interval | 1.0 second |
| Change threshold | 25% |
| Pixel delta | 25 |
| Compare width | 320 px |
| Resolution | Original |

## Usage

1. Open YouTube to Slide.
2. Drop one or more video files into the center drop zone, or paste a YouTube URL.
3. For YouTube links, confirm the preview card, then click **Add**.
4. Adjust threshold, sampling, output format, and resolution in the inspector.
5. Choose an output folder if you do not want the default.
6. Click **Start**.
7. Click **Reveal Output** to open the result folder in Finder.

## Output Rules

For a local video, output is created beside the source video:

```text
/Users/eiden/Movies/lecture.mp4
→ /Users/eiden/Movies/lecture/
```

For a YouTube URL, output goes under the default YouTube output folder:

```text
~/Downloads/YouTube to Slide/YouTubeTitle/
```

If a folder already exists, the app avoids overwriting by creating `Title 2`, `Title 3`, and so on.

Example output:

```text
VideoTitle/
  VideoTitle_000001_1s.png
  VideoTitle_000002_37s.png
  VideoTitle.pdf
  VideoTitle.pptx
  VideoTitle.timeline.json
```

## Output Formats

| Format | Use |
| --- | --- |
| PNG folder | Best for reviewing and reusing slide screenshots |
| PDF | Best for reading, printing, and sharing |
| PPTX | Best for opening the result as a PowerPoint deck |
| Timeline JSON | Best for auditing timestamps and change ratios |

## Tuning

Lower the threshold if the app misses slide changes.

Raise the threshold if the app creates too many slides from cursors, animations, or small highlights.

Recommended starting points:

| Lecture Type | Sampling | Threshold |
| --- | ---: | ---: |
| Static slide lecture | 1.0s | 25% |
| Bullet-heavy lecture | 0.5s | 10-15% |
| Long lecture with few changes | 2.0s | 25-35% |

## Privacy

Processing is local. Local videos stay on your Mac. YouTube links are downloaded locally with `yt-dlp` before processing. The app does not send video frames, slide images, or output files to an AI service.

The YouTube preview card uses YouTube's public preview metadata and thumbnail URL for the pasted link.

## Limitations

- YouTube support depends on `yt-dlp` and the availability of the public video URL.
- The app extracts slide screenshots, not editable slide text.
- PPTX output places each extracted slide image on a slide; it does not reconstruct native PowerPoint shapes.
- Videos with live handwriting, frequent cursor movement, animated slides, or speaker overlays may need a lower threshold or manual cleanup.
- GPU/Metal comparison is not implemented in v1.0.1; the engine is structured so acceleration can be added later.

## Build From Source

```bash
git clone https://github.com/eidenchoe-appstore/youtube-to-slide.git
cd youtube-to-slide
./script/build_and_run.sh --verify
```

Create a DMG:

```bash
./script/package_dmg.sh
```

## App Icon

Place `icon.icon` in the project root before building.

The build script uses it as the app icon when it is an ICNS file. If `icon.icon` is a PNG/JPEG image or a `.icon` package containing an image under `icon.icon/Assets`, the script converts it to `AppIcon.icns` during bundling.

## Download

Download the latest DMG from:

https://github.com/eidenchoe-appstore/youtube-to-slide/releases/latest
