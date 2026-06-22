# Screen capture matrix

Run: `npm run capture:design-review`  
Output: `design-review/captures/{screenId}/{state}.png`

Query param (web): `http://localhost:8080/?design_review={screenId}__{state}`

| Priority | screenId | state | DESIGN_REVIEW key | File |
|----------|----------|-------|-------------------|------|
| P0 | student_hub | first_visit | `student_hub__first_visit` | student_hub/first_visit.png |
| P0 | student_hub | returning | `student_hub__returning` | student_hub/returning.png |
| P0 | upload | idle | `upload__idle` | upload/idle.png |
| P0 | upload | analyzing | `analysis__analyzing` | upload/analyzing.png |
| P0 | analysis | result_weak | `analysis__result_weak` | analysis/result_weak.png |
| P0 | analysis | result_ok | `analysis__result_ok` | analysis/result_ok.png |
| P0 | practice | question | `practice__question` | practice/question.png |
| P0 | practice | feedback_correct | `practice__feedback_correct` | practice/feedback_correct.png |
| P0 | practice | feedback_wrong | `practice__feedback_wrong` | practice/feedback_wrong.png |
| P0 | student_progress | grade_e12 | `student_progress__grade_e12` | student_progress/grade_e12.png |
| P0 | student_progress | grade_m1 | `student_progress__grade_m1` | student_progress/grade_m1.png |
| P0 | student_progress | chain_warning | `student_progress__chain_warning` | student_progress/chain_warning.png |

P1/P2 captures can be added to this matrix later.
