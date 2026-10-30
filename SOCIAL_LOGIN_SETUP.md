# 간편 회원가입 설정

홈페이지 주소: https://intfree78-ux.github.io/noisy_upstair/  
Supabase OAuth callback URL: https://ardhdvnsapvxproknqpr.supabase.co/auth/v1/callback

## Google

Supabase 대시보드 → Authentication → Sign In / Providers → Google에서 제공자를 켜고 Google OAuth Client ID와 Client Secret을 입력합니다. Google Cloud의 승인된 리디렉션 URI에는 위 Supabase callback URL을 등록합니다.

## Kakao

Kakao Developers에서 발급한 REST API 키와 Client Secret을 Supabase의 Kakao 제공자에 입력하고, 카카오 로그인 Redirect URI에는 위 Supabase callback URL을 등록합니다. 이메일을 필수로 받지 않으려면 Supabase Kakao 설정에서 이메일 없이 가입 허용 여부도 확인합니다.

## 리디렉션 허용 목록

Authentication → URL Configuration의 Redirect URLs에 홈페이지 주소를 등록합니다. OAuth 제공자 Client Secret은 GitHub 코드에 올리지 말고 Supabase 대시보드에서만 입력합니다.
