defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesJuno.JunoGuide do
  @moduledoc """
  Juno guide who marks the city's landmarks for visitors.

  ## Behavior

  - Marks the selected destination on the mini-map and describes its location.
  - Offers a farewell when the conversation ends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - usul
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Musashiden
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "yuno",
        x: 153,
        y: 47,
        dir: 4,
        sprite: 700,
        name: "Juno Guide",
        scope: :pre_renewal,
        unique_name: "Juno Guide#yuno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @locations [
    {"Armory", {120, 138, 0, 0xFF3355},
     [
       "Please look",
       "at the mini map.",
       "^FF3355+^000000 -> Armory",
       "Thank you,",
       "have a good day."
     ]},
    {"Tool Shop", {193, 142, 1, 0x3355FF},
     [
       "Please look",
       "at the mini map.",
       "^3355FF+^000000 -> Tool Shop",
       "Thank you,",
       "have a good day."
     ]},
    {"Sage Castle (Sage Job Change Place)", {90, 318, 2, 0x33FF55},
     [
       "Please look",
       "at the mini map.",
       "^33FF55+^000000 -> Sage Castle",
       "( Sage Job Change Place )",
       "Thank you, have a good day."
     ]},
    {"Street of Book Stores", {257, 102, 3, 0xFF3355},
     [
       "Please look",
       "at the mini map.",
       "^FF3355+^000000 -> Street of Book Stores",
       "Thank you, have a good day."
     ]},
    {"Juphero Plaza", {157, 170, 4, 0x3355FF},
     [
       "Please look",
       "at the mini map.",
       "^3355FF+^000000 -> Juphero Plaza",
       "Thank you,",
       "have a good day."
     ]},
    {"Library of the Republic", {336, 204, 5, 0x33FF55},
     [
       "Please look",
       "at the mini map.",
       "^33FF55+^000000 -> Library of the Republic",
       "Thank you, have a good day."
     ]},
    {"Schweicherbil Magic Academy", {323, 281, 6, 0xFF3355},
     [
       "Please look at the mini map.",
       "^FF3355+^000000 -> Schweicherbil Magic Academy",
       "Thank you, have a good day."
     ]},
    {"Monster Museum", {278, 288, 7, 0x3355FF},
     [
       "Please look at the mini map.",
       "^3355FF+^000000 -> Monster Museum",
       "Thank you, have a good day."
     ]},
    {"Forge", {120, 138, 8, 0xFF3355},
     [
       "Please look at the mini map.",
       "^FF3355+^000000 -> Forge",
       "The forge is located underneath Armory.",
       "Thank you, have a good day."
     ]},
    {"Airport", {53, 214, 9, 0xFF3355},
     ["Please look at the mini map.", "^FF3355+^000000 -> Airport", "Thank you, have a good day."]}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ms. Yoon]")
      |> mes(
        "A place that takes the vision of the future, and gives it form in the present. Welcome to"
      )
      |> mes("the city of Juno!")
      |> next()
      |> select(Enum.map(@locations, &elem(&1, 0)) ++ ["End Conversation"])

    case choice do
      choice when choice in 1..10 ->
        {_name, {x, y, id, color}, lines} = Enum.at(@locations, choice - 1)

        Enum.reduce(lines, viewpoint(ctx, 1, x, y, id, color) |> mes("[Ms. Yoon]"), &mes(&2, &1))
        |> close()

      11 ->
        ctx
        |> mes("[Ms. Yoon]")
        |> mes("A great city of wise men.")
        |> mes("A city of Knowledge!")
        |> mes("Welcome to Juno.")
        |> close()

      _ ->
        ctx
    end
  end
end
