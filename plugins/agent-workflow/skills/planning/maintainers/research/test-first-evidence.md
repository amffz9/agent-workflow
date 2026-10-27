# Test-first evidence for LLM coding agents (researched 2026-10-05)

Bottom line [inferred]: evidence supports "an executable check that discriminates between claims" as a way to settle disputes and to filter fixes. It does NOT support "agents that write more tests while coding do better." Results come from abstracts and search summaries only; full papers were mostly not read.

## 1. TDD / test-first with LLMs
- Tests given alongside the problem raise pass rates on small benchmarks. [quoted] "including test cases leads to higher success in solving programming challenges" (Mathews & Nagappan, arXiv 2402.13521, Feb 2024, rev. Jun 2024). Search snippet gave +12.0% (MBPP) and +8.5% (HumanEval) more problems solved; I did not verify these in the paper. Function-level tasks only; these tests were supplied, not agent-written.
- Test-driven intent clarification (TiCoder): [quoted] "average absolute improvement of 45.97% in pass@1" within 5 user interactions, MBPP/HumanEval, four LLMs (arXiv 2404.10100, Apr 2024). Needs a user to approve tests; sample size not seen.
- WebApp1K (arXiv 2505.09027, 2025): 1000 test-driven React tasks; [quoted] performance is "governed by the model's ability to extract and obey specifications encoded in test code." Shows tests work as specs; no tests-vs-no-tests comparison seen.
- Null/negative for agent-written tests: "Rethinking the Value of Agent-Generated Tests" (arXiv 2602.07900, Feb 2026, rev. Apr 2026). Six LLMs on SWE-bench Verified. [quoted] "resolved and unresolved tasks within the same model exhibit similar test-writing frequencies"; prompts that raised or lowered test writing (four models) "do not significantly change final outcomes"; "print statements appear much more often than assertion-based checks". Forcing tests added cost without better success. Test volume affects cost and process, not success. Effect sizes and N not seen.
- No controlled study found comparing test-first vs plan-first vs test-after for agents on cost or time. Practitioner guidance (Anthropic best practices, https://code.claude.com/docs/en/best-practices ) is experience, not measurement. [inferred]

## 2. Reproduction-first bug fixing
- SWT-Bench (Mündler et al., arXiv 2406.12952, Jun 2024, rev. Feb 2025): [quoted] "Code Agents designed for code repair exceeding the performance of systems designed specifically for test generation"; using generated tests to filter fixes is [quoted] "doubling the precision of SWE-Agent." Reproduction tests as a filter has the strongest support found. Precision, not resolve rate.
- Otter / TestPrune (arXiv 2510.18270, v2 May 2026): selected regression tests raise reproduction rate 6.2%-9.0% relative and resolution 8.0%-12.9% relative (Agentless, SWE-agent, Trae), cost per instance down 8.0%-23.0%. Mixed: TestPrune "helped in 49 instances but also hurt performance in 35"; adding tests broke 8 (SWE-agent) and 17 (Trae) previously resolved instances. Gains are relative, small, and not net-positive per instance.
- SWE-Doctor (arXiv 2607.00990, 2026): +8.0-8.9 points on SWE-bench Pro from multi-faceted bug-reproduction tests with runtime diagnosis (search summary only; not opened).
- Tension [inferred]: reproduction tests help when executed and used as a verifier/diagnostic (SWT-Bench, SWE-Doctor), while merely encouraging agents to write more tests does nothing (2602.07900).

## 3. Weak or self-confirming agent tests
- Oracles mirror behaviour: [quoted] LLMs "generate oracles that capture the actual program behaviour rather than the expected one" (Konstantinou et al., arXiv 2410.21136, Oct 2024; 24 Java repos). Test written after code inherits the code's bugs.
- Coverage misleads: [quoted] "some test suites achieve 100% coverage but only 4% mutation score" (MUTGEN, arXiv 2506.02954, TSE, rev. Apr 2026; 204 subjects). Mutation feedback in the prompt beat EvoSuite and plain prompting.
- Building to the test (arXiv 2606.28430, Jun 2026): Claude Opus 4.7 and GPT-5.5, 18 runs, hidden 222-test Playwright suite. Agents given the tests scored near-perfect while shipping dead or absent functionality; [quoted] "the agent does not, on its own, validate what it ships as a user would." Small N, one task. Tests given up front can be gamed too.
- Practitioner: agents edit tests to go green; commit failing tests first and review any test diff (Anthropic best-practices page above; secondary guides). Blog claims of "independent evaluator" and mutation testing (awesome-testing.com Aug 2026; zylos.ai Jul 2026) are unmeasured advice. [inferred]
- Mitigations with evidence: mutation feedback (MUTGEN); hidden or independent tests (2606.28430, by implication); executing tests against the unfixed code to confirm failure (SWT-Bench fail-to-pass criterion).

## 4. Spec-driven vs test/example-driven
- No controlled comparison found. Sources are vendor and practitioner pieces (Augment, Devoteam, DEV Community 2026) asserting specs as "executable contracts." Consort (arXiv 2609.09671, Sep 2026) argues for controls agents cannot bypass (immutable tests, human gates) over prompt persuasion; it states a "pre-registered, testable hypothesis" and gives no numbers. Treat as opinion. [inferred]

## What I would put in a planning skill
1. A claimed bug in a plan or design must come with a failing test or script that runs against the current code (or a stated reason it cannot). Unproven claims are marked "suspected" and do not block. [inferred; supported by SWT-Bench filtering, the user's own observation]
2. The reviewer, not the author, writes or runs the repro; the author may rebut only with a passing counter-test or a named wrong assumption. Caps debate at one round per claim. [inferred; mirror-oracle and self-confirmation findings]
3. Confirm each test fails for the claimed reason before accepting it (red check), and re-run after the fix. [sourced: SWT-Bench fail-to-pass; Anthropic best practices]
4. Do not require agents to write tests for every task or as a volume target; require assertion-based checks only where a behavioural claim is in dispute or a fix is accepted. [sourced: 2602.07900 null result]
5. Commit failing tests before implementing, forbid editing them without review, and keep some acceptance checks hidden from the implementer. [sourced: Anthropic practice; 2606.28430 gaming]
6. Judge test quality by mutation or negative controls, not coverage, for high-stakes modules. [sourced: MUTGEN 4% mutation at 100% coverage]
