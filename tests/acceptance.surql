-- fabric.db acceptance fixture
-- Exercises the canonical governed-state chain against the real schema.

-- Reset deterministic fixture records so this test is repeatable.
DELETE drift:test;
DELETE observed_state:test;
DELETE desired_state:test;
DELETE provenance:test;
DELETE decision:test;
DELETE event:test;
DELETE approval:test;
DELETE policy:test;
DELETE tool:test;
DELETE agent:test;
DELETE actor:test;
DELETE tenant:test;

CREATE tenant:test CONTENT {
  name: "Fabric Test Tenant",
  status: "active"
};

CREATE actor:test CONTENT {
  tenant: tenant:test,
  type: "human",
  name: "Fabric Test Owner",
  external_id: "test-owner",
  status: "active"
};

CREATE agent:test CONTENT {
  tenant: tenant:test,
  name: "Acceptance Agent",
  purpose: "Exercise governed state transitions",
  owner: actor:test,
  status: "active",
  trust_score: 90
};

CREATE tool:test CONTENT {
  tenant: tenant:test,
  name: "Acceptance Tool",
  description: "Synthetic tool used by the acceptance suite",
  endpoint: "test://fabric",
  status: "enabled",
  risk_level: "low"
};

CREATE policy:test CONTENT {
  tenant: tenant:test,
  name: "Allow Acceptance Execution",
  description: "Test policy",
  subject_type: "agent",
  action: "execute",
  resource_type: "test-resource",
  effect: "allow",
  approval_required: true,
  status: "active"
};

CREATE approval:test CONTENT {
  tenant: tenant:test,
  requested_by: actor:test,
  approved_by: actor:test,
  action: "execute",
  resource: "test-resource",
  status: "approved",
  reason: "Acceptance test",
  decided_at: time::now()
};

CREATE decision:test CONTENT {
  tenant: tenant:test,
  actor: actor:test,
  objective: "Produce governed test state",
  context: { test: true },
  constraints: ["policy-approved", "traceable"],
  options: [{ name: "execute" }, { name: "deny" }],
  selected_option: { name: "execute" },
  policy_result: { effect: "allow", policy: "policy:test" },
  approval: approval:test,
  outcome: { status: "approved" }
};

CREATE event:test CONTENT {
  tenant: tenant:test,
  type: fn::event_type("agent", "execute"),
  actor: actor:test,
  subject: "agent:test",
  action: "execute",
  resource: "test-resource",
  payload: {
    decision: "decision:test",
    test: true
  }
};

CREATE provenance:test CONTENT {
  tenant: tenant:test,
  subject: "event:test",
  source: "acceptance-suite",
  source_type: "test",
  actor: actor:test,
  tool: tool:test,
  input_hash: "sha256:test-input",
  output_hash: "sha256:test-output"
};

CREATE desired_state:test CONTENT {
  tenant: tenant:test,
  subject: "agent:test",
  spec: {
    status: "active",
    mode: "governed",
    replicas: 1
  },
  version: 1
};

CREATE observed_state:test CONTENT {
  tenant: tenant:test,
  subject: "agent:test",
  state: {
    status: "active",
    mode: "governed",
    replicas: 0
  }
};

CREATE drift:test CONTENT {
  tenant: tenant:test,
  subject: "agent:test",
  desired: desired_state:test,
  observed: observed_state:test,
  diff: {
    field: "replicas",
    desired: 1,
    observed: 0
  },
  severity: "medium",
  status: "open"
};

-- Machine-readable sentinels consumed by tests/run.sh.
RETURN "FABRIC_ACCEPTANCE_SEEDED";
SELECT count() AS count FROM tenant WHERE id = tenant:test GROUP ALL;
SELECT count() AS count FROM actor WHERE id = actor:test AND tenant = tenant:test GROUP ALL;
SELECT count() AS count FROM agent WHERE id = agent:test AND owner = actor:test AND trust_score = 90 GROUP ALL;
SELECT count() AS count FROM policy WHERE id = policy:test AND effect = "allow" AND approval_required = true GROUP ALL;
SELECT count() AS count FROM approval WHERE id = approval:test AND status = "approved" GROUP ALL;
SELECT count() AS count FROM decision WHERE id = decision:test AND approval = approval:test GROUP ALL;
SELECT count() AS count FROM event WHERE id = event:test AND actor = actor:test AND type = "agent.execute" GROUP ALL;
SELECT count() AS count FROM provenance WHERE id = provenance:test AND tool = tool:test GROUP ALL;
SELECT count() AS count FROM desired_state WHERE id = desired_state:test AND version = 1 GROUP ALL;
SELECT count() AS count FROM observed_state WHERE id = observed_state:test GROUP ALL;
SELECT count() AS count FROM drift WHERE id = drift:test AND desired = desired_state:test AND observed = observed_state:test AND status = "open" GROUP ALL;
-- Free-form object fields must keep their nested values (FLEXIBLE in a SCHEMAFULL table).
RETURN [event:test.payload.decision, decision:test.context.test, decision:test.selected_option.name, decision:test.policy_result.policy, decision:test.outcome.status, desired_state:test.spec.replicas, observed_state:test.state.replicas, drift:test.diff.field];
RETURN fn::risk_weight("critical");
RETURN fn::risk_weight("high");
RETURN fn::risk_weight("medium");
RETURN fn::risk_weight("low");
RETURN "FABRIC_ACCEPTANCE_COMPLETE";
