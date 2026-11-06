defmodule Aesir.ZoneServer.Content.Npc.Functions.FCheckkafcode do
  @moduledoc """
  Asks for the storage password before opening a protected storage.

  ## Behavior

  Does nothing when no password is set. A wrong password shows the reason and ends the script;
  a correct one resets the failed-attempt counter and lets the caller continue.

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

  @doc """
  Callable rAthena global function `F_CheckKafCode`; returns `{ctx, nil}`, or throws
  `{:script_end, ctx}` after a wrong password.
  """
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, _args) do
    if Rathena.truthy?(get_account_var(ctx, "#kafra_code", 0)) do
      check(ctx)
    else
      {ctx, nil}
    end
  end

  defp check(ctx) do
    ctx = mes(ctx, "Enter your storage password:")
    {ctx, typed} = input(ctx, :int)

    if typed == get_account_var(ctx, "#kafra_code", 0) do
      {set_temp_var(ctx, :kafcode_try, 0), nil}
    else
      ctx = ctx |> dispbottom("Wrong storage password.") |> close() |> cutin("", 255)
      throw({:script_end, ctx})
    end
  end
end
