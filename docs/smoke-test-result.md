# Smoke Test Result

Generated at: 2026-06-10 10:10:33 CST

Base URL: `http://localhost:8081`

## Summary

| Result | Count |
| --- | ---: |
| Passed | 5 |
| Failed | 0 |
| Total | 5 |

Pass criterion: HTTP status code is `200`.

## Tested APIs

| Module | API | Method | HTTP | Result | Notes |
| --- | --- | --- | ---: | --- | --- |
| Login | `/console/v1/auth/login` | POST | 200 | PASS | Login with `saa / 123456`; response returned access and refresh tokens. |
| Prompt | `/api/prompts?pageNo=1&pageSize=10` | GET | 200 | PASS | Returned empty prompt page successfully. |
| Dataset | `/api/dataset/datasets?pageNumber=1&pageSize=10` | GET | 200 | PASS | Returned empty dataset page successfully. |
| Evaluator | `/api/evaluator/evaluators?pageNumber=1&pageSize=10` | GET | 200 | PASS | Returned evaluator page successfully. |
| Trace | `/api/observability/traces?pageNumber=1&pageSize=10&startTime=2026-06-09T02:10:33Z&endTime=2026-06-10T02:10:33Z` | GET | 200 | PASS | Returned empty trace page successfully. |

## Failed APIs

None.

## Fix Notes

The previous Trace list smoke test failed with HTTP `500` because Elasticsearch returned:

```text
No mapping found for [metadata.start] in order to sort on
```

Root cause: the local `loongsuite_traces` index had documents under `contents.*`, while the backend Trace query expects normalized fields under `metadata.*`.

Fix applied:

- Updated the Elasticsearch ingest pipeline `parsing_loongsuite_traces` to transform `contents.*` into `metadata.*`.
- Set `loongsuite_traces` `index.default_pipeline` to `parsing_loongsuite_traces`.
- Added the expected `metadata.*`, `attributes`, `resources`, `spanEvents`, `spanLinks`, and `usage` mappings.
- Migrated existing local `contents.*` documents through the pipeline.
