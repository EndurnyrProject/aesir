defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler do
  @moduledoc """
  Entry point of the rAthena item-script transpiler, with two independent
  targets sharing the same `Lexer` -> `Parser` front end:

  - `transpile/1` — a raw rAthena usable-item `Script` string -> an Aesir
    `on_use` DSL **source string**, via `Codegen`. The `on_use` corpus is small
    (usable items), so compiling to code is affordable: `ScriptCompiler` turns
    the string into a generated module clause.
  - `transpile_equip/1` — a raw rAthena equip-item `Script` string -> an
    `EquipScript.program()` **data term**, via `EquipCodegen`. The equip corpus
    is huge (~13k items), so the target is interpreted data evaluated at stats
    recompute time instead of generated code — the same BEAM clause-count
    ceiling that is fine for `on_use` would not be for `on_equip`.

  Lexer errors, `{:error, {:parse_error, _}}` and `{:error, {:unsupported, _}}`
  are surfaced unchanged from both entry points so the importer can record them
  in its coverage report; nothing is raised for a malformed or unsupported
  script. No randomness happens at transpile time, so the same script always
  yields the same result.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Codegen
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Parser

  @spec transpile(String.t()) :: {:ok, String.t()} | {:error, term()}
  def transpile(script) when is_binary(script) do
    with {:ok, tokens} <- Lexer.tokenize(script),
         {:ok, ast} <- Parser.parse(tokens) do
      Codegen.generate(ast)
    end
  end

  @spec transpile_equip(String.t()) :: {:ok, EquipScript.program()} | {:error, term()}
  def transpile_equip(script) when is_binary(script) do
    with {:ok, tokens} <- Lexer.tokenize(script),
         {:ok, ast} <- Parser.parse(tokens) do
      EquipCodegen.generate(ast)
    end
  end
end
