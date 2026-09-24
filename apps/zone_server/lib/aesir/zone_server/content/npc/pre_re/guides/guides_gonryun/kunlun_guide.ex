defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesGonryun.KunlunGuide do
  @moduledoc """
  Kunlun guide who marks local shops and landmarks on the mini-map.

  ## Behavior

  - Describes the selected destination and marks it on the mini-map.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "gonryun",
        x: 163,
        y: 60,
        dir: 4,
        sprite: 780,
        name: "Kunlun Guide",
        scope: :pre_renewal,
        unique_name: "Kunlun Guide#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {109, 131, 0, 0xFF3355, "^FF3355",
     "the residence of the Chief. Enjoy your stay in lovely Kunlun!"},
    {147, 82, 1, 0xCE6300, "^CE6300", "the Tool Dealer. Enjoy your stay in lovely Kunlun!"},
    {174, 104, 2, 0x55FF33, "^55FF33", "the Weapon Dealer. Enjoy your stay in lovely Kunlun!"},
    {173, 84, 3, 0x3355FF, "^3355FF", "the Armor Dealer. Enjoy your stay in lovely Kunlun!"},
    {215, 114, 3, 0xCD69C9, "^CD69C9", "the Wine Maker. Enjoy your stay in lovely Kunlun!"}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[He Yuen Zhe]")
      |> mes("Ni Hao!")
      |> mes("Welcome to Kunlun~")
      |> mes("Take a walk around and experience")
      |> mes("the ancient history and tradition")
      |> mes("of our breath taking city.")
      |> next()
      |> mes("[He Yuen Zhe]")
      |> mes("I am responsible for helping you")
      |> mes("with any questions you may have.")
      |> mes("Please feel free to ask me anything.")
      |> next()
      |> select([
        "Residence of the Chief",
        "Tool Dealer",
        "Weapon Dealer",
        "Armor Dealer",
        "Wine Maker"
      ])

    case choice do
      choice when choice in 1..5 ->
        {x, y, id, color, highlight, destination} = Enum.at(@locations, choice - 1)

        ctx
        |> viewpoint(1, x, y, id, color)
        |> mes("[He Yuen Zhe]")
        |> mes("Please follow your minimap, and head over to the #{highlight}+^000000 mark.")
        |> mes("There, you'll get to #{destination}")
        |> mes("Xie Xie!")
        |> close()

      _ ->
        ctx
    end
  end
end
