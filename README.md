# 블록에어 크래프트 (로블록스)

하늘 섬에서 내 비행기로 블록을 캐고, 캔 블록으로 비행기를 고치고, 함께 싸우는 로블록스 게임입니다.

- 기획서: https://claude.ai/artifact/Lf8rEK89RVs7yV9DAL6sTP
- 성장 수치표: https://claude.ai/artifact/HRC8X2kCqXdgjqVE1J4b9H
- 개발 구조 설계서: https://claude.ai/artifact/VtwfGBKW9MZRMymb3kbj9E

## 처음 설정 (한 번만)

1. 설치: [Roblox Studio](https://create.roblox.com/), [VS Code](https://code.visualstudio.com/), [Git](https://git-scm.com/), [Rokit](https://github.com/rojo-rbx/rokit)
2. 이 저장소를 받은 폴더에서 `rokit install` → Rojo 7.4.4가 설치됩니다.
3. Studio에 Rojo 플러그인 설치: 터미널에서 `rojo plugin install`
4. Roblox에서 경험(게임)을 하나 만들고, 그 안에 플레이스를 하나 더 추가합니다 (허브 + 원정 섬).
5. Studio에서 게임 설정 → 보안 → **API 서비스에 대한 Studio 접근 사용** 켜기 (저장 테스트에 필요).

## 매일 하는 작업

```bash
rojo serve                      # 허브 플레이스 작업할 때
rojo serve island.project.json  # 원정 섬 플레이스 작업할 때
```

Studio에서 해당 플레이스를 열고 Rojo 플러그인의 **Connect**를 누르면 `src/`의 코드가 들어갑니다. 그다음 플레이(F5)로 테스트합니다.

## 폴더

| 경로 | Studio 위치 | 내용 |
|---|---|---|
| `src/shared/` | ReplicatedStorage.Shared | 양쪽 공통: Config(수치), Net(신호 이름), 도구 |
| `src/server/common/` | ServerScriptService.Server.common | 두 플레이스 공통 서버 서비스 |
| `src/server/hub/`, `src/server/island/` | ServerScriptService.Server.place | 플레이스 전용 서비스 |
| `src/client/` | StarterPlayerScripts.Client | 컨트롤러와 UI 화면 |
| `data/blocks_v2.csv` | (없음) | 블록 36종 원본 |
| `tools/export_config.py` | (없음) | CSV → `Config/Blocks.luau` 생성 |
| `places/` | (없음) | Studio 플레이스 파일 |

수치를 바꿀 때는 코드 대신 `src/shared/Config/`를 고칩니다. 블록 CSV를 고쳤으면 `python tools/export_config.py`를 실행합니다.

## 규칙

- 서버가 정답을 가집니다. 코인·블록·HP는 서버만 바꾸고, 클라이언트는 요청만 보냅니다.
- 서비스(서버)와 컨트롤러(클라이언트)는 `Init(목록)`과 `Start()`만 갖습니다. `Main`이 모두 Init한 뒤 모두 Start합니다.
- 숫자는 코드에 쓰지 않고 `Config`에서 읽습니다.

## 비행 (1단계)

- 허브에 들어가면 아래 가운데 **비행기 타기** 버튼(PC는 **F** 키도 됨)을 누르면 머리 위에 기본 비행기가 나타나고 바로 탑니다.
- PC: 마우스 또는 W/A/S/D(방향키)로 방향, Shift 빨라지기 / Ctrl 느려지기, F로 내리기
- 모바일: 왼쪽 스틱으로 방향, 오른쪽 막대로 속도(늘 앞으로 감), 위쪽 **내리기** 버튼
- Studio에 `HubMap`이라는 맵이 없으면 코드가 임시 공항 섬을 만듭니다. 나중에 Studio에서 맵을 만들어 이름을 `HubMap`으로 두면 임시 맵은 생기지 않습니다.
- 비행 손맛(속도·회전·카메라 거리)은 `src/shared/Config/Flight.luau`에서 바꿉니다.
- 비행기 모양(칸 배치)은 `src/shared/Config/FrameShapes.luau`에 있습니다.

## Studio 테스트 명령 (Studio에서만 동작)

채팅창에 입력합니다.

- `/coins 1000` 코인 더하기 (음수면 빼기)
- `/xp 500` XP 더하기
- `/stats` 출력 창에 내 레벨·코인 표시
- `/speed 70` 비행 속도를 기본의 70%로 (10~300). 날고 있는 비행기에도 바로 적용. 다시 시작하면 100%로 돌아감
