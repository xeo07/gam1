extends RefCounted
class_name NewspaperEdition

const MAX_ARTICLES := 5


static func create(issue_number: int, last_day: int, entries: Array[Dictionary]) -> Dictionary:
	var first_day := maxi(1, last_day - 6)
	var candidates: Array[Dictionary] = []
	for entry in entries:
		var entry_day := int(entry.get("day", 0))
		if entry_day < first_day or entry_day > last_day:
			continue
		if int(entry.get("importance", 1)) < 2:
			continue
		candidates.append(entry.duplicate(true))
	candidates.sort_custom(_comes_before)

	var articles: Array[Dictionary] = []
	for index in mini(candidates.size(), MAX_ARTICLES):
		articles.append(_create_article(candidates[index]))
	if articles.is_empty():
		articles.append({
			"source_id": "quiet:%d" % last_day,
			"day": last_day,
			"title": "Неделя прошла спокойно",
			"body": (
				"Гонцы не принесли в столицу известий о крупных потрясениях. "
				+ "Дворы соседних держав заняты привычными делами."
			),
			"participants": [],
			"reliability": &"reported",
			"importance": 1,
		})

	return {
		"issue_number": maxi(1, issue_number),
		"first_day": first_day,
		"last_day": maxi(first_day, last_day),
		"headline": String(articles[0]["title"]),
		"articles": articles,
	}


static func to_save_data(edition: Dictionary) -> Dictionary:
	var articles: Array[Dictionary] = []
	for article_value in edition.get("articles", []):
		if not article_value is Dictionary:
			continue
		var article: Dictionary = article_value
		var participants: Array[String] = []
		for participant in article.get("participants", []):
			participants.append(String(participant))
		articles.append({
			"source_id": String(article.get("source_id", "")),
			"day": int(article.get("day", 1)),
			"title": String(article.get("title", "")),
			"body": String(article.get("body", "")),
			"participants": participants,
			"reliability": String(article.get("reliability", &"reported")),
			"importance": int(article.get("importance", 1)),
		})
	return {
		"issue_number": int(edition.get("issue_number", 1)),
		"first_day": int(edition.get("first_day", 1)),
		"last_day": int(edition.get("last_day", 1)),
		"headline": String(edition.get("headline", "")),
		"articles": articles,
	}


static func parse_save_data(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all(["issue_number", "first_day", "last_day", "headline", "articles"]):
		return {"valid": false}
	for field in ["issue_number", "first_day", "last_day"]:
		if not _is_integer(data[field]):
			return {"valid": false}
	if not data["headline"] is String or not data["articles"] is Array:
		return {"valid": false}
	if int(data["issue_number"]) < 1 or int(data["first_day"]) < 1:
		return {"valid": false}
	if int(data["last_day"]) < int(data["first_day"]):
		return {"valid": false}
	if String(data["headline"]).is_empty() or data["articles"].is_empty():
		return {"valid": false}

	var articles: Array[Dictionary] = []
	for article_value in data["articles"]:
		var parsed_article := _parse_article(article_value)
		if not bool(parsed_article.get("valid", false)):
			return {"valid": false}
		var article: Dictionary = parsed_article["article"]
		if int(article["day"]) < int(data["first_day"]):
			return {"valid": false}
		if int(article["day"]) > int(data["last_day"]):
			return {"valid": false}
		articles.append(article)
	if articles.size() > MAX_ARTICLES:
		return {"valid": false}
	return {
		"valid": true,
		"edition": {
			"issue_number": int(data["issue_number"]),
			"first_day": int(data["first_day"]),
			"last_day": int(data["last_day"]),
			"headline": String(data["headline"]),
			"articles": articles,
		},
	}


static func _create_article(entry: Dictionary) -> Dictionary:
	var participants: Array[StringName] = []
	for participant in entry.get("participants", []):
		participants.append(StringName(participant))
	return {
		"source_id": String(entry.get("id", "")),
		"day": int(entry.get("day", 1)),
		"title": String(entry.get("title", "Без заголовка")),
		"body": String(entry.get("summary", "Подробности пока неизвестны.")),
		"participants": participants,
		"reliability": StringName(entry.get("reliability", &"reported")),
		"importance": int(entry.get("importance", 1)),
	}


static func _parse_article(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"valid": false}
	var data: Dictionary = value
	if not data.has_all([
		"source_id", "day", "title", "body", "participants", "reliability", "importance",
	]):
		return {"valid": false}
	for field in ["source_id", "title", "body", "reliability"]:
		if not data[field] is String:
			return {"valid": false}
	if not data["participants"] is Array:
		return {"valid": false}
	if not _is_integer(data["day"]) or not _is_integer(data["importance"]):
		return {"valid": false}
	if String(data["source_id"]).is_empty() or String(data["title"]).is_empty():
		return {"valid": false}
	if String(data["body"]).is_empty() or int(data["day"]) < 1:
		return {"valid": false}
	if int(data["importance"]) < 1 or int(data["importance"]) > 3:
		return {"valid": false}
	var reliability := StringName(data["reliability"])
	if reliability not in EventJournalEntry.VALID_RELIABILITY:
		return {"valid": false}
	var participants: Array[StringName] = []
	for participant in data["participants"]:
		if not participant is String or String(participant).is_empty():
			return {"valid": false}
		participants.append(StringName(participant))
	return {
		"valid": true,
		"article": {
			"source_id": String(data["source_id"]),
			"day": int(data["day"]),
			"title": String(data["title"]),
			"body": String(data["body"]),
			"participants": participants,
			"reliability": reliability,
			"importance": int(data["importance"]),
		},
	}


static func _comes_before(left: Dictionary, right: Dictionary) -> bool:
	var left_importance := int(left.get("importance", 1))
	var right_importance := int(right.get("importance", 1))
	if left_importance != right_importance:
		return left_importance > right_importance
	var left_day := int(left.get("day", 0))
	var right_day := int(right.get("day", 0))
	if left_day != right_day:
		return left_day > right_day
	return String(left.get("id", "")) < String(right.get("id", ""))


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and value == floor(value))
