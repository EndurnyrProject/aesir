defmodule Aesir.ZoneServer.Content.Npc.Jobs.Valkyrie.Teleporter do
  @moduledoc """
  Sends reborn characters from Valhalla to a town of their choice.

  ## Behavior

  - Gives non-transcendent visitors one of two random remarks.
  - Lets transcendent characters pick one of nine towns, then saves their respawn point
    there and warps them to it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Nana
    - Poki
    - Lupus
    - L0ne_W0lf
    - Mass Zero
    - Silentdragon
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "valkyrie", x: 44, y: 33, dir: 5, sprite: 124, name: "Teleporter", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if upper(ctx) != 1 do
      greet_visitor(ctx, Enum.random(1..10))
    else
      {ctx, choice} =
        ctx
        |> mes("[Teleporter]")
        |> mes("Honorable one,")
        |> mes("which place do you wish to go?")
        |> next()
        |> select([
          "Prontera",
          "Morocc",
          "Payon",
          "Geffen",
          "Alberta",
          "Izlude",
          "Al De Baran",
          "Comodo",
          "Juno"
        ])

      travel_to_choice(ctx, choice)
    end
  end

  defp greet_visitor(ctx, karma) when karma > 4 do
    ctx
    |> mes("[Teleporter]")
    |> mes("Congratulations.")
    |> mes("Honor to the warriors!")
    |> close()
  end

  defp greet_visitor(ctx, _karma) do
    ctx
    |> mes("[Teleporter]")
    |> mes("Please refrain")
    |> mes("from touching any")
    |> mes("of the exhibitions.")
    |> mes("..........")
    |> close()
  end

  defp travel_to_choice(ctx, 1), do: travel(ctx, "prontera", 116, 72)
  defp travel_to_choice(ctx, 2), do: travel(ctx, "morocc", 156, 46)
  defp travel_to_choice(ctx, 3), do: travel(ctx, "payon", 69, 100)
  defp travel_to_choice(ctx, 4), do: travel(ctx, "geffen", 120, 39)
  defp travel_to_choice(ctx, 5), do: travel(ctx, "alberta", 117, 56)

  defp travel_to_choice(ctx, 6) do
    if Rathena.truthy?(checkre(ctx, 0)) do
      travel(ctx, "izlude", 129, 97)
    else
      travel(ctx, "izlude", 94, 103)
    end
  end

  defp travel_to_choice(ctx, 7), do: travel(ctx, "aldebaran", 91, 105)
  defp travel_to_choice(ctx, 8), do: travel(ctx, "comodo", 209, 143)
  defp travel_to_choice(ctx, 9), do: travel(ctx, "yuno", 328, 101)
  defp travel_to_choice(ctx, _choice), do: travel(ctx, 0, 0, 0)

  defp travel(ctx, map, x, y) do
    ctx
    |> mes("[Teleporter]")
    |> mes("Have a nice trip.")
    |> close()
    |> savepoint(map, x, y)
    |> warp(map, x, y)
  end
end
