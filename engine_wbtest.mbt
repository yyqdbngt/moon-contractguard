///|
fn test_at(value : Value, parts : Array[String]) -> Value raise {
  let mut current = value
  for part in parts {
    current = match current {
      Object(fields) =>
        match fields.get(part) {
          Some(v) => v
          None => raise InputError("test key missing: " + part)
        }
      Array(items) => items[num(parse_value(part)).to_int()]
      _ => raise InputError("invalid test traversal")
    }
  }
  current
}

///|
test "response contract" {
  let result = run(
    parse_value(
      "{\"document\":{\"openapi\":\"3.0.3\",\"paths\":{\"/items\":{\"get\":{\"parameters\":[{\"name\":\"limit\",\"in\":\"query\",\"required\":true,\"schema\":{\"type\":\"integer\",\"minimum\":1}}],\"responses\":{\"200\":{\"content\":{\"application/json\":{\"schema\":{\"type\":\"array\",\"items\":{\"$ref\":\"#/components/schemas/Item\"}}}}}}}}},\"components\":{\"schemas\":{\"Item\":{\"type\":\"object\",\"required\":[\"id\"],\"properties\":{\"id\":{\"type\":\"integer\"}},\"additionalProperties\":false}}}},\"cases\":[{\"method\":\"GET\",\"path\":\"/items\",\"query\":{\"limit\":2},\"response\":{\"status\":200,\"body\":[{\"id\":1}]}}]}",
    ),
  )
  assert_eq(test_at(result, ["valid"]), parse_value("true"))
  assert_eq(test_at(result, ["complete"]), parse_value("true"))
}

///|
test "response and request failures" {
  let result = run(
    parse_value(
      "{\"document\":{\"openapi\":\"3.0.3\",\"paths\":{\"/items\":{\"get\":{\"parameters\":[{\"name\":\"limit\",\"in\":\"query\",\"required\":true,\"schema\":{\"type\":\"integer\",\"minimum\":1}}],\"responses\":{\"200\":{\"content\":{\"application/json\":{\"schema\":{\"type\":\"array\",\"items\":{\"$ref\":\"#/components/schemas/Item\"}}}}}}}}},\"components\":{\"schemas\":{\"Item\":{\"type\":\"object\",\"required\":[\"id\"],\"properties\":{\"id\":{\"type\":\"integer\"}},\"additionalProperties\":false}}}},\"cases\":[{\"method\":\"get\",\"path\":\"/items\",\"query\":{\"limit\":0},\"response\":{\"status\":200,\"body\":[{\"id\":\"wrong\"}]}}]}",
    ),
  )
  assert_eq(test_at(result, ["valid"]), parse_value("false"))
}

///|
test "unsupported is incomplete" {
  let result = run(
    parse_value(
      "{\"operation\":\"schema\",\"document\":{},\"schema\":{\"type\":\"string\",\"pattern\":\"^[a-z]+$\"},\"value\":\"123\"}",
    ),
  )
  assert_eq(test_at(result, ["valid"]), parse_value("true"))
  assert_eq(test_at(result, ["complete"]), parse_value("false"))
}

///|
test "oneOf ambiguity" {
  let result = run(
    parse_value(
      "{\"operation\":\"schema\",\"document\":{},\"schema\":{\"oneOf\":[{\"type\":\"number\"},{\"type\":\"integer\"}]},\"value\":1}",
    ),
  )
  assert_eq(test_at(result, ["valid"]), parse_value("false"))
}

///|
test "nullable" {
  let result = run(
    parse_value(
      "{\"operation\":\"schema\",\"document\":{},\"schema\":{\"type\":\"string\",\"nullable\":true},\"value\":null}",
    ),
  )
  assert_eq(test_at(result, ["valid"]), parse_value("true"))
}

///|
test "operation removal" {
  let result = run(
    parse_value(
      "{\"operation\":\"diff\",\"old\":{\"openapi\":\"3.0.3\",\"paths\":{\"/items\":{\"get\":{\"parameters\":[{\"name\":\"limit\",\"in\":\"query\",\"required\":true,\"schema\":{\"type\":\"integer\",\"minimum\":1}}],\"responses\":{\"200\":{\"content\":{\"application/json\":{\"schema\":{\"type\":\"array\",\"items\":{\"$ref\":\"#/components/schemas/Item\"}}}}}}}}},\"components\":{\"schemas\":{\"Item\":{\"type\":\"object\",\"required\":[\"id\"],\"properties\":{\"id\":{\"type\":\"integer\"}},\"additionalProperties\":false}}}},\"new\":{\"openapi\":\"3.0.3\",\"paths\":{}}}",
    ),
  )
  assert_eq(test_at(result, ["breaking"]), parse_value("true"))
}

///|
test "external reference refused" {
  let failed = try {
    ignore(
      run(
        parse_value(
          "{\"operation\":\"schema\",\"document\":{},\"schema\":{\"$ref\":\"https://example.test/schema\"},\"value\":1}",
        ),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "unique array" {
  let result = run(
    parse_value(
      "{\"operation\":\"schema\",\"document\":{},\"schema\":{\"type\":\"array\",\"uniqueItems\":true},\"value\":[{\"n\":1},{\"n\":1}]}",
    ),
  )
  assert_eq(test_at(result, ["valid"]), parse_value("false"))
}
