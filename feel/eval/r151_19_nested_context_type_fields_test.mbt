///|
test "Structural context types retain their nested field boundaries" {
  assert_eq(
    @eval.feel_eval(
      "{address:{street:\"Main\",zip:7},ready:true} instance of context<address: context<street:string,zip:number>,ready:boolean>",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "{contacts:[{name:\"a\",priority:1}]} instance of context<contacts:list<context<name:string,priority:number>>>",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "{address:{street:\"Main\",zip:\"wrong\"},ready:true} instance of context<address:context<street:string,zip:number>,ready:boolean>",
    ).text(),
    "false",
  )
  assert_eq(
    @eval.feel_eval("{a:1,b:2} instance of context<a:number,b:number>").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "{address:{street:\"Main\",zip:7},ready:true} instance of context<address:Context<street:string,zip:number>,ready:boolean>",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "{nested:{𝛼:1,ready:true}} instance of context<nested:context<𝛼:number,ready:boolean>>",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "{nested:{𝛼:\"no\",ready:true}} instance of context<nested:context<𝛼:number,ready:boolean>>",
    ).text(),
    "false",
  )
}
