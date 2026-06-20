# Multi-Model Context Packet

packet_id:
created_at:
project:
current_gate:
active_task:

purpose:

recovered_anchors:
  - source:
    proves:
      - 
    does_not_prove:
      - 

user_pain_or_pressure:
  - 

bounded_question_for_model:

execution_mode_requested: interactive_cli_continuous | capturable_cli_one_shot | capturable_cli_continuous | maestro_delegate | codex_app_one_shot | codex_app_continuous

model_role:
requested_model_alias: opus
fallback_model_alias: sonnet
actual_model_expected_from_tool: true

quota_policy:
  prefer_one_shot: true
  resume_only_if_prior_context_required: true
  retire_after_receipt: true
  max_followup_turns:
  close_condition:
    - receipt_accepted
    - gate_changed
    - user_changed_direction
    - quota_concern

must_not_decide:
  - product direction without user gate
  - UI/sample/generated-image acceptance
  - external publish/write actions
  - broad implementation outside the stated scope

context_files_or_dirs:
  - 

expected_receipt:
  template: .workflow/templates/model_review_receipt.yaml
  required_fields:
    - model_identity
    - execution_mode
    - answer
    - evidence
    - proves
    - does_not_prove
    - risks
    - next_recommended_step
