# AI Prompt History

This file records prompts that were replaced so their behaviour and tradeoffs can be reviewed later.

## 2026-06-11 - Single-pass document analysis and flag generation

### Why it was replaced

The prompt treated follow-up tasks, clarification, deadline tracking, document checks, and unresolved decisions as reasons to create flags. In practice, this produced too many flags for routine contract terms and did not use the application's imported legal resources.

### Prompt

```text
Return only valid JSON in this shape:
{
  "summary": "A short plain-English summary of the whole file.",
  "micro_summary": "A very short summary of the whole file in 8 words or fewer.",
  "clauses": [
    {
      "title": "string",
      "content": "string",
      "risk_level": "low|medium|high",
      "summary": "string",
      "flags": [
        {
          "name": "string",
          "reason": "A concise 1-2 sentence summary of what the flag is about.",
          "details": "A fuller plain-English explanation of the issue and why it matters.",
          "level": "low|medium|high",
          "category": "deadline|missing_information|negotiation_point|legal_review|document_check|commercial_decision|unclear_term",
          "suggested_action": "string"
        }
      ]
    }
  ]
}

Identify clauses that may be important for the document owner to understand or act on.
Use risk_level to describe the seriousness of the clause itself.

Do not create a flag merely because a clause is high risk.
A high-risk clause should draw attention to a potentially serious issue, but it does not automatically require a flag.

Add flags only where the clause requires a concrete follow-up action, clarification, deadline tracking, document check, review, or unresolved decision.
Keep flag reason concise: one or two sentences that help the document owner quickly understand what the flag is about.
Use flag details for a fuller explanation of the relevant wording, concern, and why it matters. Do not repeat the suggested action.
Use flag level to describe the urgency or priority of that follow-up action.
Use flag category to describe the type of follow-up.
Use suggested_action to give the document owner one concrete next step.
For clauses that do not require concrete follow-up, return an empty flags array, even if the clause is high risk.

Document text:
{{document_text}}
```

### Replacement summary

Document analysis now extracts candidate concerns rather than final flags. A focused second pass reviews each clause and its candidates against retrieved legal references, rejects routine or immaterial concerns, and keeps only distinct material risks.
