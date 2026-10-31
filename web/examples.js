// Built-in examples. Each one is written for this project.

const NS = "https://www.omg.org/spec/DMN/20230324/MODEL/";

const loan = `<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="${NS}" id="loan" name="Loan Approval" namespace="urn:moondmn:examples:loan">
  <itemDefinition id="t-employment" name="Employment">
    <typeRef>string</typeRef>
    <allowedValues><text>"employed","self-employed","retired","unemployed"</text></allowedValues>
  </itemDefinition>
  <itemDefinition id="t-applicant" name="Applicant">
    <itemComponent id="t-age" name="Age"><typeRef>number</typeRef></itemComponent>
    <itemComponent id="t-income" name="Income"><typeRef>number</typeRef></itemComponent>
    <itemComponent id="t-score" name="Score">
      <typeRef>number</typeRef>
      <allowedValues><text>[300..850]</text></allowedValues>
    </itemComponent>
    <itemComponent id="t-job" name="Employment"><typeRef>Employment</typeRef></itemComponent>
  </itemDefinition>

  <inputData id="applicant" name="Applicant"><variable name="Applicant" typeRef="Applicant"/></inputData>
  <inputData id="amount" name="Loan Amount"><variable name="Loan Amount" typeRef="number"/></inputData>
  <inputData id="term" name="Term Months"><variable name="Term Months" typeRef="number"/></inputData>

  <decision id="tier" name="Credit Tier">
    <variable name="Credit Tier" typeRef="string"/>
    <informationRequirement><requiredInput href="#applicant"/></informationRequirement>
    <decisionTable hitPolicy="FIRST">
      <input label="Credit Score"><inputExpression typeRef="number"><text>Applicant.Score</text></inputExpression></input>
      <output name="tier" typeRef="string"/>
      <rule><inputEntry><text>&gt;= 740</text></inputEntry><outputEntry><text>"A"</text></outputEntry></rule>
      <rule><inputEntry><text>&gt;= 670</text></inputEntry><outputEntry><text>"B"</text></outputEntry></rule>
      <rule><inputEntry><text>&gt;= 580</text></inputEntry><outputEntry><text>"C"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><outputEntry><text>"D"</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="ratio" name="Debt Ratio">
    <variable name="Debt Ratio" typeRef="number"/>
    <informationRequirement><requiredInput href="#applicant"/></informationRequirement>
    <informationRequirement><requiredInput href="#amount"/></informationRequirement>
    <informationRequirement><requiredInput href="#term"/></informationRequirement>
    <literalExpression><text>decimal(Loan Amount / Term Months * 12 / Applicant.Income, 3)</text></literalExpression>
  </decision>

  <decision id="verdict" name="Verdict">
    <variable name="Verdict" typeRef="string"/>
    <informationRequirement><requiredDecision href="#tier"/></informationRequirement>
    <informationRequirement><requiredDecision href="#ratio"/></informationRequirement>
    <informationRequirement><requiredInput href="#applicant"/></informationRequirement>
    <decisionTable hitPolicy="FIRST">
      <input label="Credit Tier"><inputExpression typeRef="string"><text>Credit Tier</text></inputExpression></input>
      <input label="Debt Ratio"><inputExpression typeRef="number"><text>Debt Ratio</text></inputExpression></input>
      <input label="Employment"><inputExpression typeRef="string"><text>Applicant.Employment</text></inputExpression></input>
      <output name="verdict" typeRef="string"/>
      <rule><inputEntry><text>"D"</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Decline"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>&gt; 0.45</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Decline"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>"unemployed"</text></inputEntry><outputEntry><text>"Refer"</text></outputEntry></rule>
      <rule><inputEntry><text>"A","B"</text></inputEntry><inputEntry><text>&lt;= 0.35</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Approve"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Refer"</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="rate" name="Interest Rate">
    <variable name="Interest Rate" typeRef="number"/>
    <informationRequirement><requiredDecision href="#tier"/></informationRequirement>
    <decisionTable hitPolicy="FIRST">
      <input label="Credit Tier"><inputExpression typeRef="string"><text>Credit Tier</text></inputExpression></input>
      <output name="rate" typeRef="number"/>
      <rule><inputEntry><text>"A"</text></inputEntry><outputEntry><text>3.9</text></outputEntry></rule>
      <rule><inputEntry><text>"B"</text></inputEntry><outputEntry><text>5.4</text></outputEntry></rule>
      <rule><inputEntry><text>"C"</text></inputEntry><outputEntry><text>8.2</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><outputEntry><text>12.5</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="offer" name="Offer">
    <variable name="Offer" typeRef="context"/>
    <informationRequirement><requiredDecision href="#verdict"/></informationRequirement>
    <informationRequirement><requiredDecision href="#rate"/></informationRequirement>
    <informationRequirement><requiredInput href="#amount"/></informationRequirement>
    <informationRequirement><requiredInput href="#term"/></informationRequirement>
    <context>
      <contextEntry>
        <variable name="Total Interest"/>
        <literalExpression><text>decimal(Loan Amount * Interest Rate / 100 * Term Months / 12, 2)</text></literalExpression>
      </contextEntry>
      <contextEntry>
        <variable name="Monthly Payment"/>
        <literalExpression><text>decimal((Loan Amount + Total Interest) / Term Months, 2)</text></literalExpression>
      </contextEntry>
      <contextEntry>
        <literalExpression><text>{ verdict: Verdict, rate: Interest Rate, monthly: Monthly Payment, interest: Total Interest }</text></literalExpression>
      </contextEntry>
    </context>
  </decision>
</definitions>
`;

