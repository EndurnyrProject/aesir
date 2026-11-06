defmodule Aesir.ZoneServer.Content.Npc.Functions.FCanopenstorage do
  @moduledoc """
  Reports whether the attached player may open a storage.

  ## Behavior

  A player who has not completed the basic skill check is always allowed. Otherwise Basic Skill
  must be at least level 6, or the Super Novice basic skill at least level 1.

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

  @doc "Callable rAthena global function `F_CanOpenStorage`; returns `1` when storage may be opened."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), 0 | 1}
  def call(ctx, _args) do
    qualified? = getskilllv(ctx, 1) >= 6 or getskilllv(ctx, :su_basic_skill) >= 1

    {ctx, Rathena.bool_int(not Rathena.truthy?(basicskillcheck(ctx)) or qualified?)}
  end
end
