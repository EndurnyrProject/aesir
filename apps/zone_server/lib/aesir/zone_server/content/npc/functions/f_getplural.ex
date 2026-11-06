defmodule Aesir.ZoneServer.Content.Npc.Functions.FGetplural do
  @moduledoc """
  Returns the plural form of an English noun.

  ## Behavior

  In a multi-word phrase the word before `of`, `in` or `on` is pluralized, otherwise the last one
  is, and the rest of the phrase is kept. The result is uppercased when the second argument is
  non-zero. Words shorter than three characters are returned without a suffix.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @alphabet "abcdefghijklmnopqrstuvwxyz"
  @vowels "aeiou"
  @connectors "of|in|on"
  @connector_phrases [" of ", " in ", " on "]

  @unchanged "fish|glasses|sunglasses|clothes|boots|shoes|greaves|sandals|wings|ears"
  @add_s_after_f "belief|cliff|chief|dwarf|grief|gulf|proof|roof"

  @add_es_after_o "buffalo|domino|echo|grotto|halo|hero|mango|mosquito|potato|tomato|tornado|torpedo|veto|volcano"

  @doc """
  Callable rAthena global function `F_GetPlural(noun, uppercase)`; returns the plural phrase.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    {template, word} = target(Enum.at(args, 0, 0))
    rendered = Rathena.format(template, [pluralize(word)])

    plural =
      if Rathena.truthy?(Enum.at(args, 1, 0)), do: Rathena.strtoupper(rendered), else: rendered

    {ctx, plural}
  end

  defp target(phrase) do
    if Rathena.truthy?(Rathena.countstr(phrase, " ")) do
      words = Rathena.explode(phrase, " ")
      index = target_index(phrase, words)

      {words |> List.replace_at(index, "%s") |> Enum.join(" "), Enum.at(words, index, "")}
    else
      {"%s", phrase}
    end
  end

  defp target_index(phrase, words) do
    if Enum.any?(@connector_phrases, &contained?(phrase, &1)) do
      Enum.find_index(Enum.drop(words, 1), &connector?/1) || length(words) - 1
    else
      length(words) - 1
    end
  end

  defp connector?(word) do
    Rathena.getstrlen(word) == 2 and contained?(@connectors, word)
  end

  defp pluralize(word) do
    word = to_string(word)
    length = Rathena.getstrlen(word)
    last = Rathena.charat(word, length - 1)
    tail = Rathena.substr(word, length - 2, length - 1)

    cond do
      length < 3 ->
        word

      not letter?(last) ->
        word

      contained?(@unchanged, word) ->
        word

      last in ["s", "x", "z"] or tail in ["ch", "sh"] ->
        word <> "es"

      (last == "f" or tail == "fe") and tail != "ff" ->
        if contained?(@add_s_after_f, word), do: word <> "s", else: f_to_ves(word, length)

      last == "y" and not vowel?(Rathena.charat(tail, 0)) ->
        Rathena.delchar(word, length - 1) <> "ies"

      last == "o" and contained?(@add_es_after_o, word) ->
        word <> "es"

      true ->
        word <> "s"
    end
  end

  defp f_to_ves(word, length) do
    tail = Rathena.substr(word, length - 2, length - 1)
    cut = length - 2 - if(tail == "fe", do: 1, else: 0)

    Rathena.substr(word, 0, cut) <> "ves"
  end

  defp letter?(character), do: contained?(@alphabet, character)
  defp vowel?(character), do: contained?(@vowels, character)
  defp contained?(string, substring), do: Rathena.truthy?(Rathena.compare(string, substring))
end
