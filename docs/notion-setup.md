# Notion Setup for YouTube to Slide

YouTube to Slide can create a real Notion page from extracted lecture slides. The app does not rely on ZIP import for this workflow. It uses the Notion API to create a child page, upload each slide PNG, and append image and study-note blocks.

Official Notion docs:

- [Create a page](https://developers.notion.com/reference/post-page)
- [Append block children](https://developers.notion.com/reference/patch-block-children)
- [Retrieve your token's bot user](https://developers.notion.com/reference/get-self)
- [Working with files and media](https://developers.notion.com/guides/data-apis/working-with-files-and-media)
- [Uploading small files](https://developers.notion.com/guides/data-apis/uploading-small-files)

## 1. Create a Notion Integration

1. Go to [Notion My Integrations](https://www.notion.so/my-integrations).
2. Click **New integration**.
3. Choose the workspace where you want to create study pages.
4. Enable content insert/update capabilities.
5. Copy the internal integration token. It usually starts with `ntn_`.

Keep this token private. Do not paste it into GitHub issues, screenshots, shared notes, or public documents.

## 2. Share the Parent Page

The integration cannot create pages under a Notion page until that page is shared with the integration.

1. Open the Notion page that should contain the generated study pages.
2. Click **Share**.
3. Invite or connect the integration you created.
4. Copy the parent page URL from the browser or Notion app.

If this step is skipped, Notion may return `403` or `404` even when the token is correct.

## 3. Connect Notion in the App

1. Open **YouTube to Slide**.
2. Open the right inspector.
3. Open **API Settings**.
4. Paste the token into **Notion API token**.
5. Click **Save Token**.
6. Confirm that the integration name shown under the token field is the integration you expect.
7. Paste the parent page URL into **Parent page URL or page ID**.

The token is stored in macOS Keychain. The parent page URL is stored in app preferences.

## 4. Send a Lecture to Notion

1. Add and process a local video or YouTube URL.
2. Save an OpenRouter API key if any slide notes are missing.
3. Click **Note to Notion Page**.

The app will:

```text
create a child page under the configured parent page
upload each slide PNG with Notion File Upload API
append image blocks
append heading, bullet, quote, code, and paragraph blocks from the generated notes
show Open in Notion when finished
```

For local videos, the Notion page title uses the video filename without the extension. For YouTube jobs, the page title uses the resolved YouTube title.

## Troubleshooting

### `object_not_found` mentions the wrong integration name

If Notion returns an error like this:

```text
Could not find page with ID: ...
Make sure the relevant pages and databases are shared with your integration "opencraw_api".
```

the quoted name is the Notion integration attached to the saved token. It is not selected by the app code. If the name is not the integration you expect:

1. Open **API Settings**.
2. Click **Clear** in the **Notion API** section.
3. Paste the token from the correct Notion integration.
4. Click **Save Token** and confirm the integration name shown in the app.
5. Share the parent page with that same integration from Notion's **Add connections** menu.

Notion can return `404 object_not_found` even when the page exists if the saved token belongs to an integration that has not been granted access to the parent page.

## Limits

- Notion direct upload supports files up to 20 MB in this app. If a slide PNG is too large, reduce the output resolution and process again.
- Notion workspaces can have lower file-size limits depending on the plan.
- The parent page must be shared with the integration.
- Notion API rate limits are respected with sequential uploads and retries for temporary failures.
