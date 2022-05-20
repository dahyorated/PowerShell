[[_TOC_]]
# Token Replacement

## Process to Modify Token Replacement Value in a Release
*Steps*
1. Edit the pipeline and add the new variable or update its value.
1. Edit the release that needed to be updated and add the new variable or update its value.
1. Deploy (or redeploy) the release to the requested environments.

*n.b.* When adding token replacement values, always add pairs as follows:
- DEV/QAT
- UAT/PRF
- STG/PRD
