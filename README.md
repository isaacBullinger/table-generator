# Neovim Table Generator

A lightweight Neovim plugin for generating, editing, and importing ASCII tables from CSV files.

## Features

- Generate tables from comma-separated values
- Import and render `.csv` files as ASCII tables
- Edit rendered tables
- Word-wrap and column width are adjusted automatically
- Minimal floating input UI with keyboard shortcuts

## Commands

- `:Table`  
  Opens a floating window to input a new table. Values must be double-quoted and comma-separated. Width can be specified in characters. The first row is treated as the header.

- `:TableImport`  
  Prompts for a `.csv` filename (without extension) and inserts the corresponding ASCII table into the current buffer.

- `:TableEdit`  
  With the cursor inside an existing table, opens the corresponding `.csv` file for editing. Upon saving, replaces the old table with the updated version. It also replaces the related `.csv` file.

## CSV Format

Tables are backed by a `.csv` file formatted as:

40
"header 1","header 2","header 3"
"row 1 col 1","row 1 col 2","row 1 col 3"

The first line specifies the max width of the table in characters.

## Installation

Download the files and put it in your Lua config folder for NeoVim. Add this to your main config file:

require ("table-generator").setup()
