# 고요 — 층간소음 지도

주거지별 소음 후기와 평점을 지도에서 살펴보는 정적 웹사이트입니다.

## 사용 기술

- GitHub Pages: 홈페이지 배포
- Kakao Maps JavaScript API: 지도 및 주거지 마커
- Supabase: 주거지·후기 데이터 조회 및 VWorld 건물정보 프록시
- VWorld WFS: 지도 화면 범위의 건축물 공간정보

## 처음 설정하기

1. Supabase 대시보드에서 프로젝트 URL과 Publishable key를 확인합니다.
2. `index.html` 상단의 `SUPABASE_URL`, `SUPABASE_KEY` 값을 프로젝트 값으로 설정합니다. Publishable key는 브라우저용 공개 키이며, Secret/service role 키는 넣으면 안 됩니다.
3. Supabase SQL Editor에서 [supabase/schema.sql](supabase/schema.sql)을 실행합니다.
4. Kakao Developers에서 앱을 만들고 카카오맵을 활성화합니다.
5. JavaScript SDK 도메인에 배포 주소와 로컬 개발 주소를 등록합니다. GitHub Pages 기본 주소는 `https://intfree78-ux.github.io`입니다.
6. 발급한 JavaScript 키를 `index.html`의 `KAKAO_JS_KEY`에 넣습니다.
7. GitHub 저장소의 **Settings → Pages**에서 `main` 브랜치, 루트 폴더를 배포 대상으로 선택합니다.

## 전국 주거 건물 데이터 연결

1. Supabase Edge Functions에서 `VWORLD_API_KEY` secret을 설정합니다.
2. Supabase CLI로 저장소 루트에서 `supabase functions deploy residential-buildings --project-ref ardhdvnsapvxproknqpr`를 실행합니다. (또는 Supabase 대시보드의 Edge Functions 편집기에 `supabase/functions/residential-buildings/index.ts` 내용을 배포합니다.)
3. Kakao 지도에서 확대 레벨 5 이하로 확대하거나 지도를 이동하면 현재 화면 범위의 주거용 건물 폴리곤을 조회합니다.

이 기능은 브이월드 건물 통합정보를 서버 함수가 조회해 반환합니다. VWorld 운영 단계는 이용 심의가 필요할 수 있으므로 공개 운영 전에 이용 승인을 확인하세요. 지도 표시 여부는 해당 범위의 데이터와 API 키 권한에 따라 달라집니다.

## 데이터 동작

- 주거지 위치는 공개 조회가 가능합니다.
- 승인된 후기만 공개 목록과 지도 점수에 반영됩니다.
- 후기 등록 화면은 Supabase Auth 로그인 연결 뒤 활성화해야 합니다.
- 테스트 위치는 실제 주거지 평가를 의미하지 않습니다.

주거지의 위치를 공개할 때는 거주자나 세대를 특정할 수 없도록 좌표와 후기 내용을 검토하세요.
