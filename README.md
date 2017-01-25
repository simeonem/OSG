# OSG - Open Science Grid
This repository starts a new effort in generating a workflow for running R scripts in Condor-OSG.
The intent is to make the workflow as much as possible compatible with most batch systems (e.g., Condor-OSG, Slurm-XSEDE, PBS,...).
The initial plan is to develop the workflow in Pegasus, but we will entartain other possibilities if viable and useful (e.g., makeflow,...).
We are planning to use accounts on OSG with unlimited cpu hrs to run our short burst jobs.
The pilot tests will be conducted using a version of the CBDA-SL with Knockoff algorithm that is being developed here https://github.com/SOCR/CBDA

If successful, we will be able to run tens of thousands of jobs in parallel within few minutes.
Challenges might be represented by extremely large dataset to mine (~GBs). We are interested in addressing that as well, as soon as a prototype workflow is successfully tested on OSG to "solve" small/medium size feature/model mining problems.