const insurance = `<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="${NS}" id="insurance" name="Auto Insurance Pricing" namespace="urn:moondmn:examples:insurance">
  <itemDefinition id="t-vehicle" name="Vehicle">
    <typeRef>string</typeRef>
    <allowedValues><text>"sedan","suv","sports","truck"</text></allowedValues>
  </itemDefinition>

  <inputData id="age" name="Driver Age"><variable name="Driver Age" typeRef="number"/></inputData>
  <inputData id="licensed" name="Years Licensed"><variable name="Years Licensed" typeRef="number"/></inputData>
  <inputData id="vehicle" name="Vehicle Type"><variable name="Vehicle Type" typeRef="Vehicle"/></inputData>
  <inputData id="claims" name="Claims Last 3 Years"><variable name="Claims Last 3 Years" typeRef="number"/></inputData>
  <inputData id="mileage" name="Annual Mileage"><variable name="Annual Mileage" typeRef="number"/></inputData>

  <decision id="base" name="Base Premium">
    <variable name="Base Premium" typeRef="number"/>
    <informationRequirement><requiredInput href="#vehicle"/></informationRequirement>
    <decisionTable hitPolicy="UNIQUE">
      <input label="Vehicle Type"><inputExpression typeRef="string"><text>Vehicle Type</text></inputExpression></input>
      <output name="base" typeRef="number"/>
      <rule><inputEntry><text>"sedan"</text></inputEntry><outputEntry><text>600</text></outputEntry></rule>
      <rule><inputEntry><text>"suv"</text></inputEntry><outputEntry><text>720</text></outputEntry></rule>
      <rule><inputEntry><text>"sports"</text></inputEntry><outputEntry><text>980</text></outputEntry></rule>
      <rule><inputEntry><text>"truck"</text></inputEntry><outputEntry><text>840</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="surcharges" name="Surcharges">
    <variable name="Surcharges" typeRef="number"/>
    <informationRequirement><requiredInput href="#age"/></informationRequirement>
    <informationRequirement><requiredInput href="#licensed"/></informationRequirement>
    <informationRequirement><requiredInput href="#claims"/></informationRequirement>
    <informationRequirement><requiredInput href="#mileage"/></informationRequirement>
    <decisionTable hitPolicy="COLLECT" aggregation="SUM">
      <input label="Driver Age"><inputExpression typeRef="number"><text>Driver Age</text></inputExpression></input>
      <input label="Years Licensed"><inputExpression typeRef="number"><text>Years Licensed</text></inputExpression></input>
      <input label="Claims"><inputExpression typeRef="number"><text>Claims Last 3 Years</text></inputExpression></input>
      <input label="Mileage"><inputExpression typeRef="number"><text>Annual Mileage</text></inputExpression></input>
      <output name="amount" typeRef="number"/>
      <rule><inputEntry><text>&lt; 25</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>250</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>&lt; 2</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>120</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>&gt;= 1</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>180</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>&gt;= 3</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>300</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>&gt; 20000</text></inputEntry><outputEntry><text>90</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="discount" name="Discount Rate">
    <variable name="Discount Rate" typeRef="number"/>
    <informationRequirement><requiredInput href="#licensed"/></informationRequirement>
    <informationRequirement><requiredInput href="#claims"/></informationRequirement>
    <informationRequirement><requiredInput href="#mileage"/></informationRequirement>
    <decisionTable hitPolicy="COLLECT" aggregation="MAX">
      <input label="Years Licensed"><inputExpression typeRef="number"><text>Years Licensed</text></inputExpression></input>
      <input label="Claims"><inputExpression typeRef="number"><text>Claims Last 3 Years</text></inputExpression></input>
      <input label="Mileage"><inputExpression typeRef="number"><text>Annual Mileage</text></inputExpression></input>
      <output name="rate" typeRef="number"/>
      <rule><inputEntry><text>&gt;= 5</text></inputEntry><inputEntry><text>0</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>0.10</text></outputEntry></rule>
      <rule><inputEntry><text>&gt;= 10</text></inputEntry><inputEntry><text>0</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>0.15</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>&lt; 8000</text></inputEntry><outputEntry><text>0.05</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>0</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="risk" name="Risk Class">
    <variable name="Risk Class" typeRef="string"/>
    <informationRequirement><requiredInput href="#age"/></informationRequirement>
    <informationRequirement><requiredInput href="#claims"/></informationRequirement>
    <informationRequirement><requiredInput href="#vehicle"/></informationRequirement>
    <decisionTable hitPolicy="PRIORITY">
      <input label="Driver Age"><inputExpression typeRef="number"><text>Driver Age</text></inputExpression></input>
      <input label="Claims"><inputExpression typeRef="number"><text>Claims Last 3 Years</text></inputExpression></input>
      <input label="Vehicle"><inputExpression typeRef="string"><text>Vehicle Type</text></inputExpression></input>
      <output name="risk" typeRef="string"><outputValues><text>"High","Medium","Low"</text></outputValues></output>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>&gt;= 2</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"High"</text></outputEntry></rule>
      <rule><inputEntry><text>&lt; 25</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Medium"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>"sports"</text></inputEntry><outputEntry><text>"Medium"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Low"</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="review" name="Manual Review">
    <variable name="Manual Review" typeRef="boolean"/>
    <informationRequirement><requiredInput href="#age"/></informationRequirement>
    <informationRequirement><requiredInput href="#licensed"/></informationRequirement>
    <informationRequirement><requiredInput href="#claims"/></informationRequirement>
    <decisionTable hitPolicy="ANY">
      <input label="Driver Age"><inputExpression typeRef="number"><text>Driver Age</text></inputExpression></input>
      <input label="Years Licensed"><inputExpression typeRef="number"><text>Years Licensed</text></inputExpression></input>
      <input label="Claims"><inputExpression typeRef="number"><text>Claims Last 3 Years</text></inputExpression></input>
      <output name="review" typeRef="boolean"><defaultOutputEntry><text>false</text></defaultOutputEntry></output>
      <rule><inputEntry><text>&lt; 18</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>true</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>&lt; 1</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>true</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>&gt;= 3</text></inputEntry><outputEntry><text>true</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="notes" name="Notes">
    <variable name="Notes" typeRef="list"/>
    <informationRequirement><requiredInput href="#age"/></informationRequirement>
    <informationRequirement><requiredInput href="#mileage"/></informationRequirement>
    <informationRequirement><requiredInput href="#claims"/></informationRequirement>
    <decisionTable hitPolicy="RULE ORDER">
      <input label="Driver Age"><inputExpression typeRef="number"><text>Driver Age</text></inputExpression></input>
      <input label="Mileage"><inputExpression typeRef="number"><text>Annual Mileage</text></inputExpression></input>
      <input label="Claims"><inputExpression typeRef="number"><text>Claims Last 3 Years</text></inputExpression></input>
      <output name="note" typeRef="string"/>
      <rule><inputEntry><text>&lt; 25</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Young driver surcharge"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>&gt; 20000</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"High mileage surcharge"</text></outputEntry></rule>
      <rule><inputEntry><text>-</text></inputEntry><inputEntry><text>-</text></inputEntry><inputEntry><text>0</text></inputEntry><outputEntry><text>"Claim-free discount"</text></outputEntry></rule>
    </decisionTable>
  </decision>

  <decision id="premium" name="Premium">
    <variable name="Premium" typeRef="number"/>
    <informationRequirement><requiredDecision href="#base"/></informationRequirement>
    <informationRequirement><requiredDecision href="#surcharges"/></informationRequirement>
    <informationRequirement><requiredDecision href="#discount"/></informationRequirement>
    <literalExpression><text>decimal((Base Premium + Surcharges) * (1 - Discount Rate), 2)</text></literalExpression>
  </decision>

  <decision id="quote" name="Quote">
    <variable name="Quote" typeRef="context"/>
    <informationRequirement><requiredDecision href="#premium"/></informationRequirement>
    <informationRequirement><requiredDecision href="#risk"/></informationRequirement>
    <informationRequirement><requiredDecision href="#review"/></informationRequirement>
    <informationRequirement><requiredDecision href="#notes"/></informationRequirement>
    <context>
      <contextEntry>
        <literalExpression><text>{ premium: Premium, risk: Risk Class, review: Manual Review, notes: Notes }</text></literalExpression>
      </contextEntry>
    </context>
  </decision>
</definitions>
`;

