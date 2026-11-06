defmodule Aesir.ZoneServer.Content.Npc.Functions.FGetarticle do
  @moduledoc """
  Returns the indefinite article that matches a word.

  ## Behavior

  The word is lowercased before it is classified, so casing does not matter for the article
  itself. Non-words, consonants and the vowel forms that take `a` (`one`, `euro`, `ukulele`, ...)
  resolve to `a`; silent-h and vowel forms resolve to `an`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @one_letter_an "aefhilmnorsx"
  @a_vowel_forms ["^e[uw]", "^onc?eb", "^uni([^nmd]|mo)", "^u[bcfhjkqrst][aeiou]"]

  @doc "Callable rAthena global function `F_GetArticle(word)`; returns `a` or `an`."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args), do: {ctx, article(Enum.at(args, 0, 0))}

  defp article(word) do
    word = Rathena.strtolower(word)

    cond do
      not Rathena.truthy?(Rathena.charisalpha(word, 0)) ->
        "a"

      Rathena.getstrlen(word) == 1 ->
        if Rathena.strpos(@one_letter_an, word) > -1, do: "an", else: "a"

      matches?(word, "(euler|hour(?!i)|heir|honest|hono)") ->
        "an"

      matches?(word, "^[^aeiouy]") ->
        "a"

      Enum.any?(@a_vowel_forms, &matches?(word, &1)) ->
        "a"

      matches?(word, "^ut[th]") ->
        "an"

      matches?(word, "^[aeiou]") ->
        "an"

      true ->
        "a"
    end
  end

  defp matches?(word, patterns) when is_list(patterns),
    do: Enum.any?(patterns, &matches?(word, &1))

  defp matches?(word, pattern), do: Rathena.truthy?(Rathena.preg_match(pattern, word))
end
