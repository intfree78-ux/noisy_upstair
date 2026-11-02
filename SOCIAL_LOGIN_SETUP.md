# 간편 회원가입 설정

홈페이지 주소: https://intfree78-ux.github.io/noisy_upstair/  
Supabase OAuth callback URL: https://ardhdvnsapvxproknqpr.supabase.co/auth/v1/callback

## Google

Supabase 대시보드 → Authentication → Sign In / Providers → Google에서 제공자를 켜고 Google OAuth Client ID와 Client Secret을 입력합니다. Google Cloud의 승인된 리디렉션 URI에는 위 Supabase callback URL을 등록합니다.

## Kakao

Kakao Developers에서 발급한 REST API 키와 Client Secret을 Supabase의 Kakao 제공자에 입력하고, 카카오 로그인 Redirect URI에는 위 Supabase callback URL을 등록합니다. 이메일을 필수로 받지 않으려면 Supabase Kakao 설정에서 이메일 없이 가입 허용 여부도 확인합니다.

## 네이버

Supabase는 네이버를 기본 제공 소셜 로그인 목록에 포함하지 않으므로 **Custom OAuth Provider**로 연결합니다.

1. NAVER Developers에서 애플리케이션을 등록하고 네이버 로그인을 설정합니다. 서비스 URL에는 `https://intfree78-ux.github.io/noisy_upstair/`를 등록하고, 로그인에 사용할 이메일 등 사용자 정보 제공 항목을 설정합니다.
2. Supabase Dashboard → Authentication → Sign In / Providers → **New Provider**에서 **Manual configuration (OAuth2)**를 선택합니다.
3. 식별자는 `custom:naver`, 이름은 `네이버`로 설정하고 Client ID와 Client Secret을 입력합니다. Client Secret은 Supabase 대시보드에만 입력하고 GitHub에는 저장하지 마세요.
4. OAuth 주소를 입력합니다.
   - Authorization URL: `https://nid.naver.com/oauth2.0/authorize`
   - Token URL: `https://nid.naver.com/oauth2.0/token`
   - UserInfo URL: `https://openapi.naver.com/v1/nid/me`
5. Supabase가 새 Custom Provider 설정에 표시하는 Callback URL을 복사해 NAVER Developers 앱의 Callback URL에 등록합니다.
6. 제공자를 생성하고 활성화합니다. 로그인 버튼은 Supabase 식별자 `custom:naver`를 호출합니다.

Supabase 커스텀 OAuth는 제공자 사용자 정보 응답을 Supabase 형식으로 읽어야 합니다. 네이버 프로필 API는 사용자 정보를 `response` 객체 안에 반환하므로, 단순 연결만으로 사용자 프로필 매핑이 되지 않을 수 있습니다. 설정 후 실제 로그인을 시험하고, 응답 매핑 오류가 나면 서버 측 변환 작업이 추가로 필요합니다.

## 리디렉션 허용 목록

Authentication → URL Configuration의 Redirect URLs에 홈페이지 주소를 등록합니다. OAuth 제공자 Client Secret은 GitHub 코드에 올리지 말고 Supabase 대시보드에서만 입력합니다.
