# Chinese Academic Writing Support

This workflow supports ethical thesis writing. It must not be used to evade AI detectors, plagiarism detection, CNKI checks, Turnitin, iThenticate, or school integrity review.

For deeper workflows, load these files only when needed:

- `originality_policy.md`: mandatory boundary for AI-rate, plagiarism-rate, "降重", CNKI, Turnitin, and iThenticate requests.
- `originality_revision_workflow.md`: paragraph-level diagnosis, evidence request, rewriting, and revision-log process.
- `originality_prompt_templates.md`: safe prompt templates for paragraph rewriting, multi-source synthesis, and revision records.
- `citation_and_synthesis.md`: citation-gap rules and source-grounded synthesis patterns.

## Allowed Help

- Improve originality by asking what the student actually wants to argue, what data/results support it, and what citations ground it.
- Reduce repetition risk by turning source-adjacent wording into properly cited synthesis.
- Polish Chinese academic prose for clarity, logic, terminology, concision, and structure.
- Identify duplicate sentences, overlong sentences, template-like filler, citation gaps, and unsupported claims.
- Suggest where direct quotation, paraphrase with citation, or original analysis is needed.

## Refuse or Reframe

If the user asks to "降低 AI 率", "绕过 AIGC 检测", "规避查重", or "洗稿", reframe:

> 我不能帮助规避检测，但可以帮你做合规的原创性提升：检查重复风险、补充引用、重组论证、把模板化表述改成基于你自己材料的学术表达。

## Review Procedure

Run the automatic workflow when a draft file is available:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Invoke-CnOriginalityWorkflow.ps1 -InputPath draft.docx -OutputDir review
```

The workflow creates:

- `01_originality_report.md`: readable report
- `02_sentence_issues.csv`: sentence-level issues
- `03_repeated_phrases.csv`: repeated phrases
- `04_paragraph_actions.csv`: paragraph priorities
- `05_prompt_pack.md`: compliant prompts
- `06_revision_log_template.md`: transparent revision log

Manual procedure:

1. Split the draft into paragraphs and sentences.
2. Flag exact duplicate sentences and repeated phrases.
3. Flag long sentences over about 80 Chinese characters.
4. Flag claim markers such as "研究表明", "数据显示", "已有研究指出", "学者认为" when no citation marker is nearby.
5. Flag template-like expressions such as "具有重要意义", "不可忽视", "综上所述", "在一定程度上" when repeated.
6. Suggest revision actions:
   - Add data, case, method, or source.
   - Combine several source summaries into one synthesis.
   - Replace vague judgment with specific claim.
   - Add citation or quotation when preserving another author's wording.

## Safe Rewrite Pattern

For each paragraph, output:

- Original issue: repetition, citation gap, logic gap, or style issue.
- Revision direction: what new evidence or source is needed.
- Polished version: only if the student's meaning is clear.
- Citation note: where a citation is required.

Never invent references. If citations are missing, write `[需补充来源]`.

## Compare Drafts

When the user provides an original draft and a revised draft, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Compare-CnDrafts.ps1 -OriginalPath original.md -RevisedPath revised.md -OutputPath compare.csv
```

Use the overlap ratios as a diagnostic for close wording. Do not describe them as proof that a plagiarism or AI detector will pass.
