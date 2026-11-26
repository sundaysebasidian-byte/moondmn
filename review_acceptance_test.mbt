///|
test "submission scope: the same approval model covers all three outcomes" {
  let xml =
    #|<definitions xmlns="https://www.omg.org/spec/DMN/20230324/MODEL/" id="approval" name="Approval" namespace="urn:moondmn:review:approval">
    #|  <inputData id="income" name="Monthly Income"><variable name="Monthly Income" typeRef="number"/></inputData>
    #|  <inputData id="debt" name="Existing Monthly Debt"><variable name="Existing Monthly Debt" typeRef="number"/></inputData>
    #|  <inputData id="requested" name="New Monthly Payment"><variable name="New Monthly Payment" typeRef="number"/></inputData>
    #|  <decision id="net" name="Net Income">
    #|    <variable name="Net Income" typeRef="number"/>
    #|    <informationRequirement><requiredInput href="#income"/></informationRequirement>
    #|    <informationRequirement><requiredInput href="#debt"/></informationRequirement>
    #|    <informationRequirement><requiredInput href="#requested"/></informationRequirement>
    #|    <literalExpression><text>Monthly Income - (Existing Monthly Debt + New Monthly Payment)</text></literalExpression>
    #|  </decision>
    #|  <decision id="verdict" name="Verdict">
    #|    <variable name="Verdict" typeRef="string"/>
    #|    <informationRequirement><requiredDecision href="#net"/></informationRequirement>
    #|    <decisionTable hitPolicy="FIRST">
    #|      <input><inputExpression typeRef="number"><text>Net Income</text></inputExpression></input>
    #|      <output name="Verdict" typeRef="string"/>
    #|      <rule><inputEntry><text>&lt; 1000</text></inputEntry><outputEntry><text>"Decline"</text></outputEntry></rule>
    #|      <rule><inputEntry><text>&lt; 2500</text></inputEntry><outputEntry><text>"Refer"</text></outputEntry></rule>
    #|      <rule><inputEntry><text>&gt;= 2500</text></inputEntry><outputEntry><text>"Approve"</text></outputEntry></rule>
    #|      <rule><inputEntry><text>-</text></inputEntry><outputEntry><text>"Refer"</text></outputEntry></rule>
    #|    </decisionTable>
    #|  </decision>
    #|</definitions>
  let model = @moondmn.parse_model(xml)
  let at_threshold =
    #|{"Monthly Income":3600.30,"Existing Monthly Debt":1000.10,"New Monthly Payment":100.20}
  let below_threshold =
    #|{"Monthly Income":3600.29,"Existing Monthly Debt":1000.10,"New Monthly Payment":100.20}
  let at_lower_threshold =
    #|{"Monthly Income":2100.30,"Existing Monthly Debt":1000.10,"New Monthly Payment":100.20}
  let denied =
    #|{"Monthly Income":2100.29,"Existing Monthly Debt":1000.10,"New Monthly Payment":100.20}
  inspect(
    @moondmn.evaluate_decision(model, "Net Income", at_threshold),
    content="2500",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Net Income", below_threshold),
    content="2499.99",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Verdict", at_threshold),
    content="\"Approve\"",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Verdict", below_threshold),
    content="\"Refer\"",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Net Income", at_lower_threshold),
    content="1000",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Net Income", denied),
    content="999.99",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Verdict", at_lower_threshold),
    content="\"Refer\"",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Verdict", denied),
    content="\"Decline\"",
  )
  let incomplete =
    #|{"Monthly Income":null,"Existing Monthly Debt":1000,"New Monthly Payment":100}
  inspect(
    @moondmn.evaluate_decision(model, "Verdict", incomplete),
    content="\"Refer\"",
  )
  let missing =
    #|{"Existing Monthly Debt":1000,"New Monthly Payment":100}
  let wrong_type =
    #|{"Monthly Income":"3600","Existing Monthly Debt":1000,"New Monthly Payment":100}
  inspect(
    @moondmn.evaluate_decision(model, "Verdict", missing) catch {
      e => @types.error_code(e)
    },
    content="E_INPUT_MISSING",
  )
  inspect(
    @moondmn.evaluate_decision(model, "Verdict", wrong_type) catch {
      e => @types.error_code(e)
    },
    content="E_TYPE",
  )
}
