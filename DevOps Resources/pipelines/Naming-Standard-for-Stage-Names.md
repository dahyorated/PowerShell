# Naming Standard for Stage Names
All CTP release pipelines will use a standardized set of stage names.
The use of standardized names will simplifying the learning curve for new staff, will ease the job of developers, and will support automation of processing information about pipelines and releases.

## Stage Name Parts
A stage name will have 2 to 3 parts. The first two parts are mandatory. The third part is used when pipelines need multiple jobs for a single stage.
The format for a stage name is `{Part1}-{Part2}[-{Part3}]`.

| `{Part*}` | Usage |
| ---- | ----- |
| Part1 | [The standardized name for the environment](#standard-environment-names). |
| Part2 | [The standardized name for the Azure region](#standard-region-names). |
| Part3 | The pipeline specific name for distinguishing jobs in the same environment and region. |

## Standard Environment Names
All environment names will be three characters. Here are the standard names and respective environments.

| Name | Environment |
| ---- | ----------- |
| DEV | Development |
| QAT | Quality Assurance Testing |
| PRF | Performance Testing |
| UAT | User Acceptance Testing |
| STG | Staging |
| DMO | Demo for Client |
| PRD | Production |

## Standard Region Names
All region names will be three characters. Here are the standard names and respective Azure region.

| Name | Azure Region |
| ---- | ------------ |
| euw | West Europe |
| use | East US |
| us2 | East US 2 |

## Part3 Usage
`{Part3}` is used when there is a need for multiple jobs within an environment and regions combination.
This is used, for example, when there is a job for each client (as in Boardwalk).

If the distinguisher is a client, `{Part3}` should be `Cnnnnn` 
where `nnnnn` is the client identifier with left zero padding.
