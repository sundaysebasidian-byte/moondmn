///|
/// Virtual paths are case-sensitive and never interpreted as URLs.
fn virtual_path(path : String) -> String raise @types.EngineError {
  if path.has_prefix("/") ||
    path.contains(":") ||
    path.contains("\\") ||
    path.contains("%") ||
    path.contains("?") ||
    path.contains("#") {
    raise @types.fail("E_IMPORT_PATH", "expected a relative virtual file path")
  }
  let parts : Array[String] = []
  for part in path.split("/") {
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      if parts.pop() is None {
        raise @types.fail(
          "E_IMPORT_PATH", "import escapes the virtual file table",
        )
      }
    } else {
      parts.push(part.to_owned())
    }
  }
  parts.join("/")
}

///|
fn request_model(
  req : Map[String, Json],
  xml : String,
) -> @model.Model raise Error {
  let files : Map[String, String] = Map([])
  match req.get("files") {
    None => ()
    Some(Object(entries)) =>
      for name, value in entries {
        let path = virtual_path(name)
        if path == "" || name.has_suffix("/") {
          raise bad_request("file name must identify a file")
        }
        if files.contains(path) {
          raise bad_request("duplicate virtual file name: " + path)
        }
        match value {
          String(text) => files[path] = text
          _ => raise bad_request("file contents must be strings")
        }
      }
    _ => raise bad_request("'files' must be an object")
  }
  let entry = match req.get("entry") {
    None => "main.dmn"
    Some(String(name)) => virtual_path(name)
    _ => raise bad_request("'entry' must be a string")
  }
  if entry == "" {
    raise bad_request("entry must identify a file")
  }
  let parts = entry.split("/").to_array()
  ignore(parts.pop())
  let base = if parts.is_empty() { "" } else { parts.join("/") + "/" }
  @model.parse_model(
    xml,
    resolver=Some((location, ns) => {
      // Validate before prepending the entry directory, so absolute paths and
      // URL schemes cannot turn into apparently relative names.
      ignore(virtual_path(location))
      let path = virtual_path(base + location)
      if location != "" && !location.has_suffix("/") {
        return match files.get(path) {
          Some(text) => text
          None =>
            raise @types.fail(
              "E_IMPORT_NOT_FOUND",
              "virtual file not found: " + path,
            )
        }
      }
      let directory = if path == "" { "" } else { path + "/" }
      let matches : Array[String] = []
      for name, text in files {
        if name.has_prefix(directory) &&
          !name[directory.length():].contains("/") &&
          name.has_suffix(".dmn") {
          let root = @xml.parse(text)
          if root.attr("namespace") == ns {
            matches.push(text)
          }
        }
      }
      if matches.length() != 1 {
        raise @types.fail(
          "E_IMPORT_NOT_FOUND",
          "expected one virtual model for namespace: " + ns,
        )
      }
      matches[0]
    }),
  )
}
