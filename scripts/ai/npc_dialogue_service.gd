class_name NpcDialogueService
extends RefCounted

func select_line(
	archetype: StringName,
	category: StringName,
	rng: CentralRng
) -> String:
	var pool: PackedStringArray = _pool_for(archetype, category)
	if pool.is_empty():
		return "..."
	return pool[rng.choose_index(pool.size())]

func _pool_for(archetype: StringName, category: StringName) -> PackedStringArray:
	match archetype:
		GameConstants.ARCHETYPE_COLLECTOR:
			return _collector_pool(category)
		GameConstants.ARCHETYPE_CREDITOR:
			return _creditor_pool(category)
		GameConstants.ARCHETYPE_GAMBLER:
			return _gambler_pool(category)
		_:
			return PackedStringArray(["조금 더 지켜보지."])

func _collector_pool(category: StringName) -> PackedStringArray:
	match category:
		&"strong_preference":
			return PackedStringArray(["저런 물건은 다시 보기 힘들겠군.", "상태와 별개로 소장 가치는 충분해."])
		&"interest":
			return PackedStringArray(["상태는 나빠 보여도 눈길은 가는군.", "그 정도 가격이라면 아직 싸군."])
		&"caution":
			return PackedStringArray(["진품인지부터 의심스럽군.", "소장고 자리를 내줄 정도인지는 모르겠어."])
		&"price_pressure":
			return PackedStringArray(["희귀해도 저 가격은 과해.", "수집 가치보다 호가가 앞섰군."])
		_:
			return PackedStringArray(["이번 물건은 보내주지.", "내 목록에는 맞지 않는군."])

func _creditor_pool(category: StringName) -> PackedStringArray:
	match category:
		&"strong_preference":
			return PackedStringArray(["현금 흐름은 꽤 설득력 있군.", "조건만 맞으면 훌륭한 담보가 되겠어."])
		&"interest":
			return PackedStringArray(["수익 구조가 분명해야 움직이지.", "대가는 나중 문제고, 흐름은 나쁘지 않군."])
		&"caution":
			return PackedStringArray(["불명확한 위험에는 이자를 더 붙여야지.", "장부에 적기엔 변수가 너무 많아."])
		&"price_pressure":
			return PackedStringArray(["이 가격부터는 담보 가치가 부족해.", "수익보다 원금 부담이 커졌군."])
		_:
			return PackedStringArray(["계산이 맞지 않아.", "이번 거래는 접지."])

func _gambler_pool(category: StringName) -> PackedStringArray:
	match category:
		&"strong_preference":
			return PackedStringArray(["위험할수록 판돈을 올려야지.", "안전한 물건은 재미가 없지."])
		&"interest":
			return PackedStringArray(["위험하긴 해도, 이 정도면 걸 만하지.", "이번 판은 냄새가 좋아."])
		&"caution":
			return PackedStringArray(["흐음, 꽝일 수도 있겠는데.", "지금은 패를 더 봐야겠어."])
		&"bluff":
			return PackedStringArray(["여기서 빠지면 평생 후회할걸.", "다들 겁먹었나? 난 더 올리지.", "이 물건, 생각보다 훨씬 커."])
		&"price_pressure":
			return PackedStringArray(["재미값 치고는 너무 비싸군.", "판돈이 내 계산을 넘어섰어."])
		_:
			return PackedStringArray(["이번 판은 접지.", "운은 다음에 시험하겠어."])
