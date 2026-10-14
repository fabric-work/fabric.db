-- fabric.db governed state fabric schema

DEFINE TABLE tenant SCHEMAFULL;
DEFINE FIELD name ON tenant TYPE string;
DEFINE FIELD status ON tenant TYPE string DEFAULT "active";
DEFINE FIELD created_at ON tenant TYPE datetime DEFAULT time::now();

DEFINE TABLE actor SCHEMAFULL;
DEFINE FIELD tenant ON actor TYPE record<tenant>;
DEFINE FIELD type ON actor TYPE string;
DEFINE FIELD name ON actor TYPE string;
DEFINE FIELD external_id ON actor TYPE option<string>;
DEFINE FIELD status ON actor TYPE string DEFAULT "active";
DEFINE FIELD created_at ON actor TYPE datetime DEFAULT time::now();

DEFINE TABLE agent SCHEMAFULL;
DEFINE FIELD tenant ON agent TYPE record<tenant>;
DEFINE FIELD name ON agent TYPE string;
DEFINE FIELD purpose ON agent TYPE string;
DEFINE FIELD owner ON agent TYPE record<actor>;
DEFINE FIELD status ON agent TYPE string DEFAULT "draft";
DEFINE FIELD trust_score ON agent TYPE number DEFAULT 0;
DEFINE FIELD created_at ON agent TYPE datetime DEFAULT time::now();
DEFINE FIELD updated_at ON agent TYPE datetime DEFAULT time::now();

DEFINE TABLE tool SCHEMAFULL;
DEFINE FIELD tenant ON tool TYPE record<tenant>;
DEFINE FIELD name ON tool TYPE string;
DEFINE FIELD description ON tool TYPE option<string>;
DEFINE FIELD endpoint ON tool TYPE option<string>;
DEFINE FIELD status ON tool TYPE string DEFAULT "disabled";
DEFINE FIELD risk_level ON tool TYPE string DEFAULT "medium";
DEFINE FIELD created_at ON tool TYPE datetime DEFAULT time::now();

DEFINE TABLE policy SCHEMAFULL;
DEFINE FIELD tenant ON policy TYPE record<tenant>;
DEFINE FIELD name ON policy TYPE string;
DEFINE FIELD description ON policy TYPE option<string>;
DEFINE FIELD subject_type ON policy TYPE string;
DEFINE FIELD action ON policy TYPE string;
DEFINE FIELD resource_type ON policy TYPE string;
DEFINE FIELD effect ON policy TYPE string;
DEFINE FIELD approval_required ON policy TYPE bool DEFAULT false;
DEFINE FIELD status ON policy TYPE string DEFAULT "draft";
DEFINE FIELD created_at ON policy TYPE datetime DEFAULT time::now();

DEFINE TABLE approval SCHEMAFULL;
DEFINE FIELD tenant ON approval TYPE record<tenant>;
DEFINE FIELD requested_by ON approval TYPE record<actor>;
DEFINE FIELD approved_by ON approval TYPE option<record<actor>>;
DEFINE FIELD action ON approval TYPE string;
DEFINE FIELD resource ON approval TYPE string;
DEFINE FIELD status ON approval TYPE string DEFAULT "pending";
DEFINE FIELD reason ON approval TYPE option<string>;
DEFINE FIELD created_at ON approval TYPE datetime DEFAULT time::now();
DEFINE FIELD decided_at ON approval TYPE option<datetime>;

DEFINE TABLE event SCHEMAFULL;
DEFINE FIELD tenant ON event TYPE record<tenant>;
DEFINE FIELD type ON event TYPE string;
DEFINE FIELD actor ON event TYPE record<actor>;
DEFINE FIELD subject ON event TYPE string;
DEFINE FIELD action ON event TYPE string;
DEFINE FIELD resource ON event TYPE option<string>;
DEFINE FIELD payload ON event FLEXIBLE TYPE object;
DEFINE FIELD created_at ON event TYPE datetime DEFAULT time::now();

DEFINE TABLE decision SCHEMAFULL;
DEFINE FIELD tenant ON decision TYPE record<tenant>;
DEFINE FIELD actor ON decision TYPE record<actor>;
DEFINE FIELD objective ON decision TYPE string;
DEFINE FIELD context ON decision FLEXIBLE TYPE object;
DEFINE FIELD constraints ON decision TYPE array;
DEFINE FIELD options ON decision TYPE array;
DEFINE FIELD selected_option ON decision FLEXIBLE TYPE option<object>;
DEFINE FIELD policy_result ON decision FLEXIBLE TYPE option<object>;
DEFINE FIELD approval ON decision TYPE option<record<approval>>;
DEFINE FIELD outcome ON decision FLEXIBLE TYPE option<object>;
DEFINE FIELD created_at ON decision TYPE datetime DEFAULT time::now();

DEFINE TABLE provenance SCHEMAFULL;
DEFINE FIELD tenant ON provenance TYPE record<tenant>;
DEFINE FIELD subject ON provenance TYPE string;
DEFINE FIELD source ON provenance TYPE string;
DEFINE FIELD source_type ON provenance TYPE string;
DEFINE FIELD actor ON provenance TYPE option<record<actor>>;
DEFINE FIELD model ON provenance TYPE option<string>;
DEFINE FIELD tool ON provenance TYPE option<record<tool>>;
DEFINE FIELD input_hash ON provenance TYPE option<string>;
DEFINE FIELD output_hash ON provenance TYPE option<string>;
DEFINE FIELD created_at ON provenance TYPE datetime DEFAULT time::now();

DEFINE TABLE desired_state SCHEMAFULL;
DEFINE FIELD tenant ON desired_state TYPE record<tenant>;
DEFINE FIELD subject ON desired_state TYPE string;
DEFINE FIELD spec ON desired_state FLEXIBLE TYPE object;
DEFINE FIELD version ON desired_state TYPE int DEFAULT 1;
DEFINE FIELD created_at ON desired_state TYPE datetime DEFAULT time::now();

DEFINE TABLE observed_state SCHEMAFULL;
DEFINE FIELD tenant ON observed_state TYPE record<tenant>;
DEFINE FIELD subject ON observed_state TYPE string;
DEFINE FIELD state ON observed_state FLEXIBLE TYPE object;
DEFINE FIELD observed_at ON observed_state TYPE datetime DEFAULT time::now();

DEFINE TABLE drift SCHEMAFULL;
DEFINE FIELD tenant ON drift TYPE record<tenant>;
DEFINE FIELD subject ON drift TYPE string;
DEFINE FIELD desired ON drift TYPE record<desired_state>;
DEFINE FIELD observed ON drift TYPE record<observed_state>;
DEFINE FIELD diff ON drift FLEXIBLE TYPE object;
DEFINE FIELD severity ON drift TYPE string DEFAULT "medium";
DEFINE FIELD status ON drift TYPE string DEFAULT "open";
DEFINE FIELD created_at ON drift TYPE datetime DEFAULT time::now();
