defmodule Aesir.ZoneServer.Content.Npc.Functions.FGmNpc do
  @moduledoc """
  Gates the official GM management NPCs to GM level 99 and optionally checks a password.

  ## Behavior

  - A player below GM level 99 is logged as having tried the NPC, and the whole script ends.
  - Called with no arguments, it only applies that gate.
  - `callfunc("F_GM_NPC", password, 0{, min, max})` asks for a number. It returns `1` for the
    password, `0` for another number, `-1` for zero (or a cancel), and `-2` for a number outside
    `min..max` when a `max` is given.
  - `callfunc("F_GM_NPC", password, 1)` asks for a string and returns `1` when it matches,
    otherwise `0`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Its input values stay out of the caller's `.@` variables, as in the function's own scope
    upstream.
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @gm_level 99

  @doc "Callable rAthena global function `F_GM_NPC`; returns `{ctx, result}`."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), integer() | nil}
  def call(ctx, args) do
    if getgmlevel(ctx) < @gm_level, do: reject(ctx)

    case args do
      [] -> {ctx, nil}
      [password | rest] -> check_password(ctx, password, rest)
    end
  end

  defp reject(ctx) do
    {map, x, y} = getmapxy(ctx, :npc)

    ctx =
      logmes(
        ctx,
        "#{char_name(ctx, 0)} attempted to access GM NPC #{strnpcinfo(ctx, 0)} (#{map},#{x},#{y})."
      )

    throw({:script_end, ctx})
  end

  defp check_password(ctx, password, rest) do
    if Enum.at(rest, 0, 0) == 0 do
      check_number(ctx, password, Enum.at(rest, 1, 0), Enum.at(rest, 2, 0))
    else
      {ctx, typed} = input(ctx, :string)
      {ctx, matches(typed, password)}
    end
  end

  defp check_number(ctx, password, min, max) do
    {ctx, typed} = input(ctx, :int)

    {error, number} =
      if Rathena.truthy?(max), do: Rathena.input_int(typed, min, max), else: {0, typed}

    cond do
      Rathena.truthy?(error) -> {ctx, -2}
      number == 0 -> {ctx, -1}
      true -> {ctx, matches(number, password)}
    end
  end

  defp matches(typed, password), do: if(typed == password, do: 1, else: 0)
end