const subscription = `<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="${NS}" id="subscription" name="Subscription Renewal" namespace="urn:moondmn:examples:subscription">
  <inputData id="start" name="Start Date"><variable name="Start Date" typeRef="date"/></inputData>
  <inputData id="term" name="Term"><variable name="Term" typeRef="years and months duration"/></inputData>
  <inputData id="grace" name="Grace Period"><variable name="Grace Period" typeRef="days and time duration"/></inputData>
  <inputData id="login" name="Last Login"><variable name="Last Login" typeRef="date and time"/></inputData>

  <decision id="renewal" name="Renewal Date">
    <variable name="Renewal Date" typeRef="date"/>
    <informationRequirement><requiredInput href="#start"/></informationRequirement>
    <informationRequirement><requiredInput href="#term"/></informationRequirement>
    <literalExpression><text>Start Date + Term</text></literalExpression>
  </decision>

  <decision id="ends" name="Grace Ends">
    <variable name="Grace Ends" typeRef="date"/>
    <informationRequirement><requiredDecision href="#renewal"/></informationRequirement>
    <informationRequirement><requiredInput href="#grace"/></informationRequirement>
    <literalExpression><text>Renewal Date + Grace Period</text></literalExpression>
  </decision>

  <decision id="days" name="Days Remaining">
    <variable name="Days Remaining" typeRef="number"/>
    <informationRequirement><requiredDecision href="#renewal"/></informationRequirement>
    <literalExpression><text>(Renewal Date - today()).days</text></literalExpression>
  </decision>

  <decision id="idle" name="Days Inactive">
    <variable name="Days Inactive" typeRef="number"/>
    <informationRequirement><requiredInput href="#login"/></informationRequirement>
    <literalExpression><text>(now() - Last Login).days</text></literalExpression>
  </decision>

  <decision id="status" name="Status">
    <variable name="Status" typeRef="string"/>
    <informationRequirement><requiredDecision href="#renewal"/></informationRequirement>
    <informationRequirement><requiredDecision href="#ends"/></informationRequirement>
    <conditional>
      <if><literalExpression><text>today() &lt;= Renewal Date</text></literalExpression></if>
      <then><literalExpression><text>"Active"</text></literalExpression></then>
      <else><literalExpression><text>if today() &lt;= Grace Ends then "Grace period" else "Expired"</text></literalExpression></else>
    </conditional>
  </decision>

  <decision id="reminder" name="Reminder">
    <variable name="Reminder" typeRef="string"/>
    <informationRequirement><requiredDecision href="#days"/></informationRequirement>
    <informationRequirement><requiredDecision href="#idle"/></informationRequirement>
    <decisionTable hitPolicy="UNIQUE">
      <input label="Days Remaining"><inputExpression typeRef="number"><text>Days Remaining</text></inputExpression></input>
      <input label="Days Inactive"><inputExpression typeRef="number"><text>Days Inactive</text></inputExpression></input>
      <output name="reminder" typeRef="string"/>
      <rule><inputEntry><text>&gt; 30</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"None"</text></outputEntry></rule>
      <rule><inputEntry><text>(7..30]</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Email"</text></outputEntry></rule>
      <rule><inputEntry><text>[0..7]</text></inputEntry><inputEntry><text>&lt; 14</text></inputEntry><outputEntry><text>"Email and SMS"</text></outputEntry></rule>
      <rule><inputEntry><text>[0..7]</text></inputEntry><inputEntry><text>&gt;= 14</text></inputEntry><outputEntry><text>"Phone call"</text></outputEntry></rule>
      <rule><inputEntry><text>&lt; 0</text></inputEntry><inputEntry><text>-</text></inputEntry><outputEntry><text>"Win-back offer"</text></outputEntry></rule>
    </decisionTable>
  </decision>
</definitions>
`;

