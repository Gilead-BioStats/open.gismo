# Overview

open.gismo is an end-to-end platform for running workflows in R using the {workr} package. 

# Design

There are 4 main components that work together to form a fully open source analytics platform: 

- **Database** - Stores raw data, analytics outputs (data, reports) and serves as database for web-frontend 
- **Analytics Engine** - Runs R code using {workr}, reads/writes from database. 
- **Web Front-end** - Summarizes {workr} pipelines, showing data (input and output), code, logs and packages for each set of workflows. 
- **Config** - project folder(s) of pipeline specific {workr} yamls and configuration files. 

This repo provides a sample fully public and open-source implementation, largely for demo purposes, but the approach is highly modular, and a variety of technologies can be used for each component. 

# Database

The database stores all data needed to run the workflows. 

This package uses GitHub (release artifacts and data committed directly to repos) as the default database, but many possible implementations exist including: 
- Supabase
- GitHub: either Action artifacts, release artifacts or data committed directly to repos
- AWS S3 bucket + DuckDB

# Analytics Engine

The analytics engine loads all needed packages and executes the workflows using {workr}. It pulls data from the database using custom `lConfig.saveData` and `lConfig.loadData` hooks in [`workr::RunWorkflow`](https://github.com/Gilead-BioStats/workr/blob/main/R/RunWorkflow.R) 

This package uses GitHub Actions as the default analytics engine, but many possible implementations exist including: 

- GitHub Actions
- R Shiny App (possibly with WASM)
- AWS framework (e.g. via lambdas)

# Web Front-end

The web front-end provides a user-friendly interface to explore {workr} pipelines. Data is served from the database, pipeline specific data is read from the config. A prototype of the front-end is available at https://github.com/Gilead-BioStats/workr/tree/main/site

Users can: 

- See a list of projects
- View a summary of the overall workflows for a given project
- View details for each step (each workr .yaml file) including the input/output data
- View the data model at each step of the model

This package uses GitHub Pages as the default front-end, but many possible implementations exist including: 

- GitHub Pages (used in Prototype)
- React/Next.js hosted on Vercel or similar

# Config

YAML workflow and config files are typically saved in folders in GitHub Repos (but could be pulled from other locations). A set of example projects to be used for development and testing are saved [here](https://github.com/Gilead-BioStats/workr/tree/dev/inst/workflows)

# AI Skills

open.gismo is designed for AI-assisted development with extensive human review. The platform includes two resources to support this workflow:

- **Agent Development Instructions (AGENTS.md)** — A comprehensive development guide covering the multi-language, multi-component nature of the platform (R packages, GitHub Actions YAML, JavaScript/Vite front-end, config YAMLs). Includes component-specific development workflows, testing instructions per component, PR/review workflow, architecture overview, and interface contracts between components.
- **Generic AI Agent Skills** — A set of tool-agnostic structured markdown files that provide step-by-step instructions for common development tasks (e.g., adding a workflow YAML, implementing a new lConfig hook, adding a front-end view, running a pipeline, creating snapshots). These skills are not tied to any specific AI coding assistant and can be followed by any agent or human developer.