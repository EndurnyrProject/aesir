defmodule Aesir.ZoneServer.Content.Npc.Functions.FCanchangejob do
  @moduledoc """
  Reports whether the attached player may advance to a first class.

  ## Behavior

  A player who has not completed the basic skill check is always allowed, as every normal and
  advanced class skips it. Otherwise Basic Skill must be above level 8.

  ## Credits

  - Original from rAthena, authors and Contributors
    - secretdataz

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Callable rAthena global function `F_CanChangeJob`; returns `1` when the change is allowed."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), 0 | 1}
  def call(ctx, _args) do
    {ctx, Rathena.bool_int(not Rathena.truthy?(basicskillcheck(ctx)) or getskilllv(ctx, 1) > 8)}
  end
end
