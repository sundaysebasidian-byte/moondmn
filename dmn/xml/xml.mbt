///|
pub struct Node {
  name : String
  uri : String
  attributes : Map[String, String]
  children : Array[Node]
  mut text : String
  line : Int32
  column : Int32
}

///|
pub fn Node::attr(n : Node, key : String) -> String {
  n.attributes.get(key).unwrap_or("")
}

///|
pub fn Node::all(n : Node, name : String) -> Array[Node] {
  n.children.filter(x => x.name == name && x.uri == n.uri)
}

///|
pub fn Node::child(n : Node, name : String) -> Node? {
  n.all(name).get(0)
}

///|
pub fn Node::content(n : Node, name : String) -> String {
  match n.child(name) {
    Some(v) => v.text.trim().to_owned()
    None => ""
  }
}

///|
fn node(e : @upstream.NamespaceElement, line : Int32, column : Int32) -> Node {
  let attributes = Map([])
  for a in e.attributes {
    if a.name.namespace_uri is None {
      attributes[a.name.local_name] = a.value
    } else {
      attributes[a.name.qualified_name] = a.value
    }
  }
  {
    name: e.name.local_name,
    uri: e.name.namespace_uri.unwrap_or(""),
    attributes,
    children: [],
    text: "",
    line,
    column,
  }
}

///|
pub fn parse(source : String) -> Node raise @types.EngineError {
  if source.length() > 10000000 {
    raise @types.fail("E_LIMIT", "XML exceeds 10MB")
  }
  let reader = @upstream.NamespaceReader::from_string(source)
  let stack : Array[Node] = []
  let mut root : Node? = None
  while true {
    let ev = reader.read_event() catch {
      @upstream.At(error~, span~) =>
        raise @types.Failure(
          "E_XML",
          span.start.line,
          span.start.column,
          error.to_string(),
        )
    }
    match ev.kind {
      Start(e) | Empty(e) => {
        let n = node(e, ev.span.start.line, ev.span.start.column)
        if stack.length() == 0 {
          root = Some(n)
        } else {
          stack[stack.length() - 1].children.push(n)
        }
        if ev.kind is Start(_) {
          stack.push(n)
        }
        if stack.length() > 128 {
          raise @types.fail("E_LIMIT", "XML nesting exceeds 128")
        }
      }
      End(_) => ignore(stack.pop())
      Text(t) | CData(t) =>
        if stack.length() > 0 {
          let n = stack[stack.length() - 1]
          n.text = n.text + t
        }
      DocType(_) =>
        raise @types.Failure(
          "E_XML_DTD",
          ev.span.start.line,
          ev.span.start.column,
          "DTD forbidden",
        )
      Eof => break
      _ => ()
    }
  }
  match root {
    Some(n) => n
    None => raise @types.fail("E_XML", "empty document")
  }
}
