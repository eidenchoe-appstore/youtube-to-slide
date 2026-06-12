<h1>
  <img src="icon.icon/Assets/icon%202.png" width="48" height="48" align="center" alt="YouTube to Slide icon">
  YouTube to Slide
</h1>

[한국어 README](README.ko.md) | English

Turn lecture videos into slide images, PDFs, PowerPoint decks, and Notion-ready study pages on macOS.

YouTube to Slide is a local macOS app for extracting mostly static lecture slides from YouTube links and video files. Drop in a lecture recording, tune the sampling and change threshold, then export the detected slides as PNG files, a PDF, or a PPTX deck. If you provide an OpenRouter API key, the app can also turn extracted slide PNGs into study notes and chat context with a vision-language model.

> Slide extraction is designed for screen-share lecture videos and uses local frame comparison, not AI, OCR, CLIP embeddings, or cloud processing.

## Features

- Drag and drop local lecture videos into a batch queue
- Paste a YouTube URL and see a title/thumbnail preview before adding the job
- Install missing `yt-dlp` or `ffmpeg` from inside the app when Homebrew is available
- Detect slide changes with frame sampling and pixel-change ratio
- Default 2.5 second sampling interval and 1% slide-change threshold
- Export PNG slide folders by default, with optional PDF, PPTX, and timeline JSON
- Generate slide-by-slide study notes with OpenRouter vision models
- Chat about a selected slide or the whole lecture
- Send a full-deck **Note to Notion Page** directly into Notion with uploaded slide images and study-note blocks
- Collapse or expand Processing, PNG Slides, and Chat & Study sections in the main workspace
- Keep output next to the source video by default
- Choose per-job and global output folders
- Tune sampling interval, pixel delta, threshold, comparison width, and output resolution
- Process batches locally with visible job progress and errors

## Quick Demo

Try the app with this short YouTube lecture video:

https://www.youtube.com/watch?v=MxGW2WurKuM&list=PLRJhV4hUhIymmp5CCeIFPyxbknsdcXCc8&index=2

Paste the URL into the YouTube field, wait for the preview card, click **Add**, then click **Start Processing**.

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

AI study notes require your own OpenRouter API key. Notion page creation requires your own Notion integration token and parent page URL. API tokens are stored in macOS Keychain and are only used when you click the relevant buttons.

For setup steps, see [OpenRouter Setup](docs/openrouter-setup.md) and [Notion Setup](docs/notion-setup.md).

## AI Study Notes

After extracting slides, save an OpenRouter API key in the inspector's **API Settings** tab:

1. Paste your OpenRouter API key.
2. Click **Save Key**.
3. Choose **First model** and **Second model** for fallback.
4. Click **Study Selected**, **Study All Slides**, or ask a question in the chat box when you want manual study actions.
5. Add a Notion token and parent page URL in **API Settings**.
6. Click **Note to Notion Page** to generate missing notes, upload slide images to Notion, and create a child page under the selected parent page.

Each generated study note is prompted to start with an inferred slide title and then use section headings:

```markdown
# Inferred slide title

## 핵심 요약
## 슬라이드 내용 해설
## 이미지/텍스트에서 읽힌 주요 정보
## 공부할 때 주의할 점
## 복습 질문
```

Default model order:

```text
First model: nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free
Second model: google/gemma-4-26b-a4b-it:free
```

If the first model is rate-limited or temporarily unavailable, the app retries the same request with the second model. If both selectors use the same model, duplicate fallback is skipped. Each model slot also has an editable OpenRouter model ID field, so you can choose a preset or type a model ID directly, such as `google/gemma-4-31b-it:free`.

Model choices:

| Model | Best For |
| --- | --- |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` | Default first model for fast reasoning-oriented slide study notes when throughput matters |
| `google/gemma-4-26b-a4b-it:free` | Default fallback for Korean/English slide explanation with lower load than 31B |
| `google/gemma-4-31b-it:free` | High-capacity option for slide understanding, multilingual summaries, and instruction-following |

The app sends selected PNG slide images to OpenRouter only when you explicitly run a study or chat action.

If OpenRouter returns `free-models-per-day`, add OpenRouter credits from your OpenRouter account billing or credits page. OpenRouter documents a 50 requests/day limit for free models when you have purchased less than 10 credits, and 1000 requests/day after purchasing at least 10 credits.

For token efficiency, **Study All Slides** and **Note to Notion Page** reuse existing slide notes and only send slides whose notes are still missing. Whole-deck chat uses generated notes as the primary context when they are available.

## Send to Notion

**Note to Notion Page** no longer creates a ZIP for manual import. It uses the Notion API directly:

```text
Notion parent page URL
→ create child page named after the video title
→ upload each slide PNG with Notion File Upload API
→ append image blocks and study-note blocks
→ show Open in Notion
```

Local videos use the original video filename without the extension as the Notion page title. YouTube jobs use the resolved YouTube title.

Before sending, create a Notion integration, copy its internal integration token, and share the target parent page with that integration. See [Notion Setup](docs/notion-setup.md).

## How It Works

The app samples frames from the video, compares each sampled frame against the last accepted slide baseline, and saves a new slide when enough pixels changed. If several sampled frames do not change, the baseline remains the same until a later frame crosses the threshold.

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
count(abs(gray_baseline - gray_candidate) > pixel_delta) / total_pixels
```

Default values:

| Setting | Default |
| --- | ---: |
| Sampling interval | 2.5 seconds |
| Change threshold | 1% |
| Pixel delta | 25 |
| Compare width | 160 px |
| Resolution | Original |
| Output format | PNG selected by default |

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
| PPTX | Best for opening the result as a PowerPoint deck; slide size keeps the extracted video frame aspect ratio |
| Timeline JSON | Best for auditing timestamps and change ratios |
| Note to Notion Page | Best for creating a full-deck study page directly in Notion with uploaded slide images |

## Tuning

Lower the threshold if the app misses slide changes.

Raise the threshold if the app creates too many slides from cursors, animations, or small highlights.

Recommended starting points:

| Lecture Type | Sampling | Threshold |
| --- | ---: | ---: |
| Static slide lecture | 2.5s | 1-5% |
| Bullet-heavy lecture | 1.0s | 1-3% |
| Long lecture with few changes | 5.0s | 5-10% |

## Privacy

Slide extraction is local. Local videos stay on your Mac. YouTube links are downloaded locally with `yt-dlp` before processing. The extraction pipeline does not send video frames, slide images, or output files to an AI service.

The YouTube preview card uses YouTube's public preview metadata and thumbnail URL for the pasted link.

OpenRouter study-note and chat features send selected slide PNGs and your prompt to OpenRouter only after you click the relevant buttons. Notion page creation uploads slide PNGs and study-note text to the parent page you configured. API tokens are stored in Keychain.

## Limitations

- YouTube support depends on `yt-dlp` and the availability of the public video URL.
- AI study-note quality and rate limits depend on the selected OpenRouter model and provider availability.
- The app extracts slide screenshots, not editable slide text.
- PPTX output places each extracted slide image on a slide while preserving the extracted video frame aspect ratio; it does not reconstruct native PowerPoint shapes.
- Videos with live handwriting, frequent cursor movement, animated slides, or speaker overlays may need a lower threshold or manual cleanup.
- GPU/Metal comparison is not implemented in v2.2.5; the engine is structured so acceleration can be added later.

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
