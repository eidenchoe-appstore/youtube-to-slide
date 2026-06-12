# YouTube to Slide Notion 설정 가이드

YouTube to Slide는 추출된 강의 슬라이드로 실제 Notion 페이지를 만들 수 있습니다. 이 기능은 ZIP import에 의존하지 않습니다. Notion API로 하위 페이지를 만들고, 각 슬라이드 PNG를 업로드한 뒤, 이미지 block과 공부노트 block을 삽입합니다.

Notion 공식 문서:

- [Create a page](https://developers.notion.com/reference/post-page)
- [Append block children](https://developers.notion.com/reference/patch-block-children)
- [Retrieve your token's bot user](https://developers.notion.com/reference/get-self)
- [Working with files and media](https://developers.notion.com/guides/data-apis/working-with-files-and-media)
- [Uploading small files](https://developers.notion.com/guides/data-apis/uploading-small-files)

## 1. Notion Integration 만들기

1. [Notion My Integrations](https://www.notion.so/my-integrations)에 접속합니다.
2. **New integration**을 누릅니다.
3. 공부 페이지를 만들 workspace를 선택합니다.
4. content insert/update 권한을 활성화합니다.
5. internal integration token을 복사합니다. 보통 `ntn_`으로 시작합니다.

이 token은 비밀번호처럼 관리해야 합니다. GitHub issue, 스크린샷, 공유 문서, 공개 노트에 붙여 넣지 마세요.

## 2. Parent Page를 Integration에 Share하기

integration은 share된 페이지 아래에만 새 페이지를 만들 수 있습니다.

1. 생성된 공부 페이지들이 들어갈 Notion parent page를 엽니다.
2. **Share**를 누릅니다.
3. 만든 integration을 초대하거나 연결합니다.
4. 해당 parent page URL을 복사합니다.

이 단계를 빼면 token이 맞아도 Notion에서 `403` 또는 `404`가 날 수 있습니다.

## 3. 앱에 Notion 연결하기

1. **YouTube to Slide**를 실행합니다.
2. 오른쪽 inspector를 엽니다.
3. **API Settings** 탭을 엽니다.
4. **Notion API token**에 token을 붙여 넣습니다.
5. **Save Token**을 누릅니다.
6. token 입력칸 아래에 표시되는 integration 이름이 기대한 integration인지 확인합니다.
7. **Parent page URL or page ID**에 parent page URL을 붙여 넣습니다.

token은 macOS Keychain에 저장됩니다. parent page URL은 앱 설정에 저장됩니다.

## 4. 강의를 Notion으로 보내기

1. 로컬 영상 또는 YouTube URL을 추가하고 처리합니다.
2. 누락된 슬라이드 노트가 있다면 OpenRouter API key를 저장합니다.
3. **Note to Notion Page**를 누릅니다.

앱은 아래 순서로 동작합니다.

```text
설정된 parent page 아래에 하위 페이지 생성
각 슬라이드 PNG를 Notion File Upload API로 업로드
이미지 block 삽입
생성된 공부노트를 heading, bullet, quote, code, paragraph block으로 삽입
완료 후 Open in Notion 버튼 표시
```

로컬 영상은 확장자를 제외한 원본 영상 파일명을 Notion page title로 사용합니다. YouTube 작업은 확인된 YouTube 제목을 사용합니다.

## Rich Formatting 지원

공부노트는 업로드 전에 native Notion block과 rich text로 변환됩니다. 현재 앱이 지원하는 형식은 아래와 같습니다.

- heading, paragraph, divider, quote, bullet list, numbered list, to-do item
- **bold**, *italic*, ~~strikethrough~~, underline span, inline code, link, inline math, inline color
- fenced code block과 block equation
- 단순 Markdown table을 Notion table block으로 변환
- child content를 포함한 `<callout icon="..." color="...">` block
- `{color="..."}` block color와 `<span color="...">...</span>` inline color

슬라이드 이미지는 앱이 별도로 업로드하므로, 생성된 공부노트에는 Markdown image syntax가 들어가지 않는 것이 좋습니다.

## 문제 해결

### `object_not_found`에 엉뚱한 integration 이름이 나오는 경우

Notion에서 아래와 같은 에러가 나오면:

```text
Could not find page with ID: ...
Make sure the relevant pages and databases are shared with your integration "opencraw_api".
```

따옴표 안의 이름은 앱이 고른 이름이 아니라 **현재 앱에 저장된 Notion token이 속한 integration 이름**입니다. 기대한 integration이 아니라면 다음 순서로 처리하세요.

1. **API Settings**를 엽니다.
2. **Notion API** 섹션에서 **Clear**를 누릅니다.
3. 올바른 Notion integration의 token을 다시 붙여 넣습니다.
4. **Save Token**을 누르고 앱에 표시되는 integration 이름을 확인합니다.
5. Notion에서 parent page의 **Add connections** 메뉴를 열어 같은 integration을 share합니다.

페이지가 실제로 존재해도, 저장된 token이 그 parent page에 접근 권한이 없는 integration의 token이면 Notion은 `404 object_not_found`를 반환할 수 있습니다.

## 제한 사항

- 이 앱의 직접 업로드는 20 MB 이하 파일을 대상으로 합니다. 슬라이드 PNG가 너무 크면 output resolution을 낮추고 다시 처리하세요.
- Notion workspace 요금제에 따라 파일 크기 제한이 더 낮을 수 있습니다.
- parent page는 반드시 integration에 share되어 있어야 합니다.
- Notion API rate limit을 고려해 순차 업로드와 일시적 실패 재시도를 적용했습니다.
