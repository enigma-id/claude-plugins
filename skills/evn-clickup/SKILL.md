---
name: evn-clickup
description: Use when managing ClickUp tasks, documents, and project tracking via the official ClickUp MCP server. Covers Pre-Deal Pipeline, project task management, document read/create/update.
---

# ClickUp Skill

## Overview

ClickUp is the system of record. Humans and agents operate in the same workspace in real-time.

No custom backend. No database. No deployment.

## Workspace Context (Cached)

| Entity            | ID                                     | Notes                                         |
| ----------------- | -------------------------------------- | --------------------------------------------- |
| Workspace         | `90181213274`                          |                                               |
| Space             | `Software Development` — `90184517334` |                                               |
| Pre-Deal Pipeline | `901817797808`                         | For tracking potential deals pre-confirmation |
| Projects Folder   | `90185239162`                          | Contains all active projects                  |
| Onward            | `901807958157`                         | B2B Logistics Marketplace                     |
| Suka Bread        | `901808224561`                         |                                               |
| Others            | `901808330616`                         |                                               |

## Pre-Deal Pipeline

List ID: `901817797808`

Statuses (Kanban columns in Board view):

- `Leads` — Initial contact, unqualified
- `Scoping` — Gathering requirements
- `Proposal` — Proposal sent, awaiting response
- `Negotiation` — Active negotiation
- `Won` — Deal confirmed → move to project list
- `Lost` — No deal, archived

Naming convention for pre-deal tasks:

- Title: `[CLIENT] Project Brief`
- Status: Current stage
- Assignee: Who owns the deal
- Use `Client` custom field (text) if available

## Projects

When working on an active project (Onward, CTS, etc.):

1. Check existing tasks first (`clickup_filter_tasks` with list_id)
2. Create tasks under the appropriate project list
3. Use subtasks for decomposition
4. Update status as work progresses

## Document Management

Documents are attached to lists/projects. Common doc URL format:
`https://app.clickup.com/{workspace_id}/v/dc/{doc_id}/{page_id}`

### Read Document

```
1. clickup_list_document_pages(document_id) → get page IDs
2. clickup_get_document_pages(document_id, page_ids, content_format="text/md")
```

### Create Document

```
clickup_create_document(
  name="Document Name",
  parent={id: "<list_id or folder_id>", type: "<4|5|6|7>"},
  visibility="PRIVATE",
  create_page=true
)
```

Type codes: `4`=space, `5`=folder, `6`=list, `7`=everything, `12`=workspace

### Create Page in Document

```
clickup_create_document_page(
  document_id="<doc_id>",
  name="Page Title",
  content="Markdown content here",
  content_format="text/md",
  parent_page_id="<parent_page_id or null for root>"
)
```

### Update Page Content

```
clickup_update_document_page(
  document_id="<doc_id>",
  page_id="<page_id>",
  name="Updated Title (optional)",
  content="New markdown content (replaces entire page)",
  content_format="text/md"
)
```

## Task Naming Conventions

| Entity            | Format                                 |
| ----------------- | -------------------------------------- |
| Pre-deal task     | `[CLIENT] Project Brief`               |
| Project task      | `[PROJECT] <verb> <outcome>`           |
| Subtask           | `<verb> <outcome>`                     |
| Session reference | `Session: <session-id>` in description |

## Session Init

On session start:

1. Check if human provided a ClickUp task ID/URL
2. If yes → fetch task (`clickup_get_task`)
3. If no task but clear work exists → search for existing tasks or ask which project

## Decompose Before Build

Before implementation:

1. Break into atomic subtasks
2. Create each subtask under parent
3. Do not start implementation until subtasks are created

## Task Description Template

Every task must have a comprehensive description with clear Acceptance Criteria. Use this plain‑text template (no markdown formatting needed for ClickUp):

Context:
Why does this task exist? What problem does it solve?

What to Do:
Step‑by‑step description of the work.

Acceptance Criteria:
- Criterion 1
- Criterion 2
- Criterion N

Notes (optional):
Edge cases, constraints, or additional context.

**Rules:**
- Description must be set via `clickup_create_task` using the `description` or `markdown_description` field.
- Every subtask must have at least 3 concrete, verifiable acceptance criteria.
- Acceptance criteria must be testable/verifiable — not vague.
- Use plain text; avoid markdown symbols that ClickUp does not support.
- Do not create a task without acceptance criteria.

## Progress Updates

- `Open` → `In Progress` when starting
- `In Progress` → `Complete` when done
- Use `clickup_update_task`

## Comment Trail

Add comments for:

- Key technical decisions
- Blockers and resolution
- Scope changes
- Final completion summary

Use `clickup_create_task_comment`.

## Assign

- Parent task: assigned to human initiator
- Subtasks: unassigned unless explicit handoff
- Resolve assignees via `clickup_resolve_assignees`

## Team Members (cached)

| Name                  | User ID    |
| --------------------- | ---------- |
| Alif Amri Suri        | `95638075` |
| Andika Leonardo Surya | `3823593`  |
| Robin Wijaya          | `95590683` |
| Badar Amri Suri       | `95590682` |
| Naufal Dinta          | `95590681` |
| Aditya                | `95590678` |

## Quick Reference

| Action                 | Tool                              |
| ---------------------- | --------------------------------- |
| List hierarchy         | `clickup_get_workspace_hierarchy` |
| Filter tasks by list   | `clickup_filter_tasks`            |
| Search tasks           | `clickup_search`                  |
| Get task               | `clickup_get_task`                |
| Create task/subtask    | `clickup_create_task`             |
| Update task            | `clickup_update_task`             |
| Add comment            | `clickup_create_task_comment`     |
| Create document        | `clickup_create_document`         |
| List doc pages         | `clickup_list_document_pages`     |
| Read doc page(s)       | `clickup_get_document_pages`      |
| Create doc page        | `clickup_create_document_page`    |
| Update doc page        | `clickup_update_document_page`    |
| List workspace members | `clickup_get_workspace_members`   |
| Resolve assignees      | `clickup_resolve_assignees`       |
| Add task dependency    | `clickup_add_task_dependency`     |
