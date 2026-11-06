defmodule Aesir.ZoneServer.Content.Npc.Functions.FCleargarbage do
  @moduledoc """
  Clears quest variables that no script reads any more.

  ## Behavior

  A finished Turtle Island quest folds into the `MISC_QUEST` bit 65536 before the outdated `TURTLE`
  counter is dropped, and the unused DTS flag is removed from `MISC_QUEST`. The remaining
  variables are reset to zero.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Evera
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @turtle_quest_done 65536
  @dts_flag 128

  @variables ~w(
    ADV_QSK ADV_QSK2 RES_SKILL wizard_m2
    NEW_MES_FLAG0 NEW_MES_FLAG1 NEW_MES_FLAG2 NEW_MES_FLAG3 NEW_MES_FLAG4 NEW_MES_FLAG5
    NEW_LVUP0 NEW_LVUP1 NEW_JOBLVUP dtseligible
  )a

  @doc "Callable rAthena global function `F_ClearGarbage`; migrates and clears the old variables."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil}
  def call(ctx, _args) do
    ctx =
      if get_char_var(ctx, :TURTLE, 0) == 20,
        do: fold_turtle_quest(ctx),
        else: ctx

    ctx =
      if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), @turtle_quest_done)),
        do: set_char_var(ctx, :TURTLE, 0),
        else: ctx

    ctx =
      ctx
      |> then(&Enum.reduce(@variables, &1, fn name, ctx -> set_char_var(ctx, name, 0) end))
      |> drop_dts_flag()

    {ctx, nil}
  end

  defp fold_turtle_quest(ctx) do
    set_char_var(
      ctx,
      :MISC_QUEST,
      :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), @turtle_quest_done)
    )
  end

  defp drop_dts_flag(ctx) do
    set_char_var(
      ctx,
      :MISC_QUEST,
      :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), :erlang.bnot(@dts_flag))
    )
  end
end