export const examples = [
  {
    id: "loan",
    title: "Loan",
    xml: loan,
    decision: "Offer",
    now: "2026-03-01T09:00:00Z",
    input: {
      Applicant: { Age: 34, Income: 72000, Score: 712, Employment: "employed" },
      "Loan Amount": 18000,
      "Term Months": 36,
    },
    expect: {
      decision: "Offer",
      value: { verdict: "Approve", rate: 5.4, monthly: 581, interest: 2916 },
      hits: { "Credit Tier": [1], Verdict: [3], "Interest Rate": [1] },
    },
  },
  {
    id: "insurance",
    title: "Insurance",
    xml: insurance,
    decision: "Quote",
    now: "2026-03-01T09:00:00Z",
    input: {
      "Driver Age": 23,
      "Years Licensed": 4,
      "Vehicle Type": "sports",
      "Claims Last 3 Years": 1,
      "Annual Mileage": 21000,
    },
    expect: {
      decision: "Quote",
      value: {
        premium: 1500,
        risk: "Medium",
        review: false,
        notes: ["Young driver surcharge", "High mileage surcharge"],
      },
      hits: {
        "Base Premium": [2],
        Surcharges: [0, 2, 4],
        "Discount Rate": [3],
        "Risk Class": [1, 2, 3],
        "Manual Review": [],
        Notes: [0, 1],
      },
    },
  },
  {
    id: "subscription",
    title: "Dates",
    xml: subscription,
    decision: "Reminder",
    now: "2026-03-01T09:00:00Z",
    input: {
      "Start Date": "2025-03-05",
      Term: "P1Y",
      "Grace Period": "P14D",
      "Last Login": "2026-02-24T08:30:00Z",
    },
    expect: {
      decision: "Reminder",
      value: "Email and SMS",
      hits: { Reminder: [2] },
    },
  },
];
