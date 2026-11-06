defmodule Aesir.ZoneServer.Content.Npc.Functions.FLoad1skills do
  @moduledoc """
  Restores the first class quest skills saved by `F_SaveQuestSkills`.

  ## Behavior

  A non-empty saved mask restores every first class quest skill, not only the saved ones; the mask
  is compared with a single bit rather than tested bitwise. The saved variable is cleared
  afterwards.

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
  @skills 14

  @doc "Callable rAthena global function `F_Load1Skills`; grants the saved skills and clears them."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil}
  def call(ctx, _args) do
    ctx =
      Enum.reduce(0..(@skills - 1), ctx, &restore(&2, :ADV_QSK, @first_skill, &1))

    {set_char_var(ctx, :ADV_QSK, 0), nil}
  end

  defp restore(ctx, variable, first_skill, index) do
    mask = get_char_var(ctx, variable, 0)

    # The reference groups `mask | pow(2, index) == mask` as `mask | (pow(2, index) == mask)`,
    # so a non-zero mask restores every skill.
    saved? = Rathena.truthy?(:erlang.bor(mask, Rathena.bool_int(Rathena.pow(2, index) == mask)))

    if saved?, do: skill(ctx, first_skill + index, 1, 0), else: ctx
  end
end
