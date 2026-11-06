defmodule Aesir.ZoneServer.Content.Npc.Functions.FEntkafcode do
  @moduledoc """
  Reads and validates a storage password from the player.

  ## Behavior

  Asks for a number between 1000 and 10000000. More than ten attempts in a row aborts the prompt
  and logs the attempt, and an out-of-range answer is refused with its own message. Returns the
  accepted password, or `0` when the player did not supply a valid one.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/functions_kafras.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @shortest_password 1000
  @attempt_limit 10
  @int_max 2_147_483_647

  @doc """
  Callable rAthena global function `F_EntKafCode`; returns the entered storage password or `0`.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), non_neg_integer()}
  def call(ctx, _args) do
    ctx = mes(ctx, "Enter a number 1000~10000000:")
    attempts = get_temp_var(ctx, :kafcode_try, 0) + 1
    ctx = set_temp_var(ctx, :kafcode_try, attempts)

    if attempts > @attempt_limit do
      ctx = ctx |> set_temp_var(:kafcode_try, 0) |> logmes("Tried to fit storage password.")
      {ctx, 0}
    else
      prompt(ctx)
    end
  end

  defp prompt(ctx) do
    {ctx, typed} = input(ctx, :int)
    {outcome, password} = Rathena.input_int(typed, 0, @int_max)
    ctx = set_local(ctx, :code_, password)

    cond do
      outcome == 1 -> {mes(ctx, "You can't use such big password."), 0}
      password < @shortest_password -> {mes(ctx, "You shouldn't use such short password."), 0}
      true -> {ctx, password}
    end
  end
end
