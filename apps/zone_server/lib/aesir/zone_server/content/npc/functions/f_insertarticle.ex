defmodule Aesir.ZoneServer.Content.Npc.Functions.FInsertarticle do
  @moduledoc """
  Prefixes a word with the indefinite article that matches it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Content.Npc.Functions.FGetarticle
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc """
  Callable rAthena global function `F_InsertArticle(word, uppercase)`; returns the article followed
  by the word, capitalizing the article when the second argument is non-zero.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    word = Enum.at(args, 0, 0)
    {ctx, article} = FGetarticle.call(ctx, [word])

    article =
      if Rathena.truthy?(Enum.at(args, 1, 0)),
        do: Rathena.replacestr(article, "a", "A"),
        else: article

    {ctx, Rathena.format("%s %s", [article, word])}
  end
end
