defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler do
  @moduledoc """
  Entry point of the rAthena item-script transpiler: a raw rAthena usable-item
  `Script` string -> an Aesir `on_use` DSL source string.

  Chains the three pure stages — `Lexer` -> `Parser` -> `Codegen` — behind a
  single `transpile/1`. Lexer errors, `{:error, {:parse_error, _}}` and
  `{:error, {:unsupported, _}}` are surfaced unchanged so the importer can record
  them in its coverage report; nothing is raised for a malformed or unsupported
  script. No randomness happens at transpile time, so the same script always
  yields the same string.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Codegen
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Parser

  @spec transpile(String.t()) :: {:ok, String.t()} | {:error, term()}
  def transpile(script) when is_binary(script) do
    with {:ok, tokens} <- Lexer.tokenize(script),
         {:ok, ast} <- Parser.parse(tokens) do
      Codegen.generate(ast)
    end
  end
end
