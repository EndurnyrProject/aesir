defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesAmatsu.GuideMan do
  @moduledoc """
  Amatsu guide who directs visitors to the town's landmarks.

  ## Behavior

  - Marks the chosen palace, shop, or bar on the mini-map and gives directions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "amatsu",
        x: 251,
        y: 283,
        dir: 4,
        sprite: 767,
        name: "Guide Man",
        scope: :pre_renewal,
        unique_name: "Guide Man#2ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {85, 235, 0, 0xFF3355, "^FF3355+^000000", "the Palace."},
    {96, 118, 1, 0xCE6300, "^CE6300+^000000", "the Tool Shop."},
    {132, 117, 2, 0x55FF33, "^55FF33+^000000", "the Weapon Shop."},
    {217, 116, 3, 0x3355FF, "^3355FF+^000000", "the Bar."}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guide Man]")
      |> mes("Welcome, tourist from Midgard.")
      |> mes("I'm the guide of")
      |> mes("our beautiful town, Amatsu.")
      |> next()
      |> mes("[Guide Man]")
      |> mes("What are you looking for?")
      |> next()
      |> select(["Palace", "Tool Shop", "Weapon Shop", "Bar"])

    case choice do
      choice when choice in 1..4 ->
        {x, y, id, color, marker, destination} = Enum.at(@locations, choice - 1)

        ctx
        |> viewpoint(1, x, y, id, color)
        |> mes("[Guide Man]")
        |> mes("On the mini-map,")
        |> mes("go to #{marker}")
        |> mes("to find #{destination}")
        |> mes("Have a good time")
        |> mes("in Amatsu.")
        |> close()

      _ ->
        ctx
    end
  end
end
