///|
fn operations(document : Value) -> Map[String, Value] raise {
  let version = str(get(document, "openapi"))
  if !version.has_prefix("3.0.") {
    raise InputError("this profile supports OpenAPI 3.0 JSON")
  }
  let result : Map[String, Value] = Map([])
  for path, item in obj(get(document, "paths")) {
    if !path.has_prefix("/") {
      raise InputError("operation path must be absolute")
    }
    for
      method in [
        "get", "post", "put", "patch", "delete", "head", "options", "trace",
      ] {
      if get(item, method) != Null {
        let op = obj(get(item, method)).copy()
        let parameters = if get(item, "parameters") == Null {
          []
        } else {
          arr(get(item, "parameters"))
        }
        let overrides = if get(Object(op), "parameters") == Null {
          []
        } else {
          arr(op["parameters"])
        }
        let merged : Map[String, Value] = Map([])
        for raw in parameters + overrides {
          let parameter = if get(raw, "$ref") == Null {
            raw
          } else {
            pointer(document, str(get(raw, "$ref")))
          }
          merged[str(get(parameter, "in")) + ":" + str(get(parameter, "name"))] = parameter
        }
        op["parameters"] = Array(merged.values().collect())
        result[method + " " + path] = Object(op)
      }
    }
  }
  result
}

///|
fn json_body(
  state : Validation,
  definition : Value,
  value : Value,
  path : String,
) -> Unit raise {
  let media = get(get(definition, "content"), "application/json")
  if media == Null {
    if get(definition, "content") != Null {
      state.unchecked.push(
        record([("path", String(path)), ("keyword", String("non-JSON media"))]),
      )
    }
    return
  }
  if get(media, "schema") != Null {
    state.schema(get(media, "schema"), value, path, 0)
  }
}

///|
pub fn verify_case(document : Value, case : Value) -> Value raise {
  let key = str(get(case, "method")).to_lower() + " " + str(get(case, "path"))
  let operation = match operations(document).get(key) {
    Some(op) => op
    None => raise InputError("operation not found: " + key)
  }
  let state = Validation::{
    document,
    issues: [],
    unchecked: [],
    remaining: 100000,
  }
  for parameter in arr(get(operation, "parameters")) {
    let name = str(get(parameter, "name"))
    let location = str(get(parameter, "in"))
    let values = get(
      case,
      if location == "path" {
        "path_parameters"
      } else {
        location
      },
    )
    let present = match values {
      Object(fields) => fields.contains(name)
      _ => false
    }
    if !present {
      if get(parameter, "required") == Bool(true) || location == "path" {
        state.issue("request/" + location + "/" + name, "required")
      }
    } else if get(parameter, "schema") != Null {
      state.schema(
        get(parameter, "schema"),
        get(values, name),
        "request/" + location + "/" + name,
        0,
      )
    }
  }
  let body = get(operation, "requestBody")
  if body != Null {
    let definition = if get(body, "$ref") == Null {
      body
    } else {
      pointer(document, str(get(body, "$ref")))
    }
    if !obj(case).contains("body") {
      if get(definition, "required") == Bool(true) {
        state.issue("request/body", "required")
      }
    } else {
      json_body(state, definition, get(case, "body"), "request/body")
    }
  }
  let response = get(case, "response")
  if response != Null {
    let status = num(get(response, "status"))
    if status.floor() != status || status < 100.0 || status > 599.0 {
      raise InputError("invalid HTTP status")
    }
    let responses = obj(get(operation, "responses"))
    let definition = responses
      .get(status.to_int().to_string())
      .unwrap_or(responses.get("default").unwrap_or(Null))
    if definition == Null {
      state.issue("response/status", "undeclared status")
    } else {
      let definition = if get(definition, "$ref") == Null {
        definition
      } else {
        pointer(document, str(get(definition, "$ref")))
      }
      if get(definition, "headers") != Null {
        state.unchecked.push(
          record([
            ("path", String("response/headers")),
            ("keyword", String("response header constraints")),
          ]),
        )
      }
      if status == 204.0 && get(response, "body") != Null {
        state.issue("response/body", "204 must have no body")
      } else {
        json_body(state, definition, get(response, "body"), "response/body")
      }
    }
  }
  record([
    ("operation", String(key)),
    ("valid", Bool(state.issues.is_empty())),
    ("complete", Bool(state.unchecked.is_empty())),
    ("issues", Array(state.issues)),
    ("unchecked", Array(state.unchecked)),
  ])
}

///|
fn compatibility(old : Value, new : Value) -> Value raise {
  let before = operations(old)
  let after = operations(new)
  let changes : Array[Value] = []
  let keys = before.keys().collect()
  keys.sort()
  for key in keys {
    let a = before[key]
    match after.get(key) {
      None =>
        changes.push(
          record([
            ("operation", String(key)),
            ("classification", String("breaking")),
            ("reason", String("operation removed")),
          ]),
        )
      Some(b) =>
        if a != b {
          let old_parameters : Map[String, Value] = Map([])
          for p in arr(get(a, "parameters")) {
            old_parameters[str(get(p, "in")) + ":" + str(get(p, "name"))] = p
          }
          let mut breaking = false
          for p in arr(get(b, "parameters")) {
            let id = str(get(p, "in")) + ":" + str(get(p, "name"))
            if get(p, "required") == Bool(true) &&
              get(old_parameters.get(id).unwrap_or(Null), "required") !=
              Bool(true) {
              breaking = true
            }
          }
          if get(get(b, "requestBody"), "required") == Bool(true) &&
            get(get(a, "requestBody"), "required") != Bool(true) {
            breaking = true
          }
          changes.push(
            record([
              ("operation", String(key)),
              (
                "classification",
                String(if breaking { "breaking" } else { "review" }),
              ),
              (
                "reason",
                String(
                  if breaking {
                    "new required request input"
                  } else {
                    "changed schema or operation requires semantic review"
                  },
                ),
              ),
            ]),
          )
        }
    }
  }
  let added = after.keys().filter(fn(key) { !before.contains(key) }).collect()
  added.sort()
  for key in added {
    changes.push(
      record([
        ("operation", String(key)),
        ("classification", String("additive")),
        ("reason", String("operation added")),
      ]),
    )
  }
  record([
    ("changes", Array(changes)),
    (
      "breaking",
      Bool(
        changes.any(fn(c) { get(c, "classification") == String("breaking") }),
      ),
    ),
    (
      "needs_review",
      Bool(changes.any(fn(c) { get(c, "classification") == String("review") })),
    ),
  ])
}

///|
pub fn run(request : Value) -> Value raise {
  match optional_str(get(request, "operation"), "verify") {
    "schema" =>
      validate_schema(
        get(request, "document"),
        get(request, "schema"),
        get(request, "value"),
      )
    "diff" => compatibility(get(request, "old"), get(request, "new"))
    "verify" => {
      let document = get(request, "document")
      let cases = arr(get(request, "cases"))
      let results = cases.map(fn(case) { verify_case(document, case) })
      record([
        ("results", Array(results)),
        ("valid", Bool(results.all(fn(r) { get(r, "valid") == Bool(true) }))),
        (
          "complete",
          Bool(results.all(fn(r) { get(r, "complete") == Bool(true) })),
        ),
      ])
    }
    _ => raise InputError("unknown contract operation")
  }
}
