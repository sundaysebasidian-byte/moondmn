///|
/// File loader for CLI/TCK. Imports are confined lexically to the model tree.
pub fn load(path : String) -> @model.Model raise @types.EngineError {
  let parts = model_path(path).split("/").to_array()
  ignore(parts.pop())
  let base = if parts.is_empty() { "." } else { parts.join("/") }
  let source = read(path)
  @model.parse_model(
    source,
    resolver=Some((location, ns) => {
      if location.has_prefix("/") ||
        location.contains(":") ||
        location.contains("\\") ||
        location.split("/").any(p => p == "..") {
        raise @types.fail(
          "E_IMPORT_PATH",
          "import must stay within the model directory: " + location,
        )
      }
      if location != "" && !location.has_suffix("/") {
        check_path(base, location)
        return read(base + "/" + location, display=location)
      }
      check_path(base, location)
      let directory = base + "/" + location
      let files = @fs.read_dir(directory).to_owned() catch {
        _ =>
          raise @types.fail(
            "E_IMPORT_NOT_FOUND", "cannot read import directory",
          )
      }
      let matches : Array[String] = []
      for file in files {
        if !file.has_suffix(".dmn") {
          continue
        }
        check_path(base, location + "/" + file)
        let text = read(directory + "/" + file, display=location + file)
        let root = @xml.parse(text)
        if root.attr("namespace") == ns {
          matches.push(text)
        }
      }
      if matches.length() != 1 {
        raise @types.fail(
          "E_IMPORT_NOT_FOUND",
          "expected one model for namespace: " + ns,
        )
      }
      matches[0]
    }),
  )
}

///|
fn read(
  path : String,
  display~ : String = path,
) -> String raise @types.EngineError {
  let source = try {
    if @fs.is_file(path) {
      Some(@fs.read_file_to_string(path))
    } else {
      None
    }
  } catch {
    _ => None
  }
  match source {
    Some(source) => source
    None =>
      raise @types.fail("E_IMPORT_NOT_FOUND", "cannot read model: " + display)
  }
}

///|
#cfg(platform="windows")
fn model_path(path : String) -> String {
  // CLI paths use host separators; import locations still require URI slashes.
  path.replace_all(old="\\", new="/")
}

///|
#cfg(not(platform="windows"))
fn model_path(path : String) -> String {
  path
}

///|
fn check_path(
  base : String,
  relative : String,
) -> Unit raise @types.EngineError {
  let mut path = base
  for part in relative.split("/") {
    if part == "" || part == "." {
      continue
    }
    path = path + "/" + part.to_owned()
    let state = path_link(@utf8.encode(path) + b"\x00")
    if state == -2 {
      raise @types.fail(
        "E_IMPORT_PATH", "file imports require native or js; use a host resolver on wasm",
      )
    }
    if state < 0 {
      raise @types.fail(
        "E_IMPORT_NOT_FOUND",
        "import path not found: " + relative,
      )
    }
    if state > 0 {
      raise @types.fail(
        "E_IMPORT_PATH",
        "import path is missing or traverses a symbolic link: " + relative,
      )
    }
  }
}
