defmodule Aesir.ZoneServer.Content.Npc.Functions.JobChange do
  @moduledoc """
  Changes the attached player's class.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @doc """
  Callable rAthena global function `Job_Change(class)`; changes the class and returns `{ctx, nil}`.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil}
  def call(ctx, args), do: {jobchange(ctx, Enum.at(args, 0, 0)), nil}
end
