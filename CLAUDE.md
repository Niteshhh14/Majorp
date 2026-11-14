# Instructions for Claude Code

Read `PROJECT_CONTEXT_FOR_CLAUDE.md` before changing this project. It is the current handoff: project purpose, architecture, evidence, caveats, and next safe action. `WALKTHROUGH.md` preserves the longer chronology; `TEAMMATE_PROMPT.txt` is the concise task prompt. For research scope, read `Base_papers/RELATED_WORK_AND_GAP.md` and `Base_papers/RESEARCH_DIRECTION_AND_BENCHMARK_PLAN.md`. For neural implementation, read `DeepLearning/README.md` and `DeepLearning/CLARITY_METRICS_SETUP.md`.

## Project constraints

- The intended product is one hearing-aid speech enhancement chain: neural noise enhancement followed by the existing MATLAB CVBW audiogram fitting. Keep CVBW functional and in the final chain; it is not the primary research contribution.
- Treat unprocessed speech, spectral subtraction, and current neural checkpoints as evaluation baselines. AECRN is a direct external reference. Do not describe generic audiogram conditioning or “DL + CVBW” as novel.
- The project research goal is explicitly paused. Documentation and handoff work is authorized; do not start training, long MATLAB runs, or new experiments unless the user resumes the research work.
- Never claim improvement, novelty, clinical benefit, or a fair numerical comparison to AECRN without evidence. Report per-profile results, valid sample counts, uncertainty, compute/latency boundary, and metric limitations. Negative/mixed results are first-class results.
- Preserve the fixed speaker-disjoint test set. Choose methods using training/validation only. Current noise scenes are not split-disjoint; disclose this limitation.
- Preserve the production CVBW default (`normalizePeak=true`). The raw level-preserving diagnostic produces implausible levels under the project's assumed SPL mapping and is not a valid route to aided-intelligibility claims.
- Do not attach example audiogram presets to VCTK speakers as if measured from those speakers. They are controlled profile conditions, not patient data.

## Working safely

- Treat MATLAB source as authoritative for CVBW and baseline behavior. Check call signatures and defaults before modifying either.
- Keep generated audio/checkpoints, datasets, `.venv`, `.runtime`, `.matlabprefs`, and large binary results out of Git unless specifically requested.
- Do not modify or stage `PROJECT_FAMILIARIZATION_GUIDE.docx`, its `~$` lock file, or the user-supplied AECRN PDF in `Base_papers/`.
- Make changes narrowly. Do not overwrite existing result directories; create a new named experiment folder with config, commands, per-case results, summary, and failures.
- After meaningful project changes, update `PROJECT_CONTEXT_FOR_CLAUDE.md` and `WALKTHROUGH.md`; keep `TEAMMATE_PROMPT.txt` pointed at the current task. Separate measured results from interpretation/hypotheses.
- Use PowerShell for Windows commands. Check `git status` before staging and stage only intended text/source files. Remote is `https://github.com/Niteshhh14/Majorp.git`.

## Current research continuation point

The next queued, small validation-only action is to score the already generated 25% neural-strength probe with official Clarity metrics on profile-1 cases `1,5,9,13,17,21,25,29`. Exact command and interpretation safeguards are in `PROJECT_CONTEXT_FOR_CLAUDE.md`. Compare only with the same eight scenes in the original neural, 50% blend, and classical artifacts. Do not treat SI-SDR/STOI as a proxy for missing HASPI/HASQI. After that report the trade-off; do not automatically promote the blend or start training.
