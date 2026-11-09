defmodule Aesir.ZoneServer.Content.Npc.Functions.FPartyrelayExp do
  @moduledoc """
  Grants the Party Relay quest's base experience reward by base level bracket.

  ## Behavior

  - Picks the bracket from the player's base level (50, 60, 70, 80, 90 and 95 steps).
  - Renewal pays one tenth of the pre-renewal amount for every bracket.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/partyrelay.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @pre_renewal_exp [
    {94, 1_047_600},
    {89, 859_200},
    {79, 385_200},
    {69, 195_600},
    {59, 67_200},
    {49, 28_800},
    {0, 10_800}
  ]

  @doc "Callable rAthena global function; returns `{ctx, return_value}`."
  @spec call(Ctx.t(), list()) :: {Ctx.t(), nil}
  def call(ctx, _args) do
    renewal? = Rathena.truthy?(checkre(ctx, 3))
    level = base_level(ctx)
    {_min_level, exp} = Enum.find(@pre_renewal_exp, fn {min_level, _exp} -> level > min_level end)

    {getexp(ctx, if(renewal?, do: div(exp, 10), else: exp), 0), nil}
  end
end
