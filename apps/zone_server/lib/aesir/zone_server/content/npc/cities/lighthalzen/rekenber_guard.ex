defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.RekenberGuard do
  @moduledoc """
  Controls access to a restricted Regenschirm laboratory entrance.

  ## Behavior

  - Recognizes visitors wearing both disguise items and warps them inside.
  - Challenges other visitors and explains the access restriction.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 35,
        y: 226,
        dir: 5,
        sprite: 867,
        name: "Rekenber Guard",
        scope: :shared,
        unique_name: "Rekenber Guard#li01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.truthy?(is_equipped(ctx, 2241)) and Rathena.truthy?(is_equipped(ctx, 2243)) do
      ctx
      |> mes("[Rekenber Guard]")
      |> mes("^3355FF(Whoa, it's a member")
      |> mes("of the staff!)^000000 Good day!")
      |> close()
      |> warp("lhz_in01", 37, 225)
    else
      request_identification(ctx)
    end
  end

  defp request_identification(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Rekenber Guard]")
      |> mes("This is a restricted")
      |> mes("area! Please show")
      |> mes("some ID immediately!")
      |> next()
      |> select(["ID?", "Cancel"])

    if choice == 1 do
      ctx
      |> mes("[Rekenber Guard]")
      |> mes("I don't know how you")
      |> mes("adventurers do things in")
      |> mes("Rune-Midgarts, but over here")
      |> mes("we have laws about trespassing!")
      |> close()
    else
      ctx
      |> mes("[Rekenber Guard]")
      |> mes("Unless you have special")
      |> mes("authorization, nobody is")
      |> mes("allowed into the Underground")
      |> mes("Laboratory for security reasons.")
      |> close()
    end
  end
end
