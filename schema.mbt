///|
fn pointer(root : Value, path : String) -> Value raise {
  if !path.has_prefix("#/") {
    raise InputError("only local JSON references are supported")
  }
  let mut value = root
  for segment in path.substring(start=2).split("/") {
    let key = segment
      .to_string()
      .replace(old="~1", new="/")
      .replace(old="~0", new="~")
    value = match value {
      Object(fields) =>
        match fields.get(key) {
          Some(v) => v
          None => raise InputError("reference does not exist: " + path)
        }
      _ => raise InputError("reference traverses a non-object")
    }
  }
  value
}

///|
fn value_type(value : Value) -> String {
  match value {
    Null => "null"
    Bool(_) => "boolean"
    Number(n) => if n.floor() == n { "integer" } else { "number" }
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
struct Validation {
  document : Value
  issues : Array[Value]
  unchecked : Array[Value]
  mut remaining : Int
}

///|
fn Validation::issue(self : Validation, path : String, code : String) -> Unit {
  self.issues.push(record([("path", String(path)), ("code", String(code))]))
}

///|
fn Validation::schema(
  self : Validation,
  schema : Value,
  value : Value,
  path : String,
  depth : Int,
) -> Unit raise {
  self.remaining -= 1
  if self.remaining < 0 || depth > 64 {
    raise InputError("schema validation budget exhausted")
  }
  ignore(obj(schema))
  if get(schema, "$ref") != Null {
    self.schema(
      pointer(self.document, str(get(schema, "$ref"))),
      value,
      path,
      depth + 1,
    )
    return
  }
  let supported = [
    "type", "nullable", "enum", "allOf", "anyOf", "oneOf", "required", "properties",
    "additionalProperties", "minProperties", "maxProperties", "items", "minItems",
    "maxItems", "uniqueItems", "minLength", "maxLength", "minimum", "maximum", "exclusiveMinimum",
    "exclusiveMaximum", "multipleOf", "title", "description", "default", "example",
    "deprecated", "externalDocs",
  ]
  for keyword, _ in obj(schema) {
    if !supported.contains(keyword) && !keyword.has_prefix("x-") {
      self.unchecked.push(
        record([("path", String(path)), ("keyword", String(keyword))]),
      )
    }
  }
  if value == Null && get(schema, "nullable") == Bool(true) {
    return
  }
  let expected = optional_str(get(schema, "type"), "any")
  let actual = value_type(value)
  if expected != "any" &&
    expected != actual &&
    !(expected == "number" && actual == "integer") {
    self.issue(path, "type")
    return
  }
  if get(schema, "enum") != Null && !arr(get(schema, "enum")).contains(value) {
    self.issue(path, "enum")
  }
  if get(schema, "allOf") != Null {
    for sub in arr(get(schema, "allOf")) {
      self.schema(sub, value, path, depth + 1)
    }
  }
  for keyword in ["anyOf", "oneOf"] {
    if get(schema, keyword) != Null {
      let alternatives = arr(get(schema, keyword))
      if alternatives.is_empty() {
        raise InputError("empty schema alternatives")
      }
      let mut matches = 0
      for sub in alternatives {
        let branch = Validation::{
          document: self.document,
          issues: [],
          unchecked: [],
          remaining: self.remaining,
        }
        branch.schema(sub, value, path, depth + 1)
        self.remaining = branch.remaining
        self.unchecked.append(branch.unchecked)
        if branch.issues.is_empty() {
          matches += 1
        }
      }
      if matches == 0 || (keyword == "oneOf" && matches != 1) {
        self.issue(path, keyword)
      }
    }
  }
  match value {
    Object(fields) => {
      let required = if get(schema, "required") == Null {
        []
      } else {
        string_list(get(schema, "required"))
      }
      for key in required {
        if !fields.contains(key) {
          self.issue(path + "/" + key, "required")
        }
      }
      let properties = if get(schema, "properties") == Null {
        Map([])
      } else {
        obj(get(schema, "properties"))
      }
      for key, child in fields {
        match properties.get(key) {
          Some(sub) => self.schema(sub, child, path + "/" + key, depth + 1)
          None =>
            match get(schema, "additionalProperties") {
              Bool(false) =>
                self.issue(path + "/" + key, "additionalProperties")
              Object(_) as sub =>
                self.schema(sub, child, path + "/" + key, depth + 1)
              _ => ()
            }
        }
      }
      self.bounds(
        schema,
        fields.size().to_double(),
        path,
        "minProperties",
        "maxProperties",
      )
    }
    Array(items) => {
      self.bounds(
        schema,
        items.length().to_double(),
        path,
        "minItems",
        "maxItems",
      )
      let seen : Map[String, Bool] = Map([])
      for i = 0; i < items.length(); i = i + 1 {
        if get(schema, "items") != Null {
          self.schema(
            get(schema, "items"),
            items[i],
            path + "/" + i.to_string(),
            depth + 1,
          )
        }
        let key = canonical(items[i])
        if get(schema, "uniqueItems") == Bool(true) && seen.contains(key) {
          self.issue(path, "uniqueItems")
        }
        seen[key] = true
      }
    }
    String(text) =>
      self.bounds(
        schema,
        text.to_array().length().to_double(),
        path,
        "minLength",
        "maxLength",
      )
    Number(n) => {
      self.bounds(schema, n, path, "minimum", "maximum")
      if get(schema, "exclusiveMinimum") == Bool(true) &&
        get(schema, "minimum") != Null &&
        n == num(get(schema, "minimum")) {
        self.issue(path, "exclusiveMinimum")
      }
      if get(schema, "exclusiveMaximum") == Bool(true) &&
        get(schema, "maximum") != Null &&
        n == num(get(schema, "maximum")) {
        self.issue(path, "exclusiveMaximum")
      }
      if get(schema, "multipleOf") != Null {
        let divisor = num(get(schema, "multipleOf"))
        if divisor <= 0.0 {
          raise InputError("multipleOf must be positive")
        }
        let quotient = n / divisor
        if (quotient - quotient.round()).abs() > 0.000000001 {
          self.issue(path, "multipleOf")
        }
      }
    }
    _ => ()
  }
}

///|
fn Validation::bounds(
  self : Validation,
  schema : Value,
  n : Double,
  path : String,
  lower : String,
  upper : String,
) -> Unit raise {
  if get(schema, lower) != Null && n < num(get(schema, lower)) {
    self.issue(path, lower)
  }
  if get(schema, upper) != Null && n > num(get(schema, upper)) {
    self.issue(path, upper)
  }
}

///|
pub fn validate_schema(
  document : Value,
  schema : Value,
  value : Value,
) -> Value raise {
  let state = Validation::{
    document,
    issues: [],
    unchecked: [],
    remaining: 100000,
  }
  state.schema(schema, value, "", 0)
  record([
    ("valid", Bool(state.issues.is_empty())),
    ("complete", Bool(state.unchecked.is_empty())),
    ("issues", Array(state.issues)),
    ("unchecked", Array(state.unchecked)),
  ])
}
