defmodule Aesir.ZoneServer.Content.Npc.Functions.FSavequestskills do
  @moduledoc """
  Records the first and second class quest skills the character has learnt.

  ## Behavior

  Each learnt skill sets its bit in `ADV_QSK` (first class, ids 144 to 157) or `ADV_QSK2` (second
  class, ids 1001 to 1019), so `F_Load1Skills` and `F_Load2Skills` can grant them again after a
  skill reset.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @first_skill 144
  @first_skills 14
  @second_skill 1001
  @second_skills 19

  @doc "Callable rAthena global function `F_SaveQuestSkills`; rewrites both skill masks."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil}
  def call(ctx, _args) do
    ctx =
      ctx
      |> set_char_var(:ADV_QSK, 0)
      |> set_char_var(:ADV_QSK2, 0)
      |> save(:ADV_QSK, @first_skill, @first_skills)
      |> save(:ADV_QSK2, @second_skill, @second_skills)

    {ctx, nil}
  end

  defp save(ctx, variable, first_skill, skills) do
    Enum.reduce(0..(skills - 1), ctx, fn index, ctx ->
      if Rathena.truthy?(getskilllv(ctx, first_skill + index)) do
        set_char_var(
          ctx,
          variable,
          :erlang.bor(get_char_var(ctx, variable, 0), Rathena.pow(2, index))
        )
      else
        ctx
      end
    end)
  end
end
