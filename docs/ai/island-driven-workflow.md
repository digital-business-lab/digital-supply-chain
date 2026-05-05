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
4. Expand one task into a detailed concept note, not production code.
5. Review and validate.
6. Repeat.

## Implementation steps

1. Capture the island goal.
2. List core components.
3. Define the first milestone.
4. Draft the concept details for later AI implementation. Do not write the actual code yet. Mark every assumption explicitly with `Assumption:` so it can be clarified later.
5. Review against the repo.
6. Move to the next milestone.

## Task format

Use a simple format:

- `task`: short sentence
- `output`: what success looks like
- `notes`: special requirements
- `assumptions`: open assumptions that still need clarification before implementation

### Example

- task: "Describe the Farm island LoRaWAN architecture"
- output: "A short concept note with hardware, services, interfaces, and implementation-ready acceptance criteria"
- notes: "Keep it aligned with `docs/islands/farm/index.md` style and stay conceptual"
- assumptions: "Assumption: the selected LoRaWAN gateway remains part of the current farm island hardware plan"

## Validation

- Review generated content manually.
- Update the island spec when gaps appear.
- Mark concept tasks done when the concept aligns with the current repo constraints.
- Mark implementation tasks done only when docs and implementation align.
