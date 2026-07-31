# tracking

Habit-completion logging domain, data and presentation layers. HBM-15 owns the
daily done/partial/skipped UI and note editing. HBM-16 persists local writes,
queues idempotent upserts, retries on authentication/app resume and exposes
pending or conflict state without changing the network-first behavior of other
features.

Jira: epic `HBM-4`, tickets `HBM-15`, `HBM-16`.
