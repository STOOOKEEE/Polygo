# Polygo — instructions for Codex agents

## Roles

If you are the root/primary agent, act only as the coordinator. Do not write or modify code, apply patches, implement features, or run implementation commands yourself. Delegate all research, design, implementation, integration, builds, and tests to worker agents.

If you are a delegated worker agent, perform only the assigned task and report the files changed, decisions made, tests run, and remaining blockers.

## Delegation

The root/primary agent must delegate implementation work to agents using the model Luna Max with `priority: default`. Independent tasks should run in parallel. Use a dedicated integration agent for merges and a dedicated QA agent for final validation.

## Git delivery

The project is hosted at `https://github.com/STOOOKEEE/Polygo`.

At the end of every coherent milestone, the integration/release agent must:

1. inspect `git status` and the complete diff;
2. run the relevant checks and tests;
3. ensure secrets, credentials, local databases, and machine-specific files are ignored;
4. create a descriptive commit containing all in-scope changes;
5. push the commit to `origin main`.

Do not leave completed work only in the working tree. Do not force-push, rewrite history, discard unrelated changes, or overwrite unexpected remote commits. If pushing fails, report the exact blocker and keep the commit locally available.

## Product scope

Build an original Mandarin-learning application for iPhone, iPad, and macOS. It may be inspired by publicly observable learning patterns from HelloChinese, but all branding, UI, exercises, text, audio, video, illustrations, and code must be original or properly licensed. Do not scrape or bypass paywalls.

The product should include structured HSK-aligned lessons, pinyin and tones, vocabulary, grammar, listening, speaking, handwriting, selectable words with audio, graded reading, flashcards with spaced repetition, progress tracking, offline use, and cross-device synchronization.
