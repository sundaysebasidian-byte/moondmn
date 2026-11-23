///|
/// Namespace-aware XML node with source location and ordered children.
pub struct Node {
  name : String
  uri : String
  attributes : Map[String, String]
  priv expanded_attributes : Map[String, String]?
  priv namespace_prefixes : Map[String, String]
  children : Array[Node]
  mut text : String
  line : Int32
  column : Int32
}

///|
/// Return an attribute value, or the empty string if absent.
pub fn Node::attr(n : Node, key : String) -> String {
  n.attributes.get(key).unwrap_or("")
}

///|
/// Return an attribute by its namespace URI and local name.
pub fn Node::attr_namespace(n : Node, uri : String, name : String) -> String? {
  match n.expanded_attributes {
    Some(attributes) => attributes.get(uri + "#" + name)
    None => None
  }
}

///|
/// Return direct children matching this node namespace and local name.
pub fn Node::all(n : Node, name : String) -> Array[Node] {
  n.children.filter(x => x.name == name && x.uri == n.uri)
}

///|
/// Return the first direct child matching namespace and local name.
pub fn Node::child(n : Node, name : String) -> Node? {
  for child in n.children {
    if child.name == name && child.uri == n.uri {
      return Some(child)
    }
  }
  None
}

///|
/// Return the text of the first matching direct child, or the empty string.
pub fn Node::content(n : Node, name : String) -> String {
  match n.child(name) {
    Some(v) => v.text.trim().to_owned()
    None => ""
  }
}

///|
/// Resolve an in-scope prefix; an empty prefix denotes the default.
pub fn Node::namespace_uri(n : Node, prefix : String) -> String? {
  if prefix == "xml" {
    Some("http://www.w3.org/XML/1998/namespace")
  } else {
    n.namespace_prefixes.get(prefix)
  }
}

///|
fn node(
  e : @upstream.NamespaceElement,
  namespace_prefixes : Map[String, String],
  line : Int32,
  column : Int32,
) -> Node {
  let attributes = Map([])
  let mut expanded_attributes : Map[String, String]? = None
  for a in e.attributes {
    if a.name.namespace_uri is Some(uri) {
      attributes[a.name.qualified_name] = a.value
      let expanded = match expanded_attributes {
        Some(fields) => fields
        None => {
          let fields = Map([])
          expanded_attributes = Some(fields)
          fields
        }
      }
      expanded[uri + "#" + a.name.local_name] = a.value
    } else {
      attributes[a.name.local_name] = a.value
    }
  }
  {
    name: e.name.local_name,
    uri: e.name.namespace_uri.unwrap_or(""),
    attributes,
    expanded_attributes,
    namespace_prefixes,
    children: [],
    text: "",
    line,
    column,
  }
}

///|
/// Parse namespace-aware XML, rejecting DTDs and excessive input or nesting.
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
        let inherited = match stack.last() {
          Some(parent) => parent.namespace_prefixes
          None => Map([])
        }
        let prefixes = if e.namespace_declarations.is_empty() {
          inherited
        } else {
          let scope = inherited.copy()
          for declaration in e.namespace_declarations {
            let prefix = declaration.prefix.unwrap_or("")
            if declaration.namespace_uri == "" {
              ignore(scope.remove(prefix))
            } else {
              scope[prefix] = declaration.namespace_uri
            }
          }
          scope
        }
        let n = node(e, prefixes, ev.span.start.line, ev.span.start.column)
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
