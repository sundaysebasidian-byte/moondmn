///|
test "Boxed filters expose context item fields" {
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[{price: 2}, {price: 7}, {price: 3}]</text></literalExpression></in><match><literalExpression><text>price &gt; 4</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{price: 7}]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[{price: 2}, {price: 7}]</text></literalExpression></in><match><literalExpression><text>item.price &gt; 4</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{price: 7}]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[1, 2, 3]</text></literalExpression></in><match><literalExpression><text>item &gt; 1</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[2, 3]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[{item: 2, price: 7}, {item: 6, price: 9}]</text></literalExpression></in><match><literalExpression><text>item &gt; 4</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{item: 6, price: 9}]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[{price: 2}, {price: 7}, {price: 3}]</text></literalExpression></in><match><literalExpression><text>price &gt; 4</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([("price", @types.Number(@types.decimal_int(0)))]),
    ).text(),
    "[{price: 7}]",
  )
}
