# 작업 백로그 (아카핏)

## ✅ 완료
- 아카이브 탭: 영상 탭 시 단일 영상만 표시 + 카테고리/운동 도구/메모 인라인 편집 (`ArchiveVideoDetailScreen`)
- `ExerciseVideo` 모델에 `memo` 필드 추가 (backward-compat 디코딩)
- 영어 "Video N" 라벨 → "N번째 영상"
- `ActionButton.swift` 복구 (마지막 커밋 버전으로)
- 앱 아이콘 교체 (리퀴드 글래스 덤벨 + 재생)
- Display Name `AcaFit` → `아카핏`
- YouTube 플레이어 안정성: youtube.com embed URL 직접 로드 + navigation delegate 정리 + `enablejsapi=1`

## ✅ 완료 — 영상 묶음
- 단일 YouTube 영상 URL 가져오기 (`youtu.be/…`, `?v=…`, `/embed/…`, `/shorts/…` 자동 파싱)
- 가져오기 URL 자동 판별: 재생목록 vs 단일 영상
- YouTube Data API v3로 정확한 영상 길이 + 제목 가져오기
- 설정 탭에 API key 입력 (SecureField, `@AppStorage`로 로컬 저장)
- API key 없을 때는 기존 RSS feed로 fallback

## ⏳ 대기 — 영상 묶음
- [ ] **mp4 가져오기 (로컬 파일 + 인터넷 URL)**
  - 모델 확장: `VideoSource = .youtube(id) | .localFile(url) | .remoteURL(url)`
  - AVPlayer 기반 재생 뷰
  - 로컬 파일은 앱 Documents 디렉토리에 복사 저장
  - duration은 AVAsset으로 정확히 추출

## ⏳ 대기 — 기능 추가
- [ ] **루틴 만들기 기능**
  - 모델: `CustomRoutine { id, name, videoIDs[] }`, `RoutineSelection: .automatic | .custom(id) | .all`
  - 설정 탭 "오늘 루틴" 섹션에 선택 라디오 + "+ 새 루틴" 버튼
  - 새 루틴 편집 sheet: 이름 입력 + 아카이브 영상 다중 선택
  - 오늘 탭 동작:
    - 자동 추천: 기존 `recommendationPlan` 그대로
    - 특정 루틴: 해당 루틴 영상들 (선택 순서)
    - 모두 보기: `exerciseVideos` 전부

## 📝 메모 / 알려진 제약
- iOS 시뮬레이터에서 YouTube embed가 검은 화면 나오는 경우 있음 → 실기기에서 확인 권장
- 영상 소유자가 임베드 차단한 영상은 "오류 153" 발생 (코드 문제 아님)
- YouTube Data API v3 비용: 무료 quota 10,000 unit/일, 일반 사용은 사실상 무료
