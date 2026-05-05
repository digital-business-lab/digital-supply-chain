# Island-Driven Workflow

Use AI to document and refine the repo one island at a time.

## Recommended structure

- `docs/ai/index.md`
- `docs/ai/island-driven-workflow.md`
- `docs/islands/<island>/index.md`
- `docs/islands/<island>/*.md`

## Workflow

1. Choose an island.
2. Define its goal.
3. Write a rough task list.
4. Expand one task into docs or an implementation note.
5. Review and validate.
6. Repeat.

## Implementation steps

1. Capture the island goal.
2. List core components.
3. Define the first milestone.
4. Draft the doc or task details.
5. Review against the repo.
6. Move to the next milestone.

## Task format

Use a simple format:

- `task`: short sentence
- `output`: what success looks like
- `notes`: special requirements

### Example

- task: "Describe the Farm island LoRaWAN architecture"
- output: "A short markdown section with hardware, services, and integration points"
- notes: "Keep it aligned with `docs/islands/farm/index.md` style"

## Validation

- Review generated content manually.
- Update the island spec when gaps appear.
- Mark tasks done only when docs and implementation align.
