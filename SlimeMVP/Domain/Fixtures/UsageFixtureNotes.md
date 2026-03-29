# Usage Fixture Notes

- defaultDay fixture는 아래 케이스를 검증하도록 설계됨
  - 긴 비활성 구간(수면 후보)
  - 중간 짧은 사용(<=10분) micro-awake
  - 다시 긴 비활성 구간 병합

검증 포인트
- idleGap >= 180분 후보 인식
- micro-awake 병합 적용
- 대표 수면 구간(최장 1개) 선택
- SleepPoint 계산 및 category 매핑
