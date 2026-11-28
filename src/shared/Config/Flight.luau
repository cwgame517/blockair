--!strict
-- 비행·카메라·조작 수치 (임시값). 손맛을 바꿀 때는 이 파일만 고친다.
-- 거리 단위는 스터드, 각도 단위는 도(°), 시간 단위는 초.
return {
	CELL_SIZE = 2, -- 블록 한 칸 크기
	DEFAULT_BLOCK = "wood", -- 빈 칸을 채우는 기본 블록 (Blocks 의 key)

	-- 속도
	BASE_MAX_SPEED = 110, -- 기준 무게일 때 최고 속도
	MIN_SPEED = 35, -- 자동 전진 최저 속도 (멈춰서 떨어지지 않음)
	ACCELERATION = 45, -- 1초에 바뀌는 속도
	THROTTLE_RATE = 0.7, -- Shift/Ctrl 을 1초 누르면 바뀌는 속도 레버 (0~1)
	START_THROTTLE = 0.35,

	-- 제자리 비행 (블록 캐기용): 속도 레버를 맨 아래(이 값 미만)로 내리면 드론처럼 멈춰 떠 있다
	HOVER_ZONE = 0.06,
	HOVER_MOVE_SPEED = 22, -- 제자리 비행 중 앞뒤(W/S·스틱 위아래)로 움직이는 속도
	HOVER_TURN_RATE = 70, -- 제자리 비행 중 도는 속도 (도/초)
	HOVER_BRAKE = 70, -- 멈출 때 1초에 줄어드는 속도
	HOVER_CAMERA_PITCH = 40, -- 제자리 비행 중 카메라가 내려다보는 각도 (착탄 원이 잘 보이게)

	-- 무게: 기준 무게 = 틀 칸 수 × 이 값. 가벼우면 빠르고 잘 돈다.
	REF_WEIGHT_PER_CELL = 1,
	WEIGHT_SPEED_EXP = 0.15,
	WEIGHT_TURN_EXP = 0.2,
	SPEED_MUL_MIN = 0.75,
	SPEED_MUL_MAX = 1.25,

	-- 회전
	BASE_TURN_RATE = 75, -- 기수가 1초에 돌 수 있는 최대 각도
	MAX_AIM_PITCH = 80, -- 위아래 조준 한계
	MAX_BANK = 55, -- 돌 때 기울어지는 최대 각도
	BANK_GAIN = 1.2, -- 조준과 기수 차이 1도당 기울기
	BANK_SMOOTH = 5, -- 기울기가 따라오는 빠르기
	STEER_RESPONSIVENESS = 40, -- AlignOrientation 반응 속도 (높을수록 즉시)

	-- PC 조작
	MOUSE_SENSITIVITY = 0.0035, -- 마우스 1픽셀당 조준 회전 (라디안)
	KEY_TURN_RATE = 70, -- W/A/S/D 를 누르고 있을 때 1초에 도는 각도

	-- 모바일 조작
	STICK_TURN_RATE = 70, -- 스틱 끝까지 밀었을 때 1초에 도는 각도
	STICK_DEAD_ZONE = 0.12,

	-- 카메라
	CAMERA_DISTANCE = 30,
	CAMERA_HEIGHT = 8,
	CAMERA_LOOK_AHEAD = 60,
	CAMERA_FOV = 70,
	CAMERA_FOV_BOOST = 12, -- 최고 속도일 때 더해지는 시야각
	AIM_MARK_DISTANCE = 300, -- 조준점·기수 표시를 그리는 거리

	-- 충돌 피하기 (비행기는 벽을 뚫지 않고 미끄러진다)
	PROBE_RADIUS = 3,
	PROBE_MARGIN = 6,

	-- 허브 하늘의 경계
	WORLD_RADIUS = 1400,
	CEILING = 700,
	FLOOR = -300,

	-- 소환
	SPAWN_HEIGHT = 40, -- 타는 곳에서 이만큼 위에 비행기가 나타남
	REQUEST_COOLDOWN = 1, -- 타기/내리기 요청 간격

	-- 서버 속도 감시
	SPEED_TOLERANCE = 1.25, -- 최고 속도의 몇 배까지 봐줄지
	SPEED_STRIKES = 6, -- 0.5초마다 검사해서 이만큼 연속 넘으면 비행기 회수
}
