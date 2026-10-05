# Request and result guide

Every example below is an executable fixture. Assertions cover the listed result fields; additional output fields are documented by the API and other fixtures. Error cases intentionally reject the request.

## response contract

```json
{
  "document": {
    "openapi": "3.0.3",
    "paths": {
      "/items": {
        "get": {
          "parameters": [
            {
              "name": "limit",
              "in": "query",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "content": {
                "application/json": {
                  "schema": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Item"
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "components": {
      "schemas": {
        "Item": {
          "type": "object",
          "required": [
            "id"
          ],
          "properties": {
            "id": {
              "type": "integer"
            }
          },
          "additionalProperties": false
        }
      }
    }
  },
  "cases": [
    {
      "method": "GET",
      "path": "/items",
      "query": {
        "limit": 2
      },
      "response": {
        "status": 200,
        "body": [
          {
            "id": 1
          }
        ]
      }
    }
  ]
}
```

Expected result fields:

```json
{
  "valid": true,
  "complete": true
}
```

## response and request failures

```json
{
  "document": {
    "openapi": "3.0.3",
    "paths": {
      "/items": {
        "get": {
          "parameters": [
            {
              "name": "limit",
              "in": "query",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "content": {
                "application/json": {
                  "schema": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Item"
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "components": {
      "schemas": {
        "Item": {
          "type": "object",
          "required": [
            "id"
          ],
          "properties": {
            "id": {
              "type": "integer"
            }
          },
          "additionalProperties": false
        }
      }
    }
  },
  "cases": [
    {
      "method": "get",
      "path": "/items",
      "query": {
        "limit": 0
      },
      "response": {
        "status": 200,
        "body": [
          {
            "id": "wrong"
          }
        ]
      }
    }
  ]
}
```

Expected result fields:

```json
{
  "valid": false
}
```

## unsupported is incomplete

```json
{
  "operation": "schema",
  "document": {},
  "schema": {
    "type": "string",
    "pattern": "^[a-z]+$"
  },
  "value": "123"
}
```

Expected result fields:

```json
{
  "valid": true,
  "complete": false
}
```

## oneOf ambiguity

```json
{
  "operation": "schema",
  "document": {},
  "schema": {
    "oneOf": [
      {
        "type": "number"
      },
      {
        "type": "integer"
      }
    ]
  },
  "value": 1
}
```

Expected result fields:

```json
{
  "valid": false
}
```

## nullable

```json
{
  "operation": "schema",
  "document": {},
  "schema": {
    "type": "string",
    "nullable": true
  },
  "value": null
}
```

Expected result fields:

```json
{
  "valid": true
}
```

## operation removal

```json
{
  "operation": "diff",
  "old": {
    "openapi": "3.0.3",
    "paths": {
      "/items": {
        "get": {
          "parameters": [
            {
              "name": "limit",
              "in": "query",
              "required": true,
              "schema": {
                "type": "integer",
                "minimum": 1
              }
            }
          ],
          "responses": {
            "200": {
              "content": {
                "application/json": {
                  "schema": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Item"
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "components": {
      "schemas": {
        "Item": {
          "type": "object",
          "required": [
            "id"
          ],
          "properties": {
            "id": {
              "type": "integer"
            }
          },
          "additionalProperties": false
        }
      }
    }
  },
  "new": {
    "openapi": "3.0.3",
    "paths": {}
  }
}
```

Expected result fields:

```json
{
  "breaking": true
}
```

## external reference refused

```json
{
  "operation": "schema",
  "document": {},
  "schema": {
    "$ref": "https://example.test/schema"
  },
  "value": 1
}
```

Expected: nonzero exit with an input error.

## unique array

```json
{
  "operation": "schema",
  "document": {},
  "schema": {
    "type": "array",
    "uniqueItems": true
  },
  "value": [
    {
      "n": 1
    },
    {
      "n": 1
    }
  ]
}
```

Expected result fields:

```json
{
  "valid": false
}
```

## Host adapter

```sh
node scripts/http.mjs examples/contract.json examples/http-cases.json http://127.0.0.1:8080
```

Read the current boundaries before using this adapter.
