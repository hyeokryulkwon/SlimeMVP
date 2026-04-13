# iOS MVP Scaffold (Real Device Verification)

이 폴더는 실 iPhone 검증용 MVP SwiftUI 스캐폴딩입니다.

## 포함 범위
- Stage0(5분) -> Stage1 단일 진화
- Stage1(1일) -> Stage2
- Stage2(2일) -> Stage3
- HealthKit 활동/수면 데이터(이동 칼로리/걸음 수/수면 시간)
- 텍스트 디버그 UI(입력/카테고리/trace)

## 폴더 구조
- `App/SlimeMVPApp.swift` : 앱 엔트리
- `UI/DebugTextView.swift` : 텍스트 디버그 화면
- `UI/MVPViewModel.swift` : 오케스트레이션
- `Data/HealthKitActivityProvider.swift` : HealthKit 수집
- `Domain/Models/*` : 모델
- `Domain/Engines/*` : 알고리즘/진화/타이머

## Xcode 연결 방법
1. Xcode에서 iOS App 프로젝트 생성 (SwiftUI)
2. 프로젝트에 이 폴더의 `.swift` 파일들을 추가
3. Target -> Signing & Capabilities 에서 `HealthKit` 추가
4. `Info.plist`에 권한 문구 추가:
   - `NSHealthShareUsageDescription`: "활동 데이터를 읽어 슬라임 진화를 검증합니다."
5. 실기기(iPhone) 선택 후 실행

## 주의 사항
- `DataSourceMode.real`은 HealthKit 실데이터(`moveKcal`, `steps`, `sleepMinutes`)를 사용합니다.
- 실데이터가 없거나 권한이 없으면 `DEBUG INFO`에서 원인을 확인할 수 있습니다.
- 앱이 종료된 동안 백그라운드에서 계속 실행되지는 않습니다.
- 대신 다음 실행/활성화 시점에 `lastTickAt` 이후 경과 시간을 catch-up 방식으로 반영합니다.
- MVP 목적은 파이프라인 검증이므로 텍스트 UI 중심입니다.

## 빠른 검증 시나리오
1. 앱 실행 -> Health 권한 요청
2. Tick 버튼으로 시간 경과(5분/1일/2일 가속)
3. 파이프라인 실행
4. Stage/캐릭터/카테고리/trace 확인
