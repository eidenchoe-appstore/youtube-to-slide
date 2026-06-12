# OpenRouter Setup for YouTube to Slide

YouTube to Slide can generate slide-by-slide study notes and chat answers with OpenRouter vision-language models. The slide extraction pipeline does not require OpenRouter. OpenRouter is only needed when you click **Study Selected**, **Study All Slides**, **Note to Notion Page** with missing notes, or chat actions.

Official OpenRouter docs:

- [OpenRouter Quickstart](https://openrouter.ai/docs/quickstart)
- [OpenRouter API Authentication](https://openrouter.ai/docs/api/reference/authentication)

## 1. Create an OpenRouter API Key

1. Go to [OpenRouter](https://openrouter.ai/).
2. Sign up or log in.
3. Open the API Keys page from your OpenRouter account.
4. Create a new API key.
5. Optionally set a credit limit for safety.
6. Copy the key. OpenRouter API keys usually start with `sk-or-`.

Keep the key private. Do not paste it into GitHub issues, screenshots, shared notes, or public documents.

## 2. Connect the Key in the App

1. Open **YouTube to Slide**.
2. Add and process a video or YouTube URL.
3. Open the right inspector.
4. Open the **API Settings** tab.
5. Paste your OpenRouter API key into **OpenRouter API key**.
6. Click **Save Key**.

The app stores the key in macOS Keychain. It does not write the key to the project folder or exported slide folders.

## 3. Choose a Model

The default model order is:

```text
First model: nvidia/nemotron-nano-12b-v2-vl:free
Second model: google/gemma-4-31b-it:free
```

Select both **First model** and **Second model** in the **API Settings** tab. If the first model is rate-limited or temporarily unavailable, the app retries the same request with the second model. If both selectors use the same model, duplicate fallback is skipped.

Available model choices:

| Model | Use Case |
| --- | --- |
| `nvidia/nemotron-nano-12b-v2-vl:free` | Default. Strong for OCR, documents, charts, and slide-level visual understanding |
| `google/gemma-4-31b-it:free` | Stronger broad image understanding, multilingual explanations, and long-context synthesis |
| `nvidia/llama-nemotron-rerank-vl-1b-v2:free` | Lightweight option when speed matters more than depth |

Free models can have provider-side rate limits or temporary availability issues. Configure a fallback model so the app can recover from many temporary model failures without manual retry.

## 4. Generate Study Notes

1. Select a processed job.
2. Select a slide in **PNG Slides**.
3. Click **Study Selected** for one slide, **Study All Slides** for manual full-deck note generation, or **Note to Notion Page** for the complete full-deck Notion export workflow.

For token efficiency, **Study All Slides** and **Note to Notion Page** reuse notes that already exist and only send slides whose notes are still missing. Whole-deck chat uses generated notes as the primary context when they are available.

The VLM is prompted to infer a slide title and create a study-note structure:

```markdown
# Inferred slide title

## 핵심 요약
- Main points

## 슬라이드 내용 해설
- Student-friendly explanation

## 이미지/텍스트에서 읽힌 주요 정보
- OCR-like key terms, equations, chart labels, or diagram elements

## 공부할 때 주의할 점
- Common misunderstanding or practical interpretation

## 복습 질문
- Review questions
```

## 5. Export a Notion Page ZIP

Click **Note to Notion Page** after slide extraction. The app checks the full deck, generates missing notes for every slide, then creates the Notion-ready ZIP.

The app creates:

```text
LectureTitle.notion-page.zip
  LectureTitle.md
  assets/
    slide_000001_3s.png
    slide_000002_37s.png
```

The Markdown uses a Notion-safe heading hierarchy:

```markdown
# Lecture title

## Slide 1: Slide title inferred by the VLM

![Slide 1](assets/slide_000001_3s.png)

### 핵심 요약
- Main points

### 슬라이드 내용 해설
- Student-friendly explanation
```

Import the ZIP into Notion so the Markdown and referenced local slide images are handled together. The export intentionally avoids HTML tags, internal anchors, footnotes, Mermaid blocks, and complex tables because those are less reliable for Notion import.

Reference: [Notion enhanced Markdown format](https://developers.notion.com/guides/data-apis/enhanced-markdown).

## Privacy Notes

- Local video processing stays on your Mac.
- YouTube videos are downloaded locally with `yt-dlp` before slide extraction.
- OpenRouter is only contacted when you run AI study-note or chat features.
- The app sends selected slide PNG images and your prompt to OpenRouter for those AI actions.
- The API key is stored in macOS Keychain.
