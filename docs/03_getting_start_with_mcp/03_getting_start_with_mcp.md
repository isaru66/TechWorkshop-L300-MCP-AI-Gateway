---
title: 'Exercise 03: Getting started with MCP'
layout: default
nav_order: 4
has_children: true
---

# Exercise 03: Getting started with MCP

## Scenario

In this exercise, you will get hands-on experience with the Model Context Protocol (MCP) by running a simple MCP weather mock server. You will learn how to run an MCP server locally, test it using various tools, and then build and deploy it to Azure Container Apps.

The MCP Weather Mock server is a simple Python-based MCP server that exposes two tools: `get_cities` (returns a list of cities for a given country) and `get_weather` (returns mock weather information for a given city). This is a great starting point to understand how MCP servers work before building more complex solutions.

## Objectives

After you complete this exercise, you will be able to:

* Run an MCP server locally using Python
* Test MCP endpoints using the MCP Inspector and HTTP requests
* Build a Docker image for an MCP server
* Deploy an MCP server to Azure Container Apps

## Duration

* **Estimated Time:** 45 minutes
