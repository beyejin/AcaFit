# Archiving Fitness (AcaFit)

iOS 운동 아카이브 앱 — YouTube 재생목록과 로컬 MP4 영상을 모아 나만의 운동 루틴을 관리합니다.

## 주요 기능

- **운동 영상 아카이브** — YouTube URL 또는 로컬 MP4를 가져와 카테고리·운동 부위·장비·메모로 분류
- **오늘의 추천** — 날짜 기반 자동 추천 또는 커스텀 루틴 선택
- **커스텀 루틴** — 원하는 영상을 묶어 요일·시간 스케줄 설정
- **YouTube Data API v3** — 영상 제목·길이 자동 가져오기 (API 키 없으면 RSS fallback)
- **자동 메타데이터 인식** — 영상 제목에서 카테고리·신체 부위·장비·시간 자동 추출

## 지원 카테고리

수영 · 스트레칭 · 필라테스 · 근력 · 유산소 등

## 시작하기

1. Xcode 16 이상에서 `ArchivingFitness.xcodeproj` 열기
2. 실기기 또는 시뮬레이터로 빌드 & 실행
3. (선택) 설정 탭에서 YouTube Data API v3 키 입력 — 영상 제목·길이 자동 조회 활성화

> YouTube embed는 iOS 시뮬레이터에서 검은 화면이 나올 수 있습니다. 실기기에서 확인을 권장합니다.

## 기술 스택

- Swift · SwiftUI
- YouTube Data API v3 / RSS feed fallback
- Swift Testing (단위 테스트)

## 라이선스

개인 프로젝트입니다.
